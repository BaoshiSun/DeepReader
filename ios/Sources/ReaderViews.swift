// SPDX-License-Identifier: AGPL-3.0-or-later
import SwiftUI
import PDFKit

struct TextReader: UIViewRepresentable {
    let chapter: MobileChapter
    let highlights: [String]
    let search: String
    let selection: (String, String) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(selection) }
    func makeUIView(context: Context) -> UITextView {
        let view = UITextView(); view.isEditable = false; view.isSelectable = true
        view.delegate = context.coordinator; view.backgroundColor = .systemBackground
        view.textContainerInset = UIEdgeInsets(top: 24, left: 22, bottom: 40, right: 22)
        view.adjustsFontForContentSizeCategory = true
        view.accessibilityLabel = "Document text"
        return view
    }
    func updateUIView(_ view: UITextView, context: Context) {
        let changed = context.coordinator.chapter != chapter.id
        let signature = chapter.id + highlights.joined(separator: "\0") + search + String(view.traitCollection.preferredContentSizeCategory.rawValue)
        guard context.coordinator.signature != signature else { return }
        context.coordinator.signature = signature; context.coordinator.chapter = chapter.id
        let oldSelection = view.selectedRange, oldOffset = view.contentOffset
        let paragraph = NSMutableParagraphStyle(); paragraph.lineSpacing = 7
        let text = NSMutableAttributedString(string: chapter.text, attributes: [.font: UIFont.preferredFont(forTextStyle: .body), .foregroundColor: UIColor.label, .paragraphStyle: paragraph])
        func mark(_ value: String, color: UIColor) -> NSRange? {
            guard !value.isEmpty else { return nil }
            let source = chapter.text as NSString
            var remaining = NSRange(location: 0, length: source.length), first: NSRange?
            while remaining.length > 0 {
                let match = source.range(of: value, options: .caseInsensitive, range: remaining)
                if match.location == NSNotFound { break }
                if first == nil { first = match }
                text.addAttribute(.backgroundColor, value: color, range: match)
                remaining = NSRange(location: NSMaxRange(match), length: source.length - NSMaxRange(match))
            }
            return first
        }
        for value in highlights { _ = mark(value, color: UIColor.systemYellow.withAlphaComponent(0.35)) }
        let match = mark(search, color: UIColor.systemOrange.withAlphaComponent(0.4))
        view.attributedText = text
        if changed { view.setContentOffset(.zero, animated: false) }
        else { view.selectedRange = oldSelection; view.setContentOffset(oldOffset, animated: false) }
        if let match { view.scrollRangeToVisible(match) }
    }
    final class Coordinator: NSObject, UITextViewDelegate {
        var signature = "", chapter = ""
        let selection: (String, String) -> Void
        init(_ selection: @escaping (String, String) -> Void) { self.selection = selection }
        func textViewDidChangeSelection(_ view: UITextView) {
            let text = view.text as NSString? ?? ""; let range = view.selectedRange
            guard range.length > 0, NSMaxRange(range) <= text.length else { return }
            let start = max(0, range.location - 1800), end = min(text.length, NSMaxRange(range) + 1800)
            let chosen = text.substring(with: range), context = text.substring(with: NSRange(location: start, length: end-start))
            DispatchQueue.main.async { self.selection(chosen, context) }
        }
    }
}
struct PDFReaderView: UIViewRepresentable {
    let document: PDFDocument
    let position: Int
    let search: String
    let model: MobileModel
    func makeCoordinator() -> Coordinator { Coordinator(model) }
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView(); view.autoScales = true; view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical; context.coordinator.observe(view)
        return view
    }
    func updateUIView(_ view: PDFView, context: Context) {
        if view.document !== document {
            view.document = document; model.pdfView = view
            if let page = document.page(at: position) { view.go(to: page) }
        }
        if context.coordinator.query != search {
            context.coordinator.query = search
            let matches = search.isEmpty ? [] : document.findString(search, withOptions: .caseInsensitive)
            view.highlightedSelections = matches
            if let first = matches.first { view.go(to: first) }
        }
    }
    final class Coordinator {
        let model: MobileModel
        var observers: [NSObjectProtocol] = []
        var query = ""
        init(_ model: MobileModel) { self.model = model }
        func observe(_ view: PDFView) {
            observers.append(NotificationCenter.default.addObserver(forName: .PDFViewSelectionChanged, object: view, queue: .main) { [weak self, weak view] _ in
                guard let selection = view?.currentSelection, let text = selection.string, !text.isEmpty else { return }
                let surrounding = selection.pages.compactMap(\.string).joined(separator: "\n")
                Task { @MainActor [weak self] in self?.model.select(text, surrounding: surrounding) }
            })
            observers.append(NotificationCenter.default.addObserver(forName: .PDFViewPageChanged, object: view, queue: .main) { [weak self, weak view] _ in
                guard let view, let page = view.currentPage, let document = view.document else { return }
                let index = document.index(for: page)
                Task { @MainActor [weak self] in self?.model.position = index }
            })
        }
        deinit { observers.forEach(NotificationCenter.default.removeObserver) }
    }
}
enum AssistantPresentation: String {
    case sidebar, floating
}

