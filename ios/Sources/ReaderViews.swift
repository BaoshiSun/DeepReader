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
struct ReaderScreen: View {
    @EnvironmentObject var model: MobileModel
    @State private var search = ""
    @Environment(\.dismiss) private var dismiss
    var body: some View {
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
        .onChange(of: model.position) { model.savePosition(); model.selected = ""; model.context = "" }
        .onDisappear { model.savePosition() }
    }
}
