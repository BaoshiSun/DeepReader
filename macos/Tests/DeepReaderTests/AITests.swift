// SPDX-License-Identifier: AGPL-3.0-or-later
import XCTest
import AppKit
import PDFKit
@testable import DeepReaderCore
@testable import DeepReaderDesktop

private final class MockProtocol: URLProtocol {
    static let lock = NSLock()
    static var handler: ((MockProtocol) -> Void)?
    static func use(_ value: @escaping (MockProtocol) -> Void) { lock.lock(); handler = value; lock.unlock() }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { Self.lock.lock(); let handle = Self.handler; Self.lock.unlock(); handle?(self) }
    override func stopLoading() {}
    func respond(_ text: String, status: Int = 200, finish: String = "stop") {
        let data = try! JSONSerialization.data(withJSONObject: ["choices": [["finish_reason": finish, "message": ["content": text]]]])
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data); client?.urlProtocolDidFinishLoading(self)
    }
}
private final class MemoryCredentials: Credentials {
    func read(_ provider: Provider) throws -> String { "offline-test-credential" }
    func save(_ value: String, for provider: Provider) throws {}
    func remove(_ provider: Provider) throws {}
}

final class AITests: XCTestCase {
    func testStoreEditionRejectsRestoredUnsupportedProvidersBeforeRequestCreation() throws {
        var settings = Settings()
        for (provider, host) in [(Provider.gemini, "generativelanguage.googleapis.com"),
                                 (Provider.openRouter, "openrouter.ai")] {
            settings.provider = provider
            XCTAssertThrowsError(try AIClient.request(settings: settings, key: "offline-test", task: .explain,
                                                     source: "sample", appStore: true))
            XCTAssertEqual(try AIClient.request(settings: settings, key: "offline-test", task: .explain,
                                               source: "sample", appStore: false).url?.host, host)
        }
        settings.provider = .deepSeek
        XCTAssertEqual(try AIClient.request(settings: settings, key: "offline-test", task: .explain,
                                           source: "sample", appStore: true).url?.host, "api.deepseek.com")
    }
    @MainActor func testDeniedSharingNeverStartsNetworkAndConsentIsPerOperation() async throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("DeepReader-consent-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try LibraryStore(root: root)
        var allowed = false, prompts: [(Provider, AISharingKind)] = []
        let model = ReaderModel(store: store, credentials: MemoryCredentials(), ai: client()) { settings, kind in
            prompts.append((settings.provider, kind)); return allowed
        }
        let url = root.appendingPathComponent("consent.pdf"); try SmokeTest.makePDF(at: url)
        try model.pdf.open(url); try model.didOpen()
        let page = model.pdf.view.document!.page(at: 0)!, text = page.string! as NSString
        model.pdf.view.setCurrentSelection(page.selection(for: text.range(of: "bank", options: .backwards)), animate: false)
        MockProtocol.use { _ in XCTFail("A denied action made a network request") }
        model.explain(); try await waitUntilIdle(model)
        XCTAssertTrue(model.records.isEmpty); XCTAssertEqual(prompts.last?.1, .selection)
        model.prepareSummary(); model.summarize(); try await waitUntilIdle(model)
        XCTAssertTrue(model.records.isEmpty); XCTAssertEqual(prompts.last?.1, .document)
        allowed = true; MockProtocol.use { $0.respond("A bank lends money.") }
        model.explain(); try await waitUntilIdle(model); XCTAssertEqual(model.records.count, 1)
        allowed = false; MockProtocol.use { _ in XCTFail("Earlier consent authorized a later action") }
        model.chooseProvider(.gemini); model.followup = "Why?"; model.ask(); try await waitUntilIdle(model)
        XCTAssertEqual(prompts.last?.0, .gemini); XCTAssertEqual(prompts.last?.1, .followup)
        XCTAssertEqual(model.records.count, 1); XCTAssertFalse(model.followup.isEmpty)
        model.summaryScope = 1; model.prepareSummary(); XCTAssertTrue(model.canSummarize)
        model.summarize(); try await waitUntilIdle(model)
        XCTAssertEqual(prompts.last?.1, .history); XCTAssertEqual(model.records.count, 1)
    }
    private func client() -> AIClient {
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [MockProtocol.self]; return AIClient(configuration: config)
    }
    func testOfflineTransportSuccess() async throws {
        MockProtocol.use { $0.respond("Contextual answer") }
        let answer = try await client().complete(settings: Settings(), key: "offline-test", task: .explain, source: "sample")
        XCTAssertEqual(answer, "Contextual answer")
    }
    func testOfflineTransportCancellation() async throws {
        let started = expectation(description: "request started")
        MockProtocol.use { _ in started.fulfill() }
        let ai = client()
        let task = Task { try await ai.complete(settings: Settings(), key: "offline-test", task: .explain, source: "sample") }
        await fulfillment(of: [started], timeout: 5); task.cancel()
        do { _ = try await task.value; XCTFail("Cancelled request succeeded") } catch is CancellationError { }
    }
    func testOfflineProviderErrorsAreSanitized() async {
        MockProtocol.use { $0.respond("sensitive-provider-response", status: 429) }
        do { _ = try await client().complete(settings: Settings(), key: "offline-test", task: .explain, source: "sample"); XCTFail("Error response succeeded") }
        catch { XCTAssertFalse(error.localizedDescription.contains("sensitive-provider-response")); XCTAssertFalse(error.localizedDescription.contains("offline-test")) }
    }
    func testAllSummaryChunksAreProcessed() async throws {
        var count = 0
        MockProtocol.use { protocolInstance in count += 1; protocolInstance.respond("section note") }
        let source = String(repeating: "Reading material. ", count: 3000)
        let chunks = TextLimits.chunks(source).count
        _ = try await client().summarize(settings: Settings(), key: "offline-test", source: source, review: false) { _, _ in }
        XCTAssertEqual(count, AIClient.summaryRequests(chunks: chunks))
    }
    @MainActor func testLookupFollowupPersistenceAndLanguage() async throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("DeepReader-AI-tests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try LibraryStore(root: root), model = ReaderModel(store: store, credentials: MemoryCredentials(), ai: client(), confirmSharing: { _, _ in true })
        let url = root.appendingPathComponent("example.pdf"); try SmokeTest.makePDF(at: url)
        try model.pdf.open(url); try model.didOpen()
        let page = model.pdf.view.document!.page(at: 0)!, source = page.string! as NSString
        model.pdf.view.setCurrentSelection(page.selection(for: source.range(of: "bank", options: .backwards)), animate: false)
        MockProtocol.use { $0.respond("银行：在这里批准了贷款。") }
        model.explain(); try await waitUntilIdle(model)
        XCTAssertEqual(model.records.count, 1); let id = model.records.first?.id
        model.followup = "Why?"; model.language()
        MockProtocol.use { $0.respond("The loan provides the financial context.") }
        model.ask(); try await waitUntilIdle(model)
        XCTAssertEqual(model.records.count, 1); XCTAssertEqual(model.records.first?.id, id)
        XCTAssertTrue(model.answer.contains("The loan")); XCTAssertEqual(ReadingStats(model.records).lookups, 1)
        XCTAssertTrue(model.followup.isEmpty)
        let reloaded = ReaderModel(store: store, credentials: MemoryCredentials(), ai: client(), confirmSharing: { _, _ in true })
        XCTAssertTrue(reloaded.settings.english); XCTAssertEqual(reloaded.records.count, 1)
        XCTAssertEqual(reloaded.tab, 0, "Onboarding must not repeat")
    }
    @MainActor private func waitUntilIdle(_ model: ReaderModel) async throws {
        for _ in 0..<500 { if !model.busy { return }; try await Task.sleep(nanoseconds: 10000000) }
        model.stop(); XCTFail("AI task did not finish")
    }
    @MainActor func testEbookLookupFollowupAndFullDocumentSummary() async throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("DeepReader-Ebook-AI-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try LibraryStore(root: root), model = ReaderModel(store: store, credentials: MemoryCredentials(), ai: client(), confirmSharing: { _, _ in true })
        let book = try EBookDocument.load(EBookTests.fixtures.appendingPathComponent("garden.epub"))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 850, height: 700), styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = model.reader.view; window.orderFront(nil); defer { window.orderOut(nil) }
        model.reader.openEBook(book, marks: []); try model.didOpen()
        for _ in 0..<600 { if model.reader.ebook.ready { break }; try await Task.sleep(nanoseconds: 50000000) }
        XCTAssertTrue(model.reader.ebook.ready)
        try await model.reader.ebook.selectForTesting("The bank approved the loan.")
        MockProtocol.use { request in
            let body = request.request.httpBody.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            if !body.isEmpty { XCTAssertTrue(body.contains("river bank")) }
            request.respond("银行：这里是批准贷款的金融机构。")
        }
        model.explain(); try await waitUntilIdle(model)
        XCTAssertEqual(model.records.count, 1); XCTAssertEqual(model.records.first?.file, book.url.path)
        XCTAssertTrue(model.records.first?.context.contains("⟦The bank approved the loan.⟧") == true)
        model.followup = "Explain briefly in English"; model.language()
        MockProtocol.use { $0.respond("The loan shows that bank means a financial institution.") }
        model.ask(); try await waitUntilIdle(model); XCTAssertEqual(ReadingStats(model.records).lookups, 1)
        model.prepareSummary(); XCTAssertTrue(model.canSummarize)
        MockProtocol.use { $0.respond("The reading garden illustrates context and saved reading progress.") }
        model.summarize(); try await waitUntilIdle(model)
        XCTAssertEqual(model.records.filter { $0.kind == "file" }.count, 1)
        XCTAssertTrue(model.summaryAnswer.contains("reading garden"))
    }
}
