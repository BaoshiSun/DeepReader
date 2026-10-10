// SPDX-License-Identifier: AGPL-3.0-or-later
import XCTest
import PDFKit
import SwiftUI
import ZIPFoundation
import Security
@testable import DeepReaderMobile

final class MobileTests: XCTestCase {
    var root: URL!
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }
    func testKeychainSaveUpdateReloadAndRemove() throws {
        let service = "org.deepreader.ios.tests." + UUID().uuidString
        let credentials = KeychainCredentials(service: service)
        defer { try? credentials.remove(.deepSeek) }
        XCTAssertEqual(try credentials.read(.deepSeek), "")
        let first = "sk-offline-test-" + UUID().uuidString
        let second = "sk-offline-test-" + UUID().uuidString
        try credentials.save(first, for: .deepSeek)
        XCTAssertEqual(try KeychainCredentials(service: service).read(.deepSeek), first)
        try credentials.save(second, for: .deepSeek)
        XCTAssertEqual(try credentials.read(.deepSeek), second)
        try credentials.remove(.deepSeek)
        XCTAssertEqual(try credentials.read(.deepSeek), "")
    }
    @MainActor func testFailedKeyReplacementPreservesSavedStateAndReportsFailure() throws {
        let credentials = FailingCredentials()
        let model = MobileModel(root: root, credentials: credentials)
        XCTAssertFalse(model.hasKey)
        XCTAssertFalse(model.key("sk-offline-test"))
        XCTAssertFalse(model.hasKey)
        XCTAssertTrue(model.error?.contains("-34018") == true)
        credentials.failSave = false
        XCTAssertTrue(model.key("  sk-offline-test  \n"))
        XCTAssertTrue(model.hasKey)
        XCTAssertNil(model.error)
        XCTAssertEqual(credentials.value, "sk-offline-test")
        credentials.failSave = true
        XCTAssertFalse(model.key("sk-replacement"))
        XCTAssertTrue(model.hasKey)
        XCTAssertEqual(credentials.value, "sk-offline-test")
        model.removeKey()
        XCTAssertFalse(model.hasKey)
    }
    func testInvalidKeyDoesNotReplaceExistingKey() throws {
        let credentials = KeychainCredentials(service: "org.deepreader.ios.tests." + UUID().uuidString)
        defer { try? credentials.remove(.deepSeek) }
        let value = "sk-offline-test-" + UUID().uuidString
        try credentials.save(value, for: .deepSeek)
        XCTAssertThrowsError(try credentials.save("invalid key\n", for: .deepSeek))
        XCTAssertEqual(try credentials.read(.deepSeek), value)
    }
    func write(_ name: String, _ text: String) throws -> URL {
        let url = root.appendingPathComponent(name); try Data(text.utf8).write(to: url); return url
    }
    func testImportPersistsRelativePathsAndProtectsOriginal() throws {
        let source = try write("notes.txt", "A river bank. 河岸。")
        let storeRoot = root.appendingPathComponent("library")
        let store = try MobileLibrary(root: storeRoot)
        let first = try store.importFile(source), second = try store.importFile(source)
        XCTAssertNotEqual(first.filename, second.filename)
        XCTAssertFalse(first.filename.contains("/"))
        try store.update { $0.books[0].rating = 4; $0.books[0].position = 1; $0.books[0].highlights = ["bank"] }
        let restored = try MobileLibrary(root: storeRoot)
        XCTAssertEqual(restored.state.books.count, 2)
        XCTAssertEqual(restored.state.books[0].rating, 4)
        XCTAssertEqual(restored.state.books[0].highlights, ["bank"])
        try restored.remove(first)
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: restored.url(first).path))
    }
    func testCorruptStateIsNotOverwritten() throws {
        let store = try MobileLibrary(root: root.appendingPathComponent("library"))
        let file = store.root.appendingPathComponent("library.json")
        let broken = Data("not JSON".utf8); try broken.write(to: file)
        XCTAssertThrowsError(try MobileLibrary(root: store.root))
        XCTAssertEqual(try Data(contentsOf: file), broken)
    }
    func testImportFailureDoesNotLeaveGhostBook() throws {
        let store = try MobileLibrary(root: root.appendingPathComponent("library"))
        let bad = try write("broken.epub", "not a zip")
        XCTAssertThrowsError(try store.importFile(bad))
        XCTAssertTrue(store.state.books.isEmpty)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: store.root.appendingPathComponent("Documents").path).isEmpty)
    }
    func testPathTraversalRejected() throws {
        for path in ["../../bad", "/root", "https://example.com", "a\\b", "%2e%2e/secret"] {
            XCTAssertThrowsError(try EPUBText.path(path))
        }
        XCTAssertEqual(try EPUBText.path("../Text/chapter.xhtml#p", relativeTo: "OPS/nav/toc.xhtml"), "OPS/Text/chapter.xhtml")
        XCTAssertFalse(MobileLibrary.validFilename("../outside.txt"))
    }
    func epub(_ name: String, entries: [(String, String)]) throws -> URL {
        let url = root.appendingPathComponent(name)
        let archive = try Archive(url: url, accessMode: .create)
        for (path, text) in entries {
            let data = Data(text.utf8)
            try archive.addEntry(with: path, type: .file, uncompressedSize: Int64(data.count), compressionMethod: .deflate) { offset, count in
                data.subdata(in: Int(offset)..<(Int(offset)+count))
            }
        }
        return url
    }
    var entries: [(String, String)] {
        [("META-INF/container.xml", "<container><rootfiles><rootfile full-path='OPS/book.opf'/></rootfiles></container>"),
         ("OPS/book.opf", "<package><manifest><item id='b' href='b.xhtml' media-type='application/xhtml+xml'/><item id='a' href='a.xhtml' media-type='application/xhtml+xml'/></manifest><spine><itemref idref='a'/><itemref idref='b'/></spine></package>"),
         ("OPS/a.xhtml", "<html><head><title>First</title><script>hidden</script></head><body><h1>第一章</h1><p>The river bank.</p><script>never shown</script></body></html>"),
         ("OPS/b.xhtml", "<html><head><title>Second</title></head><body><p>End.</p></body></html>")]
    }
    func testEPUBSpineUnicodeAndScriptExclusion() throws {
        let url = try epub("garden.epub", entries: entries)
        let document = try MobileDocument.load(url)
        XCTAssertEqual(document.chapters.map(\.title), ["First", "Second"])
        XCTAssertTrue(document.chapters[0].text.contains("第一章"))
        XCTAssertFalse(try document.fullText().contains("never shown"))
        XCTAssertFalse(try document.fullText().contains("hidden"))
    }
    func testEPUBRejectsEntitiesAndDRM() throws {
        XCTAssertThrowsError(try EPUBXML.parse(Data("<!DOCTYPE x [<!ENTITY leak SYSTEM 'file:///etc/passwd'>]><x>&leak;</x>".utf8)))
        let url = try epub("drm.epub", entries: entries + [("META-INF/encryption.xml", "<encryption><EncryptionMethod Algorithm='unsupported-drm'/></encryption>")])
        XCTAssertThrowsError(try MobileDocument.load(url))
    }
    func testPDFTextAndAnnotationRoundTrip() throws {
        let url = root.appendingPathComponent("sample.pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 400, height: 500))
        let data = renderer.pdfData { context in context.beginPage(); NSString(string: "The bank approved the loan.").draw(at: CGPoint(x: 30, y: 30), withAttributes: [.font: UIFont.systemFont(ofSize: 18)]) }
        try data.write(to: url)
        let document = try MobileDocument.load(url)
        XCTAssertTrue(try document.fullText().contains("bank"))
        let page = try XCTUnwrap(document.pdf?.page(at: 0))
        page.addAnnotation(PDFAnnotation(bounds: CGRect(x: 30, y: 440, width: 80, height: 20), forType: .highlight, withProperties: nil))
        XCTAssertTrue(document.pdf!.write(to: url))
        XCTAssertEqual(PDFDocument(url: url)?.page(at: 0)?.annotations.count, 1)
    }
    func testAIRequestAndLimitsOffline() throws {
        var settings = Settings(); settings.provider = .openRouter
        XCTAssertThrowsError(try AIClient.request(settings: settings, key: "offline-test", task: .explain, source: "bank", appStore: true))
        settings.provider = .deepSeek
        let request = try AIClient.request(settings: settings, key: "offline-test", task: .explain, source: "bank", appStore: true)
        XCTAssertEqual(request.url?.host, "api.deepseek.com")
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: request.httpBody!) as? [String: Any])
        XCTAssertEqual(json["stream"] as? Bool, false)
        XCTAssertThrowsError(try AIClient.request(settings: settings, key: "offline-test", task: .explain, source: String(repeating: "x", count: 30001)))
        XCTAssertThrowsError(try AIClient.decode(Data(), status: 402))
        XCTAssertEqual(AIClient.summaryRequests(chunks: 4), 7)
    }
    @MainActor func testRememberedConsentAndRevocationGateRequests() async throws {
        OfflineAIProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [OfflineAIProtocol.self]
        let credentials = FailingCredentials(); credentials.value = "offline-test"
        let client = AIClient(configuration: configuration)
        let model = MobileModel(root: root.appendingPathComponent("consent"), credentials: credentials, ai: client)
        let library = try XCTUnwrap(model.library)
        let book = try library.importFile(write("consent.txt", "The river bank is green."))
        model.open(book); model.select("bank", surrounding: "The river bank is green.")
        XCTAssertTrue(model.showAI)
        XCTAssertFalse(model.busy)
        XCTAssertEqual(OfflineAIProtocol.count, 0)
        model.explain()
        let obsolete = try XCTUnwrap(model.pending)
        model.select("river", surrounding: "The river bank is green.")
        model.authorizeAndSend(obsolete)
        XCTAssertFalse(model.hasAIConsent)
        XCTAssertEqual(OfflineAIProtocol.count, 0)
        model.explain()
        model.authorizeAndSend(try XCTUnwrap(model.pending))
        await waitForAI(model)
        XCTAssertTrue(model.hasAIConsent)
        XCTAssertNil(model.pending)
        XCTAssertEqual(OfflineAIProtocol.count, 1)
        model.question = "Why?"; model.followup(); await waitForAI(model)
        XCTAssertNil(model.pending)
        XCTAssertEqual(OfflineAIProtocol.count, 2)
        model.summary(); await waitForAI(model)
        XCTAssertNil(model.pending)
        XCTAssertEqual(OfflineAIProtocol.count, 3)
        let restored = MobileModel(root: library.root, credentials: credentials, ai: client)
        XCTAssertTrue(restored.hasAIConsent)
        restored.open(book); restored.select("bank", surrounding: "The river bank is green.")
        restored.explain(); await waitForAI(restored)
        XCTAssertEqual(OfflineAIProtocol.count, 4)
        restored.revokeAIConsent()
        XCTAssertFalse(restored.hasAIConsent)
        XCTAssertFalse(MobileModel(root: library.root, credentials: credentials, ai: client).hasAIConsent)
        restored.explain()
        XCTAssertNotNil(restored.pending)
        restored.dismissAssistant()
        XCTAssertNil(restored.pending)
        await waitForAI(restored)
        XCTAssertEqual(OfflineAIProtocol.count, 4)
    }
    func testOlderLibraryRequiresFreshAIConsent() throws {
        let directory = root.appendingPathComponent("legacy")
        let library = try MobileLibrary(root: directory)
        // This is the exact pre-consent schema, without the new optional field.
        let state = try JSONSerialization.jsonObject(with: JSONEncoder().encode(library.state)) as! [String: Any]
        XCTAssertNil(state["aiConsentVersion"])
        try JSONSerialization.data(withJSONObject: state).write(to: directory.appendingPathComponent("library.json"))
        XCTAssertNil(try MobileLibrary(root: directory).state.aiConsentVersion)
    }
    @MainActor private func waitForAI(_ model: MobileModel) async {
        for _ in 0..<100 {
            if !model.busy { break }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertFalse(model.busy)
        XCTAssertNil(model.error)
    }
    @MainActor func testReadingScreensAndMissingCredentialGate() async throws {
        let source = try write("Reading-Garden.txt", "阅读花园 · The Reading Garden\n\n慢下来，读懂一句话。\n\nThe river bank is green. The bank approved the loan.\n\n同一个词，在不同语境中含义不同。长按选择一句话，再打开阅读助手。\n\nRead at your own pace. Keep a question in mind and let context do the work.")
        let model = MobileModel(root: root.appendingPathComponent("preview"), credentials: EmptyCredentials())
        let library = try XCTUnwrap(model.library)
        let book = try library.importFile(source)
        model.refresh()
        let rootView = RootView().environmentObject(model).tint(Color(red: 0.16, green: 0.43, blue: 0.32))
        await capture(rootView, name: "iPhone-library", size: CGSize(width: 393, height: 852))
        model.open(book)
        model.select("bank", surrounding: "The bank approved the loan.")
        model.explain()
        XCTAssertNil(model.pending)
        XCTAssertFalse(model.busy)
        XCTAssertNotNil(model.error)
        model.error = nil
        let reader = NavigationStack { ReaderScreen() }.environmentObject(model).tint(Color(red: 0.16, green: 0.43, blue: 0.32))
        let select = { model.select("bank", surrounding: "The bank approved the loan.") }
        await capture(reader, name: "iPhone-reading", size: CGSize(width: 393, height: 852), beforeCapture: select)
        await capture(reader, name: "iPad-reading", size: CGSize(width: 1024, height: 768), beforeCapture: select)
        await capture(reader.environment(\.colorScheme, .dark), name: "iPhone-floating-dark", size: CGSize(width: 393, height: 852), beforeCapture: select)
        await capture(reader, name: "iPhone-floating-landscape", size: CGSize(width: 852, height: 393), beforeCapture: select)
        await capture(reader, name: "iPhone-first-consent", size: CGSize(width: 393, height: 852)) {
            select(); model.hasKey = true; model.explain()
        }
    }
    @MainActor private func capture<V: View>(_ content: V, name: String, size: CGSize, beforeCapture: () -> Void = {}) async {
        let host = UIHostingController(rootView: content)
        host.loadViewIfNeeded()
        host.view.frame = CGRect(origin: .zero, size: size)
        host.traitOverrides.horizontalSizeClass = size.width > 600 ? .regular : .compact
        host.view.setNeedsLayout(); host.view.layoutIfNeeded()
        try? await Task.sleep(nanoseconds: 300_000_000)
        beforeCapture()
        try? await Task.sleep(nanoseconds: 150_000_000)
        host.view.setNeedsLayout(); host.view.layoutIfNeeded()
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true) }
        let attachment = XCTAttachment(image: image)
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testUnicodeChunkingPreservesText() {
        let text = String(repeating: "书📚 é ", count: 4000)
        let chunks = TextLimits.chunks(text)
        XCTAssertEqual(chunks.joined(), text)
        XCTAssertTrue(chunks.allSatisfy { $0.utf16.count <= 12000 })
    }
}

private final class EmptyCredentials: Credentials {
    func read(_ provider: DeepReaderMobile.Provider) throws -> String { "" }
    func save(_ value: String, for provider: DeepReaderMobile.Provider) throws {}
    func remove(_ provider: DeepReaderMobile.Provider) throws {}
}

private final class FailingCredentials: Credentials {
    var value = ""
    var failSave = true
    func read(_ provider: DeepReaderMobile.Provider) throws -> String { value }
    func save(_ value: String, for provider: DeepReaderMobile.Provider) throws {
        if failSave { throw KeychainCredentials.failure(errSecMissingEntitlement, "保存失败。", "Save failed.") }
        self.value = value
    }
    func remove(_ provider: DeepReaderMobile.Provider) throws { value = "" }
}

private final class OfflineAIProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var requests = 0
    static var count: Int { lock.lock(); defer { lock.unlock() }; return requests }
    static func reset() { lock.lock(); requests = 0; lock.unlock() }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.lock(); Self.requests += 1; Self.lock.unlock()
        let data = Data(#"{"choices":[{"finish_reason":"stop","message":{"content":"Offline test response."}}]}"#.utf8)
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
