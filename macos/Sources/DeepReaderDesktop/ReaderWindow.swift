// SPDX-License-Identifier: AGPL-3.0-or-later
import AppKit
import SwiftUI
import PDFKit
import UniformTypeIdentifiers
import DeepReaderCore

@MainActor public final class ReaderWindow: NSWindowController, NSWindowDelegate, NSSplitViewDelegate {
    public let model: ReaderModel
    private let split = NSSplitViewController()
    private let sidebar: NSHostingController<Sidebar>
    private var sidebarItem: NSSplitViewItem!
    private var panel: NSPanel?
    private var hidden = false
    private var closingApproved = false
    private let toolbar = NSStackView()
    private let pageLabel = NSTextField(labelWithString: "—")
    private let search = NSSearchField()
    private let chapters = NSPopUpButton()
    private var openTask: Task<Void, Never>?
    private var documentAccess: FileAccess?
    private var openID = UUID()
    private var observer: NSObjectProtocol?
    public var menusChanged: (() -> Void)?

    public init(model: ReaderModel) {
        self.model = model; sidebar = NSHostingController(rootView: Sidebar(m: model))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1180, height: 790),
            styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        super.init(window: window)
        window.title = "DeepReader"; window.minSize = NSSize(width: 850, height: 640)
        window.isReleasedWhenClosed = false; window.delegate = self
        let reader = NSViewController(); reader.view = model.reader.view
        let readerItem = NSSplitViewItem(viewController: reader); readerItem.minimumThickness = 360
        split.addSplitViewItem(readerItem)
        sidebarItem = NSSplitViewItem(viewController: sidebar)
        sidebarItem.minimumThickness = 360; sidebarItem.maximumThickness = 1000; sidebarItem.canCollapse = true
        split.addSplitViewItem(sidebarItem)
        let container = NSView()
        toolbar.orientation = .horizontal; toolbar.alignment = .centerY; toolbar.spacing = 6; toolbar.edgeInsets = NSEdgeInsets(top: 8, left: 10, bottom: 8, right: 10)
        toolbar.translatesAutoresizingMaskIntoConstraints = false; split.view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(toolbar); container.addSubview(split.view)
        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: container.leadingAnchor), toolbar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            toolbar.topAnchor.constraint(equalTo: container.topAnchor), toolbar.heightAnchor.constraint(equalToConstant: 48),
            split.view.topAnchor.constraint(equalTo: toolbar.bottomAnchor), split.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            split.view.trailingAnchor.constraint(equalTo: container.trailingAnchor), split.view.bottomAnchor.constraint(equalTo: container.bottomAnchor)])
        window.contentView = container; rebuildToolbar()
        model.openAction = { [weak self] in self?.openPanel() }
        model.openURLAction = { [weak self] url in self?.open(url) }
        model.floatAction = { [weak self] in self?.toggleFloating() }
        model.hideAction = { [weak self] in self?.toggleSidebar() }
        model.languageAction = { [weak self] in self?.rebuildToolbar(); self?.menusChanged?() }
        model.beforeArchive = { [weak self] in self?.saveBeforeArchive() ?? false }
        model.reader.ebook.changed = { [weak self] in self?.updatePage() }
        model.reader.ebook.failed = { [weak model] error in model?.show(error) }
        observer = NotificationCenter.default.addObserver(forName: .PDFViewPageChanged, object: model.pdf.view, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.updatePage() }
        }
        NotificationCenter.default.addObserver(self, selector: #selector(resizedSplit(_:)), name: NSSplitView.didResizeSubviewsNotification, object: split.splitView)
        window.center()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { if let observer = observer { NotificationCenter.default.removeObserver(observer) }; NotificationCenter.default.removeObserver(self) }
    public func present() {
        closingApproved = false
        showWindow(nil); window?.makeKeyAndOrderFront(nil)
        if let width = window?.contentView?.bounds.width { split.splitView.setPosition(max(360, width - model.settings.sidebarWidth), ofDividerAt: 0) }
        if model.settings.floating { setFloating(true) }
    }
    private func button(_ title: String, _ action: Selector, help: String? = nil) -> NSButton {
        let button = NSButton(title: title, target: self, action: action); button.bezelStyle = .rounded
        button.toolTip = help; button.setContentHuggingPriority(.required, for: .horizontal); return button
    }
    private func rebuildToolbar() {
        for view in toolbar.arrangedSubviews { toolbar.removeArrangedSubview(view); view.removeFromSuperview() }
        toolbar.addArrangedSubview(button(model.t("打开", "Open"), #selector(openPanel)))
        toolbar.addArrangedSubview(button("‹", #selector(previousPage), help: model.t("上一页", "Previous page")))
        toolbar.addArrangedSubview(button("›", #selector(nextPage), help: model.t("下一页", "Next page")))
        toolbar.addArrangedSubview(pageLabel)
        chapters.target = self; chapters.action = #selector(chooseChapter)
        chapters.setContentHuggingPriority(.defaultLow, for: .horizontal)
        if chapters.constraints.isEmpty { chapters.widthAnchor.constraint(lessThanOrEqualToConstant: 200).isActive = true }
        toolbar.addArrangedSubview(chapters)
        toolbar.addArrangedSubview(button("−", #selector(zoomOut))); toolbar.addArrangedSubview(button("+", #selector(zoomIn)))
        toolbar.addArrangedSubview(button(model.t("适合页面", "Fit"), #selector(fitPage)))
        search.placeholderString = model.t("搜索正文", "Find text"); search.target = self; search.action = #selector(findNext)
        search.sendsWholeSearchString = true; search.sendsSearchStringImmediately = false
        search.setContentHuggingPriority(.defaultLow, for: .horizontal)
        if search.constraints.isEmpty { search.widthAnchor.constraint(greaterThanOrEqualToConstant: 120).isActive = true }
        toolbar.addArrangedSubview(search)
        toolbar.addArrangedSubview(button("AI", #selector(showAI), help: model.t("显示 AI 侧栏", "Show AI sidebar")))
        updatePage()
    }
    private func updatePage() {
        chapters.isHidden = model.reader.isPDF
        if !model.reader.isPDF, let book = model.reader.ebook.book {
            let index = model.reader.ebook.chapter
            pageLabel.stringValue = "\(index + 1) / \(book.chapters.count)"
            let titles = book.chapters.enumerated().map { "\($0.offset + 1). \($0.element.title)" }
            if chapters.itemTitles != titles { chapters.removeAllItems(); chapters.addItems(withTitles: titles) }
            chapters.selectItem(at: index); chapters.toolTip = model.t("章节目录；搜索仅限当前章节", "Chapters; search applies to the current chapter")
        }
        else if let document = model.pdf.view.document, let page = model.pdf.view.currentPage { pageLabel.stringValue = "\(document.index(for: page)+1) / \(document.pageCount)" }
        else { pageLabel.stringValue = "—" }
    }
    @objc public func openPanel() {
        let picker = NSOpenPanel(); picker.allowedContentTypes = BookFormat.extensions.compactMap { UTType(filenameExtension: $0) }; picker.allowsMultipleSelection = false
        if picker.runModal() == .OK, let url = picker.url { open(url) }
    }
    public func open(_ requestedURL: URL) {
        guard mayDiscard() else { return }
        let access: FileAccess
        do { access = try model.fileAccess.acquire(requestedURL) }
        catch { model.show(error); return }
        let url = access.url
        openTask?.cancel(); openID = UUID(); model.cancel(); model.opening = false
        if url.pathExtension.lowercased() != "pdf" {
            let id = openID
            model.opening = true; model.status = model.t("正在打开电子书…", "Opening ebook…")
            openTask = Task { [weak self] in
                let worker = Task.detached { try withExtendedLifetime(access) { try EBookDocument.load(url) } }
                do {
                    let book = try await withTaskCancellationHandler(operation: { try await worker.value }, onCancel: { worker.cancel() })
                    try Task.checkCancellation()
                    guard let self = self, self.openID == id else { return }
                    let entry = try self.model.store.ensureBook(url)
                    let marks = try self.model.store.highlights(bookID: entry.id, fingerprint: book.fingerprint)
                    self.model.reader.openEBook(book, marks: marks); self.documentAccess = access
                    try self.model.didOpen(); self.opened(url)
                } catch is CancellationError {} catch { if self?.openID == id { self?.model.show(error) } }
                if self?.openID == id { self?.model.opening = false; self?.openTask = nil }
            }
            return
        }
        do {
            var password: String?
            if let document = PDFDocument(url: url), document.isLocked {
                let alert = NSAlert(); alert.messageText = model.t("输入 PDF 密码", "Enter the PDF password")
                let input = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24)); alert.accessoryView = input
                alert.addButton(withTitle: model.t("打开", "Open")); alert.addButton(withTitle: model.t("取消", "Cancel"))
                alert.window.initialFirstResponder = input
                guard alert.runModal() == .alertFirstButtonReturn else { return }; password = input.stringValue
            }
            try model.reader.openPDF(url, password: password); documentAccess = access
            try model.didOpen(); opened(url)
        } catch { model.show(error) }
    }
    private func opened(_ url: URL) {
        window?.title = url.lastPathComponent + " — DeepReader"; window?.representedURL = url
        NSDocumentController.shared.noteNewRecentDocumentURL(url); updatePage()
    }
    @objc private func chooseChapter() { model.reader.ebook.go(to: chapters.indexOfSelectedItem) }
    private func mayDiscard() -> Bool {
        guard model.reader.isPDF, model.pdf.dirty else { return true }
        let alert = NSAlert(); alert.messageText = model.t("保存当前 PDF 的高亮批注？", "Save highlights in the current PDF?")
        alert.addButton(withTitle: model.t("保存", "Save")); alert.addButton(withTitle: model.t("不保存", "Discard")); alert.addButton(withTitle: model.t("取消", "Cancel"))
        switch alert.runModal() {
        case .alertFirstButtonReturn: do { try model.pdf.save(); model.dirty = false; return true } catch { model.show(error); return false }
        case .alertSecondButtonReturn: return true
        default: return false
        }
    }
    private func saveBeforeArchive() -> Bool {
        guard model.reader.isPDF, model.pdf.dirty else { return true }
        let alert = NSAlert(); alert.messageText = model.t("先保存高亮批注，再归档当前 PDF。", "Save highlights before archiving the current PDF.")
        alert.addButton(withTitle: model.t("保存并归档", "Save and archive")); alert.addButton(withTitle: model.t("取消", "Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return false }
        do { try model.pdf.save(); model.dirty = false; return true } catch { model.show(error); return false }
    }
    @objc public func previousPage() { model.reader.move(-1) }
    @objc public func nextPage() { model.reader.move(1) }
    @objc public func zoomIn() { model.reader.zoom(1.15) }
    @objc public func zoomOut() { model.reader.zoom(1 / 1.15) }
    @objc public func fitPage() { model.reader.fit() }
    @objc public func findNext() { model.reader.find(search.stringValue) }
    @objc public func findPrevious() { model.reader.find(search.stringValue, backwards: true) }
    @objc public func focusSearch() { window?.makeFirstResponder(search) }
    @objc public func explain() { showAI(); model.explain() }
    @objc public func ask() { model.ask() }
    @objc public func savePDF() { model.savePDF() }
    @objc public func saveCopy() {
        guard model.reader.isPDF, model.pdf.url != nil else { return }
        let panel = NSSavePanel(); panel.allowedContentTypes = [.pdf]; panel.nameFieldStringValue = "DeepReader-copy.pdf"
        if panel.runModal() == .OK, let url = panel.url {
            let access = FileAccess(url)
            do { try withExtendedLifetime(access) { try model.pdf.saveCopy(url) } } catch { model.show(error) }
        }
    }
    @objc public func showAI() {
        hidden = false
        if model.settings.floating { if panel == nil { setFloating(true) }; panel?.makeKeyAndOrderFront(nil) }
        else { sidebarItem.isCollapsed = false }
    }
    @objc public func toggleSidebar() {
        hidden.toggle()
        if model.settings.floating { if hidden { panel?.orderOut(nil) } else { panel?.makeKeyAndOrderFront(nil) } }
        else { sidebarItem.isCollapsed = hidden }
    }
    @objc public func toggleFloating() { setFloating(!model.settings.floating) }
    public func setFloating(_ floating: Bool) {
        hidden = false
        if floating && panel == nil {
            let width = sidebar.view.bounds.width
            if width >= 360 { model.settings.sidebarWidth = width }
            split.removeSplitViewItem(sidebarItem)
            let floatingPanel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: model.settings.floatingWidth, height: model.settings.floatingHeight),
                styleMask: [.titled, .closable, .resizable, .utilityWindow], backing: .buffered, defer: false)
            floatingPanel.title = "DeepReader AI"; floatingPanel.minSize = NSSize(width: 380, height: 570)
            floatingPanel.isReleasedWhenClosed = false; floatingPanel.isFloatingPanel = true; floatingPanel.level = .normal
            floatingPanel.delegate = self; floatingPanel.contentViewController = sidebar
            if let parent = window { parent.addChildWindow(floatingPanel, ordered: .above); floatingPanel.setFrameTopLeftPoint(NSPoint(x: parent.frame.maxX-80, y: parent.frame.maxY)) }
            if let visible = window?.screen?.visibleFrame {
                var frame = floatingPanel.frame
                frame.size.width = min(frame.width, visible.width); frame.size.height = min(frame.height, visible.height)
                frame.origin.x = min(max(frame.minX, visible.minX), visible.maxX-frame.width)
                frame.origin.y = min(max(frame.minY, visible.minY), visible.maxY-frame.height)
                floatingPanel.setFrame(frame, display: true)
            }
            panel = floatingPanel; floatingPanel.makeKeyAndOrderFront(nil)
        } else if !floating, let existing = panel {
            window?.removeChildWindow(existing); existing.orderOut(nil); existing.contentViewController = nil; existing.delegate = nil; panel = nil
            split.addSplitViewItem(sidebarItem); sidebarItem.isCollapsed = false
            if let width = window?.contentView?.bounds.width { split.splitView.setPosition(max(360, width-model.settings.sidebarWidth), ofDividerAt: 0) }
        }
        model.settings.floating = floating; model.persist()
    }
    @objc private func resizedSplit(_ notification: Notification) {
        guard !model.settings.floating, !hidden, sidebar.view.bounds.width >= 360 else { return }
        let width = sidebar.view.bounds.width
        if abs(model.settings.sidebarWidth-width) > 2 { model.settings.sidebarWidth = width; model.persist() }
    }
    public func windowDidResize(_ notification: Notification) {
        guard let panel = panel, notification.object as? NSWindow === panel else { return }
        model.settings.floatingWidth = Double(panel.contentView?.bounds.width ?? 460)
        model.settings.floatingHeight = Double(panel.contentView?.bounds.height ?? 760); model.persist()
    }
    public func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender === panel { hidden = true; panel?.orderOut(nil); return false }
        return mayDiscard()
    }
    public func windowWillClose(_ notification: Notification) {
        guard notification.object as? NSWindow === window else { return }
        closingApproved = true; openTask?.cancel(); model.cancel(); panel?.orderOut(nil)
    }
    public func canTerminate() -> Bool { closingApproved || mayDiscard() }
    public func layoutState() -> String {
        let pdf = model.pdf.view
        return "PDF frame=\(pdf.frame), bounds=\(pdf.bounds), hidden=\(pdf.isHidden), window=\(String(describing: pdf.window?.windowNumber)), scale=\(pdf.scaleFactor), documentFrame=\(String(describing: pdf.documentView?.frame)), visible=\(String(describing: pdf.documentView?.visibleRect)), destination=\(String(describing: pdf.currentDestination?.point)), split=\(split.splitView.frame), items=\(split.splitViewItems.count)"
    }
    public func snapshot(to url: URL) throws {
        guard let target = window else { throw ReaderError("无法截取窗口。", "Could not capture the window.") }
        // CI only: capture this application's exact window, including PDFKit's tiled rendering.
        // AppKit's cacheDisplay omits GPU-backed page layers and returns transparent backgrounds.
        let capture = Process(); capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        capture.arguments = ["-x", "-o", "-l", String(target.windowNumber), url.path]
        capture.standardOutput = FileHandle.nullDevice; capture.standardError = FileHandle.nullDevice
        try capture.run()
        for _ in 0..<50 { if !capture.isRunning { break }; Thread.sleep(forTimeInterval: 0.1) }
        if capture.isRunning { capture.terminate() }
        if FileManager.default.fileExists(atPath: url.path), let data = try? Data(contentsOf: url), data.count > 1000 { return }
        throw ReaderError("窗口截图不可用。", "Window capture is unavailable on this test runner.")
    }
}