/// Uses the actual window width, so rotation and iPad multitasking share one layout.
struct ReaderSplitLayout {
    static let dividerWidth: CGFloat = 24
    static let minimumReaderWidth: CGFloat = 340
    static let minimumAssistantWidth: CGFloat = 300
    let width: CGFloat
    var canDock: Bool { width >= Self.minimumReaderWidth + Self.minimumAssistantWidth + Self.dividerWidth }
    static func validFraction(_ value: Double) -> Double {
        value.isFinite ? min(0.65, max(0.25, value)) : 0.38
    }
    func assistantWidth(fraction: Double) -> CGFloat {
        guard canDock else { return 0 }
        return min(width - Self.dividerWidth - Self.minimumReaderWidth,
                   max(Self.minimumAssistantWidth, width * Self.validFraction(fraction)))
    }
    func resizedFraction(startWidth: CGFloat, translation: CGFloat) -> Double {
        guard canDock else { return 0.38 }
        let requested = min(width - Self.dividerWidth - Self.minimumReaderWidth,
                            max(Self.minimumAssistantWidth, startWidth - translation))
        return Self.validFraction(Double(requested / width))
    }
}

struct ReaderScreen: View {
    @EnvironmentObject var model: MobileModel
    @State private var search = ""
    @State private var resizeStartWidth: CGFloat?
    var body: some View {
        GeometryReader { geometry in
            let layout = ReaderSplitLayout(width: geometry.size.width)
            let docked = model.showAI && model.assistantPresentation == .sidebar && layout.canDock
            HStack(spacing: 0) {
                readingContent.frame(maxWidth: .infinity, maxHeight: .infinity)
                if docked {
                    resizeHandle(layout)
                    DockedAssistant()
                        .frame(width: layout.assistantWidth(fraction: model.assistantWidthFraction))
                        .background(Color(.secondarySystemBackground))
                }
            }
            .coordinateSpace(name: "readerSplit")
            .overlay {
                if model.showAI && !docked {
                    FloatingAssistant(canDock: layout.canDock).padding(.bottom, 56)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { model.setAssistantPresentation(.sidebar) } label: {
                            Label(model.t("右侧栏", "Right sidebar"), systemImage: "sidebar.right")
                        }.disabled(!layout.canDock)
                        Button { model.setAssistantPresentation(.floating) } label: {
                            Label(model.t("悬浮窗", "Floating panel"), systemImage: "rectangle.on.rectangle")
                        }
                        if !layout.canDock {
                            Text(model.t("加宽窗口或横屏可使用右侧栏", "Widen the window or rotate for the sidebar"))
                        }
                    } label: { Image(systemName: docked ? "sidebar.right" : "rectangle.on.rectangle") }
                    .accessibilityLabel(model.t("助手显示方式", "Assistant layout"))
                }
            }
            .onAppear {
                if layout.canDock && model.assistantPresentation == .sidebar { model.showAI = true }
            }
            .onChange(of: geometry.size.width) { resizeStartWidth = nil }
        }
        .navigationTitle(model.book?.title ?? "DeepReader").navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search, prompt: model.t("搜索正文（电子书限当前章）", "Find text (ebooks: current chapter)"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if let book = model.book, let library = model.library { ShareLink(item: library.url(book)) { Label(model.t("导出副本", "Export copy"), systemImage: "square.and.arrow.up") } }
                    ForEach(1...5, id: \.self) { rating in Button(String(repeating: "★", count: rating)) { model.updateBook { $0.rating = rating } } }
                    Button(model.t("切换读完状态", "Toggle finished")) { model.updateBook { $0.finished.toggle() } }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .onChange(of: model.position) { model.savePosition(); model.selected = ""; model.context = ""; model.pending = nil }
        .onDisappear { model.savePosition(); model.dismissAssistant() }
    }
    private func resizeHandle(_ layout: ReaderSplitLayout) -> some View {
        Rectangle().fill(Color(.tertiarySystemFill))
            .overlay { Capsule().fill(.secondary).frame(width: 4, height: 44) }
            .frame(width: ReaderSplitLayout.dividerWidth)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("readerSplit"))
                .onChanged { value in
                    if resizeStartWidth == nil { resizeStartWidth = layout.assistantWidth(fraction: model.assistantWidthFraction) }
                    model.assistantWidthFraction = layout.resizedFraction(startWidth: resizeStartWidth!, translation: value.translation.width)
                }
                .onEnded { _ in resizeStartWidth = nil; model.persistReaderLayout() })
            .accessibilityElement()
            .accessibilityLabel(model.t("调整 AI 侧栏宽度", "Resize AI sidebar"))
            .accessibilityValue("\(Int(layout.assistantWidth(fraction: model.assistantWidthFraction) / layout.width * 100))%")
            .accessibilityHint(model.t("左右拖动分隔线", "Drag the divider left or right"))
            .accessibilityAdjustableAction { direction in
                let step: CGFloat = direction == .increment ? -40 : 40
                model.assistantWidthFraction = layout.resizedFraction(startWidth: layout.assistantWidth(fraction: model.assistantWidthFraction), translation: step)
                model.persistReaderLayout()
            }
    }
    private var readingContent: some View {
        VStack(spacing: 0) {
            if let document = model.document {
                if document.pdf == nil && document.chapters.count > 1 {
                    Picker(model.t("章节", "Chapter"), selection: $model.position) {
                        ForEach(Array(document.chapters.enumerated()), id: \.offset) { i, chapter in Text(chapter.title).tag(i) }
                    }.pickerStyle(.menu).padding(.horizontal)
                }
                if let pdf = document.pdf { PDFReaderView(document: pdf, position: model.position, search: search, model: model) }
                else if document.chapters.indices.contains(model.position) {
                    TextReader(chapter: document.chapters[model.position], highlights: model.book?.highlights ?? [], search: search, selection: model.select)
                        .id(model.book?.id).frame(maxWidth: 850)
                }
                HStack {
                    Label("\(model.position + 1) / \(document.pdf?.pageCount ?? document.chapters.count)", systemImage: "book.pages")
                    Spacer()
                    Button { model.highlight() } label: { Image(systemName: "highlighter") }.disabled(model.selected.isEmpty)
                        .accessibilityLabel(model.t("高亮选文", "Highlight selection"))
                    Button { model.showAI = true } label: { Label(model.t("阅读助手", "Ask AI"), systemImage: "sparkles") }
                }.font(.subheadline).padding().background(.bar)
            }
        }
    }
}

