// SPDX-License-Identifier: AGPL-3.0-or-later
import SwiftUI
import PDFKit

struct LocalAIRequest: Identifiable {
    let id = UUID()
    let task: AITask
    let selection: String
    let context: String
    let book: MobileBook
    let settings: Settings
    let previous: ReadingRecord?
    let question: String
    let page: Int
}
@MainActor final class MobileModel: ObservableObject {
    @Published var books: [MobileBook] = []
    @Published var records: [ReadingRecord] = []
    @Published var settings = Settings()
    @Published var book: MobileBook?
    @Published var document: MobileDocument?
    @Published var position = 0
    @Published var selected = ""
    @Published var context = ""
    @Published var answer = ""
    @Published var question = ""
    @Published var error: String?
    @Published var busy = false
    @Published var importing = false
    @Published var progress = ""
    @Published var showAI = false
    @Published var assistantPresentation = AssistantPresentation.sidebar
    @Published var assistantWidthFraction = 0.38
    private(set) var library: MobileLibrary?
    private var work: Task<Void, Never>?
    private var activeRecord: ReadingRecord?
    var answerSubject: String {
        activeRecord?.kind == "file" ? t("全文总结", "Document summary") : (activeRecord?.selected ?? "")
    }
    var pdfView: PDFView?
    var english: Bool { settings.english }
    func t(_ zh: String, _ en: String) -> String { english ? en : zh }
    init(root: URL? = nil) {
        do {
            library = try MobileLibrary(root: root); refresh(); settings = library!.state.settings
            assistantPresentation = AssistantPresentation(rawValue: library?.state.assistantPresentation ?? "") ?? .sidebar
            assistantWidthFraction = ReaderSplitLayout.validFraction(library?.state.assistantWidthFraction ?? 0.38)
        } catch { report(error) }
    }
    func refresh() { books = library?.state.books ?? []; records = library?.state.records ?? [] }
    func report(_ failure: Error) {
        error = (failure as? ReaderError)?.message(english) ?? t("操作失败，请检查文件或可用存储空间。", "Operation failed. Check the file or available storage.")
    }
    func persistSettings() {
        do {
            try library?.update { $0.settings = settings }
        } catch { report(error) }
    }
    func setWorldKnowledge(_ enabled: Bool) {
        guard !busy, let library else { return }
        do {
            var next = settings; next.useWorldKnowledge = enabled
            try library.update { $0.settings = next }
            settings = next
        } catch { report(error) }
    }
    func dismissAssistant() { showAI = false }
    func setAssistantPresentation(_ presentation: AssistantPresentation) {
        assistantPresentation = presentation
        showAI = true
        persistReaderLayout()
    }
    func persistReaderLayout() {
        assistantWidthFraction = ReaderSplitLayout.validFraction(assistantWidthFraction)
        do {
            try library?.update {
                $0.assistantPresentation = assistantPresentation.rawValue
                $0.assistantWidthFraction = assistantWidthFraction
            }
        } catch { report(error) }
    }
    func importFile(_ url: URL) {
        guard !busy, !importing, let library else { return }
        importing = true
        // Local coordinated copy; no file or credential is sent over the network.
        Task {
            do { let imported = try await Task.detached(priority: .userInitiated) { try library.importFile(url) }.value; refresh(); open(imported) } catch { report(error) }
            importing = false
        }
    }
    func open(_ target: MobileBook) {
        guard !busy, let library else { return }
        do {
            let opened = try MobileDocument.load(library.url(target))
            document = opened; book = target
            position = min(target.position, max(0, (opened.pdf?.pageCount ?? opened.chapters.count) - 1))
            selected = ""; context = ""; answer = ""; activeRecord = nil; question = ""; pdfView = nil
            dismissAssistant()
        } catch { report(error) }
    }
    func closeBook() { savePosition(); dismissAssistant(); document = nil; book = nil; pdfView = nil }
    func savePosition() { updateBook { $0.position = position } }
    func updateBook(_ mutate: (inout MobileBook) -> Void) {
        guard var value = book, let library else { return }
        mutate(&value)
        do {
            try library.update { state in if let i = state.books.firstIndex(where: { $0.id == value.id }) { state.books[i] = value } }
            book = value; refresh()
        } catch { report(error) }
    }
    func deleteBook(_ value: MobileBook) {
        do { try library?.remove(value); if book?.id == value.id { closeBook() }; refresh() } catch { report(error) }
    }
    func deleteRecord(_ id: String) {
        do { try library?.update { $0.records.removeAll { $0.id == id } }; refresh() } catch { report(error) }
    }
    func select(_ text: String, surrounding: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if selected != TextLimits.prefix(text, 4000) {
            if !busy { answer = ""; activeRecord = nil; question = "" }
        }
        selected = TextLimits.prefix(text, 4000)
        showAI = true
        if let match = surrounding.range(of: text) {
            let before = min(1000, surrounding.distance(from: surrounding.startIndex, to: match.lowerBound))
            let start = surrounding.index(match.lowerBound, offsetBy: -before)
            context = TextLimits.prefix(String(surrounding[start...]), 5000)
        } else { context = TextLimits.prefix(surrounding, 5000) }
    }
    func explain() {
        guard !selected.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            error = t("请先在正文中长按并选择文字。", "Touch and hold the document to select text first."); return
        }
        prepare(.explain)
    }
    func followup() {
        guard let previous = activeRecord, !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        prepare(.followup, previous: previous)
    }
    private func prepare(_ task: AITask, previous: ReadingRecord? = nil) {
        guard !busy, let book else { return }
        let request = LocalAIRequest(task: task, selection: selected, context: context,
            book: book, settings: settings, previous: previous, question: question, page: position + 1)
        error = nil; busy = true; showAI = true
        let previousAnswer = answer
        answer = ""; progress = t("正在本机加载千问并生成回答…", "Loading Qwen and answering on device…")
        work = Task {
            defer { busy = false; work = nil; progress = "" }
            do {
                try Task.checkCancellation()
                let output = try await LocalQwen.shared.complete(settings: request.settings,
                    source: Self.localSource(request), followup: request.task == .followup) { [weak self] partial in
                    await self?.showLocalPartial(partial)
                }
                try Task.checkCancellation()
                var record = ReadingRecord()
                record.file = request.book.filename; record.title = request.book.title
                record.selected = request.previous?.selected ?? request.selection
                record.context = request.previous?.context ?? request.context
                record.answer = output; record.kind = request.task == .document ? "file" : "explain"
                record.provider = "Qwen · 本机"; record.model = "Qwen3-0.6B-Q4_K_M"
                record.language = request.settings.english ? "en" : "zh"; record.page = request.page
                if request.task == .followup {
                    let prompt = "Q: " + TextLimits.prefix(request.question, 1000) + "\n\n"
                    let budget = max(0, 20000 - output.utf16.count)
                    record.answer = TextLimits.prefix(prompt, budget) + output
                }
                guard record.valid else { throw MobileDocument.invalid }
                try library?.update { $0.records.insert(record, at: 0) }
                answer = output; activeRecord = record; question = ""; refresh()
            } catch is CancellationError { answer = previousAnswer }
            catch { answer = previousAnswer; report(error) }
        }
    }
    static func localSource(_ request: LocalAIRequest) -> String {
        let selection = TextLimits.prefix(request.previous?.selected ?? request.selection, 500)
        let context = TextLimits.prefix(request.previous?.context ?? request.context, 600)
        if request.task == .followup {
            return "当前追问：\(TextLimits.prefix(request.question, 300))\n选文：\(selection)\n语境：\(context)\n上次回答（可能有误）：\(TextLimits.prefix(request.previous?.answer ?? "", 250))"
        }
        return "选文：\(selection)\n语境：\(context)"
    }
    private func showLocalPartial(_ text: String) { answer = text }
    func cancel() { work?.cancel() }
    func highlight() {
        guard !selected.isEmpty else { return }
        if let pdf = document?.pdf, let view = pdfView, let selection = view.currentSelection, let library, let book {
            var changes: [(PDFPage, PDFAnnotation)] = []
            for line in selection.selectionsByLine() {
                for page in line.pages {
                    let annotation = PDFAnnotation(bounds: line.bounds(for: page), forType: .highlight, withProperties: nil)
                    annotation.color = .systemYellow.withAlphaComponent(0.4); page.addAnnotation(annotation)
                    changes.append((page, annotation))
                }
            }
            if let data = pdf.dataRepresentation() {
                do { try data.write(to: library.url(book), options: .atomic) }
                catch { changes.forEach { $0.0.removeAnnotation($0.1) }; report(error) }
            } else { changes.forEach { $0.0.removeAnnotation($0.1) }; error = t("无法保存高亮。", "Could not save highlight.") }
        } else {
            let text = selected
            updateBook { if !$0.highlights.contains(text) { $0.highlights.append(text) } }
        }
    }
    func sample() {
        guard let url = Bundle.main.url(forResource: "Reading-Garden", withExtension: "txt") else { return }
        importFile(url)
    }
}
