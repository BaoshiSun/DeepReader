// SPDX-License-Identifier: AGPL-3.0-or-later
import AppKit
import Combine
import DeepReaderCore

@MainActor public final class ReaderModel: ObservableObject {
    public let store: LibraryStore
    public let fileAccess: FileAccessStore
#if !OFFLINE_QWEN
    public let credentials: Credentials
#endif
    public let reader = DocumentReader()
    public var pdf: PDFReader { reader.pdf }
    public let ai: AIClient
    private let confirmSharing: @MainActor (Settings, AISharingKind) -> AISharingDecision
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
    @Published public var endpointDraft = ""
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

#if OFFLINE_QWEN
    public init(store: LibraryStore, ai: AIClient = AIClient()) {
        self.store = store; self.ai = ai
        self.fileAccess = FileAccessStore(root: store.root)
        self.confirmSharing = { _, _ in .cancel }
        self.settings = (try? store.settings()) ?? Settings()
        do { _ = try store.settings(); try reload() } catch { show(error) }
        if !settings.onboardingSeen { tab = 4; guide() }
    }
#else
    public init(store: LibraryStore, credentials: Credentials = KeychainCredentials(), ai: AIClient = AIClient(),
                confirmSharing: @escaping @MainActor (Settings, AISharingKind) -> AISharingDecision = AISharingKind.confirm) {
        self.store = store; self.credentials = credentials; self.ai = ai
        self.fileAccess = FileAccessStore(root: store.root)
        self.confirmSharing = confirmSharing
        self.settings = (try? store.settings()) ?? Settings()
        settings.applyProviderAvailability()
        modelDraft = settings.model; endpointDraft = settings.endpointText
        do { _ = try store.settings(); try reload() }
        catch { show(error) }
        if !settings.onboardingSeen { tab = 4; guide() }
        QuestionCredits.shared.start()
    }
#endif
    public func t(_ zh: String, _ en: String) -> String { settings.english ? en : zh }
    public func show(_ error: Error) {
        status = (error as? ReaderError)?.message(settings.english) ?? t("操作失败，请检查文件权限或可用空间。", "Operation failed. Check file permissions or available disk space.")
    }
    public func persist() { do { try store.saveSettings(settings) } catch { show(error) } }
    public func setWorldKnowledge(_ enabled: Bool) {
        guard !busy else { return }
        do {
            var next = settings; next.useWorldKnowledge = enabled
            try store.saveSettings(next); settings = next; clearSummary()
        } catch { show(error) }
    }
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
#if OFFLINE_QWEN
        status = t("免费本机 AI：打开书籍，选中文字后按 ⌘⇧D。无需账户、网络或 API Key。答案可能不准确，请核对原文。", "Free on-device AI: open a book, select text and press ⌘⇧D. No account, network or API key. Answers may be inaccurate; check the source.")
        settings.onboardingSeen = true; persist()
#else
        if OrdinaryQuestions.enabled {
            status = t("打开书籍、选择文字即可解释。普通问答在设置中购买次数，无需填写 API Key。", "Open a book and select text to explain it. Purchase ordinary question credits in Settings; no API key is needed.")
            settings.onboardingSeen = true; persist(); return
        }
        status = t("① 选择服务和模型，填写自己的 API Key 并保存。② 打开文档或电子书，选词后按 ⌘⇧D。③ 可继续追问、评分和归档。AI 请求会发送所选文字及上下文；全文总结会发送提取的全文。", "1. Choose a provider and model, add your own API key and save. 2. Open a document or ebook, select text and press ⌘⇧D. 3. Ask follow-ups, rate and archive books. AI lookups send your selection and context; document summaries send extracted document text.")
        settings.onboardingSeen = true; persist()
#endif
    }
    public func language() { settings.english.toggle(); clearSummary(); persist(); languageAction?() }
