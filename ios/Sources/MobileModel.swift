// SPDX-License-Identifier: AGPL-3.0-or-later
import SwiftUI
import PDFKit

struct PendingAI: Identifiable {
    let id = UUID()
    let task: AITask
    let source: String
    let selection: String
    let context: String
    let book: MobileBook
    let settings: Settings
    let previous: ReadingRecord?
    let question: String
    let page: Int
    var requests: Int { task == .document ? AIClient.summaryRequests(chunks: TextLimits.chunks(source).count) : 1 }
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
    @Published var pending: PendingAI?
    @Published var busy = false
    @Published var importing = false
    @Published var progress = ""
    @Published var showAI = false
    @Published var assistantPresentation = AssistantPresentation.sidebar
    @Published var assistantWidthFraction = 0.38
    @Published var hasKey = false
    @Published private(set) var hasAIConsent = false
    static let aiConsentVersion = 1
    private(set) var library: MobileLibrary?
    private let credentials: Credentials
    private let ai: AIClient
    private var work: Task<Void, Never>?
    private var activeRecord: ReadingRecord?
    var answerSubject: String {
        activeRecord?.kind == "file" ? t("全文总结", "Document summary") : (activeRecord?.selected ?? "")
    }
    var pdfView: PDFView?
    var english: Bool { settings.english }
    func t(_ zh: String, _ en: String) -> String { english ? en : zh }
    init(root: URL? = nil, credentials: Credentials = KeychainCredentials(service: "org.deepreader.ios.providers"), ai: AIClient = AIClient()) {
        self.credentials = credentials; self.ai = ai
        do {
            library = try MobileLibrary(root: root); refresh(); settings = library!.state.settings
            assistantPresentation = AssistantPresentation(rawValue: library?.state.assistantPresentation ?? "") ?? .sidebar
            assistantWidthFraction = ReaderSplitLayout.validFraction(library?.state.assistantWidthFraction ?? 0.38)
            hasAIConsent = library?.state.aiConsentVersion == Self.aiConsentVersion
            hasKey = !(try credentials.read(.deepSeek)).isEmpty
        } catch { report(error) }
    }
    func refresh() { books = library?.state.books ?? []; records = library?.state.records ?? [] }
    func report(_ failure: Error) {
        error = (failure as? ReaderError)?.message(english) ?? t("操作失败，请检查文件或可用存储空间。", "Operation failed. Check the file or available storage.")
    }
    func persistSettings() {
        settings.provider = .deepSeek
        do { try library?.update { $0.settings = settings } } catch { report(error) }
    }
    @discardableResult func key(_ value: String) -> Bool {
        do {
            try credentials.save(value.trimmingCharacters(in: .whitespacesAndNewlines), for: .deepSeek)
            hasKey = true; error = nil
            return true
        } catch { report(error); return false }
    }
    func removeKey() { do { try credentials.remove(.deepSeek); hasKey = false } catch { report(error) } }
    func dismissAssistant() { showAI = false; pending = nil }
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
    func revokeAIConsent() {
        do {
            guard let library else { return }
            try library.update { $0.aiConsentVersion = nil }
            hasAIConsent = false; pending = nil; cancel()
        } catch { report(error) }
    }
    func authorizeAndSend(_ request: PendingAI) {
        guard pending?.id == request.id, request.book.id == book?.id, !busy else { return }
        do {
            guard let library else { return }
            try library.update { $0.aiConsentVersion = Self.aiConsentVersion }
            hasAIConsent = true
            send(request)
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
            pending = nil
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
        prepare(.explain, source: "Selection:\n\(selected)\n\nContext:\n\(context)")
    }
    func followup() {
        guard let previous = activeRecord, !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let source = "Original selection:\n\(previous.selected)\nContext:\n\(previous.context)\nConversation:\n\(TextLimits.prefix(previous.answer, 12000))\nQuestion:\n\(TextLimits.prefix(question, 3000))"
        prepare(.followup, source: source, previous: previous)
    }
    func summary() {
        do { guard let document else { return }; prepare(.document, source: try document.fullText()) } catch { report(error) }
    }
    private func prepare(_ task: AITask, source: String, previous: ReadingRecord? = nil) {
        guard !busy, let book else { return }
        guard hasKey else { error = t("请先在设置中保存您自己的 DeepSeek API Key。", "Save your own DeepSeek API key in Settings first."); return }
        showAI = true
        let request = PendingAI(task: task, source: source, selection: selected, context: context, book: book, settings: settings, previous: previous, question: question, page: position + 1)
        if hasAIConsent { send(request) } else { pending = request }
    }
    private func send(_ request: PendingAI) {
        guard !busy, hasAIConsent else { return }
        pending = nil; busy = true; progress = t("正在请求 DeepSeek…", "Requesting DeepSeek…"); showAI = true
        work = Task {
            defer { busy = false; work = nil; progress = "" }
            do {
                try Task.checkCancellation()
                guard hasAIConsent else { return }
                let key = try credentials.read(.deepSeek)
                let output: String
                if request.task == .document {
                    output = try await ai.summarize(settings: request.settings, key: key, source: request.source, review: false) { [weak self] done, total in
                        await self?.setProgress(done, total)
                    }
                } else { output = try await ai.complete(settings: request.settings, key: key, task: request.task, source: request.source) }
                try Task.checkCancellation()
                var record = ReadingRecord()
                record.file = request.book.filename; record.title = request.book.title
                record.selected = request.previous?.selected ?? request.selection
                record.context = request.previous?.context ?? request.context
                record.answer = output; record.kind = request.task == .document ? "file" : "explain"
                record.provider = Provider.deepSeek.rawValue; record.model = request.settings.model
                record.language = request.settings.english ? "en" : "zh"; record.page = request.page
                if request.task == .followup {
                    let prompt = "Q: " + TextLimits.prefix(request.question, 1000) + "\n\n"
                    let budget = max(0, 20000 - output.utf16.count)
                    record.answer = TextLimits.prefix(prompt, budget) + output
                }
                guard record.valid else { throw MobileDocument.invalid }
                try library?.update { $0.records.insert(record, at: 0) }
                answer = output; activeRecord = record; question = ""; refresh()
            } catch is CancellationError { }
            catch { report(error) }
        }
    }
    private func setProgress(_ done: Int, _ total: Int) { progress = "\(done) / \(total)" }
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
