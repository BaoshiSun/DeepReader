// SPDX-License-Identifier: AGPL-3.0-or-later
import AppKit
import Combine
import DeepReaderCore

@MainActor public final class ReaderModel: ObservableObject {
    public let store: LibraryStore
    public let credentials: Credentials
    public let reader = DocumentReader()
    public var pdf: PDFReader { reader.pdf }
    public let ai: AIClient
    @Published public var settings: Settings
    @Published public var tab = 0
    @Published public var status = ""
    @Published public var busy = false
    @Published public var opening = false
    @Published public var isPDF = true
    @Published public var selected = ""
    @Published public var answer = ""
    @Published public var followup = ""
    @Published public var book: Book?
    @Published public var records: [ReadingRecord] = []
    @Published public var books: [Book] = []
    @Published public var historySearch = ""
    @Published public var historyID: String?
    @Published public var bookSearch = ""
    @Published public var bookFilter = 0
    @Published public var bookID: String?
    @Published public var summaryScope = 0
    @Published public var summaryDate = Date()
    @Published public var summaryPreview = ""
    @Published public var summaryAnswer = ""
    @Published public var keyDraft = ""
    @Published public var modelDraft = ""
    @Published public var dirty = false
    public var openAction: (() -> Void)?
    public var openURLAction: ((URL) -> Void)?
    public var floatAction: (() -> Void)?
    public var hideAction: (() -> Void)?
    public var languageAction: (() -> Void)?
    public var layoutAction: (() -> Void)?
    public var beforeArchive: (() -> Bool)?
    private var task: Task<Void, Never>?
    private var job = UUID()
    private var currentRecord: ReadingRecord?
    private var captured: ReaderSelection?
    private var badRecords = 0
    private var prepared: (source: String, stats: String, title: String, scope: Int, file: String, settings: Settings)?
    public var canSummarize: Bool { prepared != nil }
    public var history: ReadingRecord? { records.first { $0.id == historyID } }
    public var libraryBook: Book? { books.first { $0.id == bookID } }
    public var filteredBooks: [Book] { books.filter { $0.matches(bookSearch, filter: bookFilter) } }

