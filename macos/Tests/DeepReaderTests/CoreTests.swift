// SPDX-License-Identifier: AGPL-3.0-or-later
import XCTest
@testable import DeepReaderCore

final class CoreTests: XCTestCase {
    func temporary() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("DeepReader-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }; return url
    }
    func testDateRanges() {
        XCTAssertEqual(Dates.range(scope: 2, anchor: "2026-10-04"), "2026-09-28"..."2026-10-04")
        XCTAssertEqual(Dates.range(scope: 3, anchor: "2024-02-20"), "2024-02-01"..."2024-02-29")
        XCTAssertNil(Dates.parse("2026-02-30")); XCTAssertNil(Dates.parse("2026-1-01"))
    }
    func testSettingsAndNoEmbeddedKey() throws {
        var settings = Settings(); settings.lookupSplit = 9; settings.sidebarWidth = 2
        XCTAssertEqual(try settings.validated().lookupSplit, 0.8)
        XCTAssertEqual(try settings.validated().sidebarWidth, 360)
        XCTAssertFalse(Settings.validModel("bad\nmodel")); XCTAssertFalse(Settings.validKey("bad\nkey"))
        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(settings)) as! [String: Any]
        XCTAssertNil(object["apiKey"]); XCTAssertEqual(settings.provider, .deepSeek)
    }
    func testRequestContractAndFreePricing() throws {
        var settings = Settings()
        var request = try AIClient.request(settings: settings, key: "test-credential", task: .explain, source: "Sample")
        XCTAssertEqual(request.url?.host, "api.deepseek.com")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-credential")
        var body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        XCTAssertNotNil(body["thinking"])
        settings.provider = .openRouter; settings.english = true
        request = try AIClient.request(settings: settings, key: "test-credential", task: .followup, source: "Question")
        body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        let provider = body["provider"] as! [String: Any], price = provider["max_price"] as! [String: Int]
        XCTAssertEqual(price["prompt"], 0); XCTAssertEqual(price["completion"], 0); XCTAssertEqual(price["request"], 0)
        XCTAssertNil(body["thinking"])
        let messages = body["messages"] as! [[String: String]]
        XCTAssertTrue(messages[0]["content"]!.contains("English")); XCTAssertTrue(messages[0]["content"]!.contains("untrusted"))
        XCTAssertThrowsError(try AIClient.request(settings: settings, key: "", task: .explain, source: "x"))
    }
    func testResponseFailureAndTruncation() throws {
        func response(_ finish: String, _ content: String) throws -> Data {
            try JSONSerialization.data(withJSONObject: ["choices": [["finish_reason": finish, "message": ["content": content]]]])
        }
        XCTAssertEqual(try AIClient.decode(response("stop", " Answer "), status: 200), "Answer")
        XCTAssertThrowsError(try AIClient.decode(response("length", "Partial"), status: 200))
        XCTAssertThrowsError(try AIClient.decode(response("stop", ""), status: 200))
        XCTAssertThrowsError(try AIClient.decode(Data(), status: 401))
        XCTAssertThrowsError(try AIClient.decode(Data("{}".utf8), status: 200))
    }
    func testChunkingPreservesUnicodeAndAllText() {
        let source = String(repeating: "中文🙂é ABC\n", count: 5000)
        let chunks = TextLimits.chunks(source)
        XCTAssertEqual(chunks.joined(), source); XCTAssertTrue(chunks.allSatisfy { $0.utf16.count <= 12000 })
        XCTAssertEqual(AIClient.summaryRequests(chunks: 1), 1); XCTAssertEqual(AIClient.summaryRequests(chunks: 4), 7)
    }
    func testFollowupUpdatesOriginalAndCountsOnce() throws {
        let store = try LibraryStore(root: temporary())
        var record = ReadingRecord(); record.file = "/fixture.pdf"; record.selected = "bank"; record.answer = "A river edge."
        try store.saveRecord(record); record.answer += "\nFollow-up: Why?\nContext explains it."; try store.saveRecord(record)
        var duplicate = ReadingRecord(); duplicate.file = record.file; duplicate.selected = " BANK "; duplicate.answer = "Finance."
        try store.saveRecord(duplicate)
        var summary = ReadingRecord(); summary.kind = "week"; summary.answer = "Review"; try store.saveRecord(summary)
        let loaded = try store.records(); XCTAssertEqual(loaded.items.count, 3)
        let stats = ReadingStats(loaded.items)
        XCTAssertEqual(stats.lookups, 2); XCTAssertEqual(stats.distinct, 1); XCTAssertEqual(stats.files, 1)
        try store.deleteRecord(record.id); XCTAssertEqual(try store.records().items.count, 2)
    }
    func testBadRecordsAreReportedAndKept() throws {
        let store = try LibraryStore(root: temporary()), folder = store.root.appendingPathComponent("AIHistory")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(UUID().uuidString.lowercased()+".json")
        try Data("broken".utf8).write(to: url)
        XCTAssertEqual(try store.records().unreadable, 1); XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertThrowsError(try store.deleteRecord("../../other"))
    }
    func testBookArchiveCollisionAndAliases() throws {
        let root = try temporary(), store = try LibraryStore(root: root.appendingPathComponent("profile"))
        let source = root.appendingPathComponent("中文 book.pdf"), destination = root.appendingPathComponent("archive")
        try Data("source-PDF-fixture".utf8).write(to: source)
        var book = try store.ensureBook(source); book = try store.updateBook(id: book.id, rating: 5, finished: true)
        let completed = book.finishedAt
        book = try store.updateBook(id: book.id, finished: true); XCTAssertEqual(book.finishedAt, completed)
        let collision = destination.appendingPathComponent("5星/中文 book.pdf")
        try FileManager.default.createDirectory(at: collision.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("unrelated".utf8).write(to: collision)
        let archived = try store.archive(book: book, source: source, root: destination)
        XCTAssertEqual(archived.lastPathComponent, "中文 book (2).pdf")
        XCTAssertEqual(try Data(contentsOf: source), try Data(contentsOf: archived))
        XCTAssertEqual(try Data(contentsOf: collision), Data("unrelated".utf8))
        book = try store.ensureBook(archived); XCTAssertEqual(try store.books().items.count, 1)
        XCTAssertEqual(try store.archive(book: book, source: source, root: destination), archived)
        book = try store.updateBook(id: book.id, rating: 3, finished: false)
        XCTAssertTrue(book.finishedAt.isEmpty)
        let rerated = try store.archive(book: book, source: source, root: destination)
        XCTAssertEqual(rerated.deletingLastPathComponent().lastPathComponent, "3星")
        let reopened = try LibraryStore(root: store.root).ensureBook(archived)
        XCTAssertEqual(reopened.id, book.id); XCTAssertEqual(reopened.copies.count, 2)
    }
    func testCancellationDoesNotArchive() async throws {
        let root = try temporary(), store = try LibraryStore(root: root.appendingPathComponent("profile")), source = root.appendingPathComponent("book.pdf")
        try Data("fixture".utf8).write(to: source)
        let book = try store.updateBook(id: store.ensureBook(source).id, rating: 3)
        let task = Task {
            try await Task.sleep(nanoseconds: 1000000000)
            return try store.archive(book: book, source: source, root: root.appendingPathComponent("archive"))
        }
        task.cancel()
        do { _ = try await task.value; XCTFail("Cancelled archive succeeded") } catch is CancellationError { }
        XCTAssertTrue(try store.books().items[0].archivePath.isEmpty)
    }
}
