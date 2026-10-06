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
    private var observer: NSObjectProtocol?
    public var menusChanged: (() -> Void)?

    public init(model: ReaderModel) {
        self.model = model; sidebar = NSHostingController(rootView: Sidebar(m: model))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1180, height: 790),
            styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        super.init(window: window)
        window.title = "DeepReader"; window.minSize = NSSize(width: 850, height: 640)
        window.isReleasedWhenClosed = false; window.delegate = self
        let reader = NSViewController(); reader.view = model.pdf.view
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
        toolbar.addArrangedSubview(button(model.t("打开 PDF", "Open PDF"), #selector(openPanel)))
        toolbar.addArrangedSubview(button("‹", #selector(previousPage), help: model.t("上一页", "Previous page")))
        toolbar.addArrangedSubview(button("›", #selector(nextPage), help: model.t("下一页", "Next page")))
        toolbar.addArrangedSubview(pageLabel)
        toolbar.addArrangedSubview(button("−", #selector(zoomOut))); toolbar.addArrangedSubview(button("+", #selector(zoomIn)))
        toolbar.addArrangedSubview(button(model.t("适合页面", "Fit"), #selector(fitPage)))
        search.placeholderString = model.t("搜索 PDF", "Find in PDF"); search.target = self; search.action = #selector(findNext)
        search.sendsWholeSearchString = true; search.sendsSearchStringImmediately = false
        search.setContentHuggingPriority(.defaultLow, for: .horizontal)
        if search.constraints.isEmpty { search.widthAnchor.constraint(greaterThanOrEqualToConstant: 120).isActive = true }
        toolbar.addArrangedSubview(search)
        toolbar.addArrangedSubview(button("AI", #selector(showAI), help: model.t("显示 AI 侧栏", "Show AI sidebar")))
        updatePage()
    }
    private func updatePage() {
        if let document = model.pdf.view.document, let page = model.pdf.view.currentPage { pageLabel.stringValue = "\(document.index(for: page)+1) / \(document.pageCount)" }
        else { pageLabel.stringValue = "—" }
    }
    @objc public func openPanel() {
        let picker = NSOpenPanel(); picker.allowedContentTypes = [.pdf]; picker.allowsMultipleSelection = false
        if picker.runModal() == .OK, let url = picker.url { open(url) }
    }
    public func open(_ url: URL) {
        guard mayDiscard() else { return }
        do {
            var password: String?
            if let document = PDFDocument(url: url), document.isLocked {
                let alert = NSAlert(); alert.messageText = model.t("输入 PDF 密码", "Enter the PDF password")
                let input = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24)); alert.accessoryView = input
                alert.addButton(withTitle: model.t("打开", "Open")); alert.addButton(withTitle: model.t("取消", "Cancel"))
                alert.window.initialFirstResponder = input
                guard alert.runModal() == .alertFirstButtonReturn else { return }; password = input.stringValue
            }
            try model.pdf.open(url, password: password); try model.didOpen()
            window?.title = url.lastPathComponent + " — DeepReader"; window?.representedURL = url
            NSDocumentController.shared.noteNewRecentDocumentURL(url); updatePage()
        } catch { model.show(error) }
    }
    private func mayDiscard() -> Bool {
        guard model.pdf.dirty else { return true }
        let alert = NSAlert(); alert.messageText = model.t("保存当前 PDF 的高亮批注？", "Save highlights in the current PDF?")
        alert.addButton(withTitle: model.t("保存", "Save")); alert.addButton(withTitle: model.t("不保存", "Discard")); alert.addButton(withTitle: model.t("取消", "Cancel"))
        switch alert.runModal() {
        case .alertFirstButtonReturn: do { try model.pdf.save(); model.dirty = false; return true } catch { model.show(error); return false }
        case .alertSecondButtonReturn: return true
        default: return false
        }
    }
    private func saveBeforeArchive() -> Bool {
        guard model.pdf.dirty else { return true }
        let alert = NSAlert(); alert.messageText = model.t("先保存高亮批注，再归档当前 PDF。", "Save highlights before archiving the current PDF.")
        alert.addButton(withTitle: model.t("保存并归档", "Save and archive")); alert.addButton(withTitle: model.t("取消", "Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return false }
        do { try model.pdf.save(); model.dirty = false; return true } catch { model.show(error); return false }
    }
    @objc public func previousPage() { model.pdf.view.goToPreviousPage(nil) }
    @objc public func nextPage() { model.pdf.view.goToNextPage(nil) }
    @objc public func zoomIn() { model.pdf.view.zoomIn(nil) }
    @objc public func zoomOut() { model.pdf.view.zoomOut(nil) }
    @objc public func fitPage() { model.pdf.view.autoScales = true }
    @objc public func findNext() { model.pdf.find(search.stringValue) }
    @objc public func findPrevious() { model.pdf.find(search.stringValue, backwards: true) }
    @objc public func focusSearch() { window?.makeFirstResponder(search) }
    @objc public func explain() { showAI(); model.explain() }
    @objc public func ask() { model.ask() }
    @objc public func savePDF() { model.savePDF() }
    @objc public func saveCopy() {
        guard model.pdf.url != nil else { return }
        let panel = NSSavePanel(); panel.allowedContentTypes = [.pdf]; panel.nameFieldStringValue = "DeepReader-copy.pdf"
        if panel.runModal() == .OK, let url = panel.url { do { try model.pdf.saveCopy(url) } catch { model.show(error) } }
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
        model.settings.floatingWidth = panel.contentView?.bounds.width ?? 460
        model.settings.floatingHeight = panel.contentView?.bounds.height ?? 760; model.persist()
    }
    public func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender === panel { hidden = true; panel?.orderOut(nil); return false }
        return mayDiscard()
    }
    public func windowWillClose(_ notification: Notification) {
        guard notification.object as? NSWindow === window else { return }
        closingApproved = true; model.cancel(); panel?.orderOut(nil)
    }
    public func canTerminate() -> Bool { closingApproved || mayDiscard() }
    public func snapshot(to url: URL) throws {
        guard let content = window?.contentView, let bitmap = content.bitmapImageRepForCachingDisplay(in: content.bounds) else { throw ReaderError("无法截取窗口。", "Could not capture the window.") }
        content.cacheDisplay(in: content.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else { return }
        try png.write(to: url)
    }
}