    public init(store: LibraryStore, credentials: Credentials = KeychainCredentials(), ai: AIClient = AIClient()) {
        self.store = store; self.credentials = credentials; self.ai = ai
        self.settings = (try? store.settings()) ?? Settings()
        modelDraft = settings.model
        do { _ = try store.settings(); try reload() }
        catch { show(error) }
        if !settings.onboardingSeen { tab = 4; guide() }
    }
    public func t(_ zh: String, _ en: String) -> String { settings.english ? en : zh }
    public func show(_ error: Error) {
        status = (error as? ReaderError)?.message(settings.english) ?? t("操作失败，请检查文件权限或可用空间。", "Operation failed. Check file permissions or available disk space.")
    }
    public func persist() { do { try store.saveSettings(settings) } catch { show(error) } }
    public func reload() throws {
        let loaded = try store.records(), library = try store.books()
        records = loaded.items; books = library.items; badRecords = loaded.unreadable
        if let id = book?.id { book = books.first { $0.id == id } }
        if loaded.unreadable + library.unreadable > 0 {
            status = t("部分本地记录损坏，已跳过；原文件保留。", "Some local records could not be read and were skipped; originals were kept.")
        }
    }
    public func didOpen() throws {
        cancel(); captured = nil; currentRecord = nil; selected = ""; answer = ""; followup = ""
        clearSummary(); dirty = false; book = nil
        isPDF = reader.isPDF
        if let url = reader.url { book = try store.ensureBook(url) }
        try reload(); status = t("选中文字后按 ⌘⇧D 解释。", "Select text and press ⌘⇧D to explain.")
    }
    public func guide() {
        status = t("① 选择服务和模型，填写自己的 API Key 并保存。② 打开文档或电子书，选词后按 ⌘⇧D。③ 可继续追问、评分和归档。AI 请求会发送所选文字及上下文；全文总结会发送提取的全文。", "1. Choose a provider and model, add your own API key and save. 2. Open a document or ebook, select text and press ⌘⇧D. 3. Ask follow-ups, rate and archive books. AI lookups send your selection and context; document summaries send extracted document text.")
        settings.onboardingSeen = true; persist()
    }
    public func language() { settings.english.toggle(); clearSummary(); persist(); languageAction?() }
    public func chooseProvider(_ provider: Provider) {
        settings.provider = provider; modelDraft = settings.model; keyDraft = ""; clearSummary()
    }
    public func saveConfiguration() {
        do {
            let model = modelDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            guard Settings.validModel(model) else { throw ReaderError("模型 ID 格式无效。", "Invalid model ID.") }
            var next = settings; next.models[next.provider.rawValue] = model
            next = try next.validated()
            let key = keyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty { try credentials.save(key, for: next.provider) }
            try store.saveSettings(next); settings = next; keyDraft = ""; clearSummary()
            status = t("设置已保存。空白密钥框会保留已有密钥。", "Settings saved. An empty key field keeps the existing key.")
        } catch { show(error) }
    }
    public func removeKey() {
        do { try credentials.remove(settings.provider); keyDraft = ""; status = t("此服务的密钥已删除。", "This provider's key was removed.") }
        catch { show(error) }
    }
    public func chooseArchiveFolder() {
        let panel = NSOpenPanel(); panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.canCreateDirectories = true
        panel.message = t("选择归档根目录，文件将复制到对应星级子目录。", "Choose the archive folder. Files are copied into star-rating subfolders.")
        if panel.runModal() == .OK, let url = panel.url { settings.archiveFolder = url.path; persist() }
    }
    private func begin(_ work: @escaping @MainActor (UUID) async throws -> Void) {
        cancel(); busy = true; let id = UUID(); job = id
        status = t("正在请求 AI…", "Requesting AI…")
        task = Task { [weak self] in
            guard let self = self else { return }
            do { try await work(id) }
            catch is CancellationError { }
            catch { if self.job == id { self.show(error) } }
            if self.job == id { self.busy = false; self.task = nil }
        }
    }
    public func cancel() { task?.cancel(); task = nil; job = UUID(); busy = false }
    public func stop() { cancel(); status = t("已取消。", "Cancelled.") }
    public func explain() {
        guard !busy, !opening else { return }
        do {
            let configuration = try settings.validated(), key = try credentials.read(settings.provider)
            _ = try AIClient.request(settings: configuration, key: key, task: .explain, source: "validate")
            let file = reader.url?.path ?? "", title = reader.url?.lastPathComponent ?? ""
            begin { [weak self] id in
                guard let self = self else { return }
                let selection = try await self.reader.selected()
                try Task.checkCancellation(); guard self.job == id else { return }
                self.captured = selection; self.selected = selection.text; self.answer = ""; self.followup = ""; self.currentRecord = nil; self.tab = 0
                let response = try await self.ai.complete(settings: configuration, key: key, task: .explain,
                    source: "Selected text:\n\(selection.text)\n\nSource context (⟦…⟧ marks the selection):\n\(selection.context)")
                try Task.checkCancellation(); guard self.job == id else { return }
                var record = ReadingRecord(); record.file = file; record.title = title; record.page = selection.page
                record.selected = selection.text; record.context = selection.context; record.answer = response
                record.provider = configuration.provider.rawValue; record.model = configuration.model; record.language = configuration.english ? "en" : "zh"
                self.answer = response
                try self.store.saveRecord(record); self.currentRecord = record; try self.reload()
                self.status = self.t("解释已自动保存。", "Explanation saved automatically.")
            }
        } catch { show(error); if (try? credentials.read(settings.provider)) == "" { tab = 4 } }
    }
    public func ask() {
        guard !busy, let original = currentRecord else { status = t("请先解释一次选中文字。", "Explain a selection first."); return }
        do {
            let question = followup.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !question.isEmpty, question.utf16.count <= 1200, original.answer.utf16.count <= 12000 else {
                throw ReaderError("追问限 1200 字符；对话过长时请重新选词。", "Follow-ups allow 1,200 characters. Start a new lookup if the conversation is too long.")
            }
            let configuration = settings, key = try credentials.read(settings.provider)
            begin { [weak self] id in
                guard let self = self else { return }
                let response = try await self.ai.complete(settings: configuration, key: key, task: .followup,
                    source: "Original selection:\n\(original.selected)\nSource context:\n\(original.context)\nPrevious conversation:\n\(original.answer)\nUser follow-up:\n\(question)")
                try Task.checkCancellation(); guard self.job == id else { return }
                var record = original
                record.answer += "\n\n— \(self.t("追问", "Follow-up")) —\n\(question)\n[\(configuration.provider.rawValue) / \(configuration.model)]\n\(response)"
                guard record.valid else { throw ReaderError("对话已达到长度上限，请重新选词。", "The conversation reached its length limit. Start a new lookup.") }
                try self.store.saveRecord(record); self.currentRecord = record; self.answer = record.answer; self.followup = ""
                try self.reload(); self.status = self.t("追问已保存到原查询。", "Follow-up saved with the original lookup.")
            }
        } catch { show(error) }
    }
    public func highlight() {
        guard !busy, !opening else { return }
        if !reader.isPDF {
            begin { [weak self] id in
                guard let self = self, let book = self.book, let fingerprint = self.reader.ebook.book?.fingerprint else { return }
                let captured: ReaderSelection
                if let previous = self.captured { captured = previous } else { captured = try await self.reader.selected() }
                try Task.checkCancellation(); guard self.job == id, case .ebook(let selection) = captured else { return }
                let next = try self.reader.ebook.toggled(selection)
                try self.store.saveHighlights(next, bookID: book.id, fingerprint: fingerprint)
                try await self.reader.ebook.setMarks(next)
                guard self.job == id else { return }
                self.status = self.t("高亮已切换并保存到本机阅读记录。", "Highlight toggled and saved to your local reading data.")
            }
            return
        }
        do {
            let selection: SelectedText
            if case .pdf(let previous) = captured { selection = previous } else { selection = try pdf.selected() }
            try pdf.toggleHighlight(selection); dirty = pdf.dirty
            status = t("高亮已切换，点击“保存 PDF”写入批注。", "Highlight toggled. Save the PDF to persist annotations.")
        } catch { show(error) }
    }
    public func savePDF() { guard reader.isPDF else { status = t("电子书高亮已自动保存在本机。", "Ebook highlights are saved locally automatically."); return }; do { try pdf.save(); dirty = pdf.dirty; status = t("PDF 已保存。", "PDF saved.") } catch { show(error) } }
    public func rate(_ rating: Int) { updateBook(rating: rating) }
    public func finish(_ value: Bool) { updateBook(finished: value) }
    private func updateBook(rating: Int? = nil, finished: Bool? = nil) {
        guard !busy, !opening, let book = book else { return }
        do { self.book = try store.updateBook(id: book.id, rating: rating, finished: finished); try reload() }
        catch { show(error) }
    }
    public func archive() {
        guard !busy, !opening, let book = book, let source = reader.url else { return }
        guard book.rating > 0 else { status = t("请先为当前文件 评分。", "Rate the current file first."); return }
        if settings.archiveFolder.isEmpty { chooseArchiveFolder() }
        guard !settings.archiveFolder.isEmpty, beforeArchive?() ?? true else { return }
        let destination = URL(fileURLWithPath: settings.archiveFolder, isDirectory: true), store = self.store
        begin { [weak self] id in
            let worker = Task.detached { try store.archive(book: book, source: source, root: destination) }
            let result = try await withTaskCancellationHandler(operation: { try await worker.value }, onCancel: { worker.cancel() })
            guard let self = self, self.job == id else { return }
            try self.reload(); self.status = self.t("归档完成，原文件保留：", "Archived; original kept: ") + result.path
        }
        status = t("正在复制文件 到归档文件夹…", "Copying the file to the archive folder…")
    }
    public func clearSummary() { prepared = nil; summaryPreview = ""; summaryAnswer = "" }
    public func prepareSummary() {
        guard !opening else { return }
        do {
            try reload()
            guard badRecords == 0 else { throw ReaderError("有无法读取的历史记录，请修复后再统计。", "Some history records are unreadable. Repair them before summarizing.") }
            let total = records.filter { $0.kind == "explain" }.count
            let source: String, stats: String, title: String, file: String
            var notice = ""
            if summaryScope == 0 {
                guard let book = book else { throw ReaderError("请先打开文档或电子书。", "Open a document or ebook first.") }
                let extracted = try reader.fullText(); source = extracted.text; file = reader.url?.path ?? ""
                title = book.title; stats = ReadingStats(records, book: book).text(total: total, english: settings.english)
                if extracted.blankPages > 0 { notice = t("\n其中 \(extracted.blankPages) 页没有可提取文字，这些页面未包含在总结中。", "\n\(extracted.blankPages) pages have no extractable text and are omitted from the summary.") }
            } else {
                guard let range = Dates.range(scope: summaryScope, anchor: Dates.day(summaryDate)) else { return }
                let selected = records.filter { ["explain", "file"].contains($0.kind) && range.contains(String($0.time.prefix(10))) }
                guard !selected.isEmpty else { throw ReaderError("此日期范围内没有已保存记录。", "No saved records in this date range.") }
                source = selected.map { "\($0.time) · \($0.title)\n\($0.selected)\n\($0.answer)" }.joined(separator: "\n\n---\n\n")
                file = ""; title = "\(range.lowerBound) – \(range.upperBound)"
                stats = ReadingStats(records, range: range).text(total: total, english: settings.english)
            }
            guard source.utf16.count <= 2000000 else { throw ReaderError("数据过多，请选择更小的范围。", "Too much data. Choose a smaller range.") }
            let requests = AIClient.summaryRequests(chunks: TextLimits.chunks(source).count)
            prepared = (source, stats, title, summaryScope, file, settings)
            summaryPreview = title + "\n\n" + stats + "\n\n" + t("将发送 \(source.utf16.count) 字符，预计 \(requests) 次 API 请求。费用或额度由服务商决定。", "Will send \(source.utf16.count) characters in approximately \(requests) API requests. Provider pricing or quotas apply.") + notice
            summaryAnswer = stats + notice
        } catch { clearSummary(); show(error) }
    }
    public func summarize() {
        guard !busy, let snapshot = prepared else { return }
        do {
            let key = try credentials.read(snapshot.settings.provider)
            _ = try AIClient.request(settings: snapshot.settings, key: key, task: .part, source: "validate")
            begin { [weak self] id in
                guard let self = self else { return }
                let response = try await self.ai.summarize(settings: snapshot.settings, key: key, source: snapshot.source, review: snapshot.scope > 0) { [self] done, count in
                    await MainActor.run { guard self.job == id else { return }; self.status = self.t("正在总结：\(done)/\(count)", "Summarizing: \(done)/\(count)") }
                }
                try Task.checkCancellation(); guard self.job == id else { return }
                var record = ReadingRecord(); record.kind = ["file", "day", "week", "month"][snapshot.scope]
                record.file = snapshot.file; record.title = snapshot.title
                record.answer = snapshot.stats + "\n\n" + response
                record.provider = snapshot.settings.provider.rawValue; record.model = snapshot.settings.model; record.language = snapshot.settings.english ? "en" : "zh"
                self.summaryAnswer = record.answer; try self.store.saveRecord(record); try self.reload()
                self.status = self.t("总结已保存到历史。", "Summary saved to History.")
            }
        } catch { show(error) }
    }
    public func export(_ text: String, name: String) {
        guard !text.isEmpty else { return }
        let panel = NSSavePanel(); panel.nameFieldStringValue = name + ".txt"; panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            do { try text.write(to: url, atomically: true, encoding: .utf8); status = t("已导出。", "Exported.") } catch { show(error) }
        }
    }
    public func exportBooks() {
        export(Book.overview(filteredBooks, english: settings.english) + "\n\n" + filteredBooks.map { $0.text(records: records, english: settings.english) }.joined(separator: "\n\n────────\n\n"), name: "DeepReader-Books")
    }
    public func openBook(_ book: Book) {
        guard let url = store.openPath(book) else { status = t("原文件和归档副本均不存在。", "Neither the original nor an archived copy exists."); return }
        openURLAction?(url)
    }
    public func deleteHistory() {
        guard let record = history else { return }
        let alert = NSAlert(); alert.messageText = t("删除这条查询及其追问？", "Delete this lookup and its follow-ups?")
        alert.addButton(withTitle: t("删除", "Delete")); alert.addButton(withTitle: t("取消", "Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do {
            try store.deleteRecord(record.id)
            if currentRecord?.id == record.id { currentRecord = nil }
            historyID = nil; try reload(); clearSummary()
        } catch { show(error) }
    }
}