#if OFFLINE_QWEN
    public func openSample() {
        do {
            guard let bundled = Bundle.main.url(forResource: "Reading-Garden", withExtension: "txt") else {
                throw ReaderError("安装包中缺少示例文章。", "The bundled sample is missing.")
            }
            // A bundled resource cannot receive a user-selected security-scoped bookmark.
            // Keep an editable sample copy in our container, preserving any existing copy.
            let folder = store.root.appendingPathComponent("Examples", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appendingPathComponent("Reading-Garden.txt")
            if !FileManager.default.fileExists(atPath: url.path) { try FileManager.default.copyItem(at: bundled, to: url) }
            openURLAction?(url)
        } catch { show(error) }
    }
#endif
#if !OFFLINE_QWEN
    public func chooseProvider(_ provider: Provider) {
        guard Provider.available().contains(provider) else { return }
        settings.provider = provider; settings.applyProviderAvailability()
        modelDraft = settings.model; endpointDraft = settings.endpointText; keyDraft = ""; clearSummary()
    }
    public func saveConfiguration() {
        do {
            let model = modelDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            guard Settings.validModel(model) else { throw ReaderError("模型 ID 格式无效。", "Invalid model ID.") }
            var next = settings; next.models[next.provider.rawValue] = model
            next.setEndpoint(endpointDraft)
            next = try next.validated()
            _ = try next.requestEndpoint()
            let key = keyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty { try credentials.save(key, for: next) }
            try store.saveSettings(next); settings = next; keyDraft = ""; clearSummary()
            status = t("设置已保存。空白密钥框会保留已有密钥。", "Settings saved. An empty key field keeps the existing key.")
        } catch { show(error) }
    }
    public func removeKey() {
        do { try credentials.remove(settings); keyDraft = ""; status = t("此服务的密钥已删除。", "This provider's key was removed.") }
        catch { show(error) }
    }
#endif
    public func chooseArchiveFolder() {
        let panel = NSOpenPanel(); panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.canCreateDirectories = true
        panel.message = t("选择归档根目录，文件将复制到对应星级子目录。", "Choose the archive folder. Files are copied into star-rating subfolders.")
        if panel.runModal() == .OK, let url = panel.url {
            do { let access = try fileAccess.acquire(url); settings.archiveFolder = access.url.path; persist() }
            catch { show(error) }
        }
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
#if OFFLINE_QWEN
            let configuration = settings, key = ""
#else
            let configuration = try settings.validated(), key = OrdinaryQuestions.enabled ? "" : try credentials.read(settings)
            if !OrdinaryQuestions.enabled { _ = try AIClient.request(settings: configuration, key: key, task: .explain, source: "validate") }
#endif
            let file = reader.url?.path ?? "", title = reader.url?.lastPathComponent ?? ""
            begin { [weak self] id in
                guard let self = self else { return }
                let selection = try await self.reader.selected()
                try Task.checkCancellation(); guard self.job == id else { return }
                guard self.allowSharing(configuration, .selection) else { return }
                self.captured = selection; self.selected = selection.text; self.answer = ""; self.followup = ""; self.currentRecord = nil; self.tab = 0
#if OFFLINE_QWEN
                let source = AIClient.source(selection: selection.text, context: selection.context)
#else
                let source = OrdinaryQuestions.enabled ? OrdinaryQuestions.source(selection: selection.text, context: selection.context) : "Selected text:\n\(selection.text)\n\nSource context (⟦…⟧ marks the selection):\n\(selection.context)"
#endif
                let response = try await self.ai.complete(settings: configuration, key: key, task: .explain, source: source)
                try Task.checkCancellation(); guard self.job == id else { return }
                var record = ReadingRecord(); record.file = file; record.title = title; record.page = selection.page
                record.selected = selection.text; record.context = selection.context; record.answer = response
                record.provider = self.answerProvider(configuration); record.model = self.answerModel(configuration); record.language = configuration.english ? "en" : "zh"
                self.answer = response
                try self.store.saveRecord(record); self.currentRecord = record; try self.reload()
                self.status = self.t("解释已自动保存。", "Explanation saved automatically.")
            }
        } catch { show(error)
#if !OFFLINE_QWEN
            if (try? credentials.read(settings)) == "" { tab = 4 }
#endif
        }
    }
    public func ask() {
        guard !busy, !opening, let original = currentRecord else { status = t("请先解释一次选中文字。", "Explain a selection first."); return }
        do {
            let question = followup.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !question.isEmpty, question.utf16.count <= 1200, original.answer.utf16.count <= 12000 else {
                throw ReaderError("追问限 1200 字符；对话过长时请重新选词。", "Follow-ups allow 1,200 characters. Start a new lookup if the conversation is too long.")
            }
#if OFFLINE_QWEN
            let configuration = settings, key = ""
#else
            let configuration = settings, key = OrdinaryQuestions.enabled ? "" : try credentials.read(settings)
#endif
            guard allowSharing(configuration, .followup) else { return }
            begin { [weak self] id in
                guard let self = self else { return }
#if OFFLINE_QWEN
                let source = AIClient.source(selection: original.selected, context: original.context, previous: original.answer, question: question)
#else
                let source = OrdinaryQuestions.enabled ? OrdinaryQuestions.source(selection: original.selected, context: original.context, previous: original.answer, question: question) : "Original selection:\n\(original.selected)\nSource context:\n\(original.context)\nPrevious conversation:\n\(original.answer)\nUser follow-up:\n\(question)"
#endif
                let response = try await self.ai.complete(settings: configuration, key: key, task: .followup, source: source)
                try Task.checkCancellation(); guard self.job == id else { return }
                var record = original
                record.answer += "\n\n— \(self.t("追问", "Follow-up")) —\n\(question)\n[\(self.answerProvider(configuration)) / \(self.answerModel(configuration))]\n\(response)"
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
                self.captured = captured
                try await self.reader.ebook.setMarks(next)
                guard self.job == id else { return }
                self.status = self.t("高亮已切换并保存到本机阅读记录。", "Highlight toggled and saved to your local reading data.")
            }
            status = t("正在保存高亮…", "Saving highlight…")
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
        let archiveAccess: FileAccess, sourceAccess: FileAccess
        do {
            archiveAccess = try fileAccess.acquire(URL(fileURLWithPath: settings.archiveFolder, isDirectory: true), restoring: true)
            sourceAccess = try fileAccess.acquire(source, restoring: true)
        } catch { show(error); chooseArchiveFolder(); return }
        let store = self.store, fileAccess = self.fileAccess
        begin { [weak self] id in
            let worker = Task.detached {
                try withExtendedLifetime((archiveAccess, sourceAccess)) {
                    let result = try store.archive(book: book, source: sourceAccess.url, root: archiveAccess.url)
                    _ = try fileAccess.acquire(result)
                    return result
                }
            }
            let result = try await withTaskCancellationHandler(operation: { try await worker.value }, onCancel: { worker.cancel() })
            guard let self = self, self.job == id else { return }
            try self.reload(); self.status = self.t("归档完成，原文件保留：", "Archived; original kept: ") + result.path
        }
        status = t("正在复制文件 到归档文件夹…", "Copying the file to the archive folder…")
    }
    public func clearSummary() { prepared = nil; summaryPreview = ""; summaryAnswer = "" }
    public func prepareSummary() {
#if OFFLINE_QWEN
        clearSummary(); show(AIClient.unsupported)
#else
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
#endif
    }
    public func summarize() {
#if OFFLINE_QWEN
        show(AIClient.unsupported)
#else
        guard !OrdinaryQuestions.enabled else { show(OrdinaryQuestions.unsupported); return }
        guard !busy, let snapshot = prepared else { return }
        do {
            let key = try credentials.read(snapshot.settings)
            _ = try AIClient.request(settings: snapshot.settings, key: key, task: .part, source: "validate")
            guard allowSharing(snapshot.settings, snapshot.scope == 0 ? .document : .history) else { return }
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
#endif
    }
    private func allowSharing(_ configuration: Settings, _ kind: AISharingKind) -> Bool {
#if OFFLINE_QWEN
        return true
#else
        guard configuration.sharingRecipient() == settings.sharingRecipient() else { return false }
        if hasAISharingConsent { return true }
        switch confirmSharing(configuration, kind) {
        case .cancel:
            status = t("已取消，未发送给 AI 服务。", "Cancelled. Nothing was sent to the AI service.")
            return false
        case .sendOnce: return configuration.sharingRecipient() == settings.sharingRecipient()
        case .rememberRecipient:
            guard configuration.sharingRecipient() == settings.sharingRecipient() else { return false }
            do {
                var next = settings
                next.aiSharingConsentRecipient = configuration.sharingRecipient()
                next.aiSharingConsentVersion = AISharingKind.consentVersion
                try store.saveSettings(next); settings = next
                return true
            } catch { show(error); return false }
        }
#endif
    }
    private func answerProvider(_ configuration: Settings) -> String {
#if OFFLINE_QWEN
        return "Qwen (on device)"
#else
        return configuration.provider.rawValue
#endif
    }
    private func answerModel(_ configuration: Settings) -> String {
#if OFFLINE_QWEN
        return "Qwen3-0.6B-Q4_K_M"
#else
        return configuration.model
#endif
    }
    public var hasAISharingConsent: Bool {
        settings.aiSharingConsentVersion == AISharingKind.consentVersion &&
            settings.aiSharingConsentRecipient == settings.sharingRecipient()
    }
    public func revokeAISharingConsent() {
        do {
            var next = settings
            next.aiSharingConsentRecipient = nil; next.aiSharingConsentVersion = nil
            try store.saveSettings(next); settings = next; cancel()
            status = t("已撤销 AI 发送授权，下次发送前会重新询问。", "AI sharing permission revoked. The next send will ask again.")
        } catch { show(error) }
    }
    public func export(_ text: String, name: String) {
        guard !text.isEmpty else { return }
        let panel = NSSavePanel(); panel.nameFieldStringValue = name + ".txt"; panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            let access = FileAccess(url)
            do { try withExtendedLifetime(access) { try text.write(to: url, atomically: true, encoding: .utf8) }; status = t("已导出。", "Exported.") } catch { show(error) }
        }
    }
    public func exportBooks() {
        export(Book.overview(filteredBooks, english: settings.english) + "\n\n" + filteredBooks.map { $0.text(records: records, english: settings.english) }.joined(separator: "\n\n────────\n\n"), name: "DeepReader-Books")
    }
    public func openBook(_ book: Book) {
        for path in [book.file, book.archivePath] + Array(book.copies.reversed()) where !path.isEmpty {
            if let access = try? fileAccess.acquire(URL(fileURLWithPath: path), restoring: true) {
                withExtendedLifetime(access) { openURLAction?(access.url) }
                return
            }
        }
        status = t("请重新选择书籍，恢复文件访问权限。", "Select the book again to restore file access.")
        openAction?()
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