struct DockedAssistant: View {
    @EnvironmentObject var model: MobileModel
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Label(model.t("阅读助手", "Reading assistant"), systemImage: "sparkles")
                    .font(.subheadline.weight(.semibold)).lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button { model.setAssistantPresentation(.floating) } label: {
                    Image(systemName: "rectangle.on.rectangle").frame(width: 44, height: 44)
                }.accessibilityLabel(model.t("改为悬浮窗", "Switch to floating panel"))
                Button { model.dismissAssistant() } label: {
                    Image(systemName: "xmark").frame(width: 44, height: 44)
                }.accessibilityLabel(model.t("关闭助手", "Close assistant"))
            }.padding(.leading, 12).padding(.trailing, 4).frame(minHeight: 52)
            Divider()
            AssistantView()
        }
    }
}

struct FloatingAssistant: View {
    var canDock = false
    @EnvironmentObject var model: MobileModel
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @State private var collapsed = false
    @State private var offset: CGSize?
    @GestureState private var translation = CGSize.zero
    var body: some View {
        GeometryReader { geometry in
            let width = min(collapsed ? 260 : 380, max(0, geometry.size.width - 24))
            let preferredHeight: CGFloat = model.pending != nil ? 520 : (model.answer.isEmpty && !model.busy ? 270 : 400)
            let height = collapsed ? 52 : min(preferredHeight, max(100, geometry.size.height - 24))
            let initial = CGSize(width: 0, height: max(0, geometry.size.height - height - 24))
            let base = bounded(offset ?? initial, in: geometry.size, panel: CGSize(width: width, height: height))
            let position = bounded(CGSize(width: base.width + translation.width, height: base.height + translation.height), in: geometry.size, panel: CGSize(width: width, height: height))
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Label(model.t("阅读助手", "Reading assistant"), systemImage: "sparkles")
                        .font(.subheadline.weight(.semibold)).lineLimit(1).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                        .accessibilityHint(model.t("拖动标题可移动浮窗", "Drag the title to move the panel"))
                        .gesture(DragGesture().updating($translation) { value, state, _ in state = value.translation }
                            .onEnded { value in offset = bounded(CGSize(width: base.width + value.translation.width, height: base.height + value.translation.height), in: geometry.size, panel: CGSize(width: width, height: height)) })
                    if model.busy { ProgressView().controlSize(.small) }
                    if canDock && !collapsed {
                        Button { model.setAssistantPresentation(.sidebar) } label: {
                            Image(systemName: "sidebar.right").frame(width: 44, height: 44)
                        }.accessibilityLabel(model.t("移到右侧栏", "Move to right sidebar"))
                    }
                    Button { collapsed.toggle() } label: { Image(systemName: collapsed ? "chevron.down" : "minus").frame(width: 44, height: 44) }
                        .accessibilityLabel(model.t(collapsed ? "展开助手" : "收起助手", collapsed ? "Expand assistant" : "Collapse assistant"))
                    Button { model.dismissAssistant() } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }
                        .accessibilityLabel(model.t("关闭助手", "Close assistant"))
                }.padding(.leading, 16).padding(.trailing, 4).frame(height: 52)
                if !collapsed { Divider(); AssistantView() }
            }
            .frame(width: width, height: height)
            .tint(colorScheme == .dark ? Color(red: 0.45, green: 0.8, blue: 0.63) : Color(red: 0.16, green: 0.43, blue: 0.32))
            .background {
                if reduceTransparency { RoundedRectangle(cornerRadius: 20).fill(Color(.secondarySystemBackground)) }
                else { RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial) }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.primary.opacity(0.12)))
            .shadow(color: .black.opacity(0.16), radius: 16, y: 6)
            .offset(x: geometry.size.width - width - 12 + position.width, y: 12 + position.height)
            .onChange(of: model.selected) { collapsed = false }
            .onChange(of: model.pending?.id) { if model.pending != nil { collapsed = false } }
        }
    }
    private func bounded(_ value: CGSize, in size: CGSize, panel: CGSize) -> CGSize {
        CGSize(width: min(0, max(-max(0, size.width - panel.width - 24), value.width)),
               height: min(max(0, size.height - panel.height - 24), max(0, value.height)))
    }
}
