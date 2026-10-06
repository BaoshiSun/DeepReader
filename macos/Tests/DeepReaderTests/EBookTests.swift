// SPDX-License-Identifier: AGPL-3.0-or-later
import XCTest
import AppKit
@testable import DeepReaderCore
@testable import DeepReaderDesktop

final class EBookTests: XCTestCase {
    private let sentence = "The river bank is green. The bank approved the loan."
    static var fixtures: URL { URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".build/format-fixtures") }
    private func load(_ name: String) throws -> EBookDocument { try EBookDocument.load(Self.fixtures.appendingPathComponent(name)) }
    func testEPUBSpineOrderResourcesAndSanitization() throws {
        let book = try load("garden.epub")
        XCTAssertEqual(book.title, "DeepReader Format Garden")
        XCTAssertEqual(book.chapters.map(\.path), ["OPS/z-first.xhtml", "OPS/a-last.xhtml"])
        XCTAssertNotNil(book.resources["OPS/leaf.svg"])
        let markup = String(decoding: book.resources[book.chapters[0].path]!, as: UTF8.self)
        XCTAssertFalse(markup.contains("<script")); XCTAssertFalse(markup.contains("<iframe")); XCTAssertFalse(markup.contains("onclick="))
        XCTAssertTrue(markup.contains("script-src 'none'")); XCTAssertTrue(markup.contains("style.css"))
        let text = try book.fullText()
        XCTAssertTrue(text.contains(sentence)); XCTAssertTrue(text.contains("CHAPTER_TWO_SENTINEL"))
        XCTAssertFalse(text.contains("bookScriptRan"))
    }
    func testUnsafeArchivesAndDRMAreRejected() {
        for name in ["traversal.epub", "missing.epub", "entity.epub", "oversize.epub", "drm.epub"] {
            XCTAssertThrowsError(try load(name), name)
        }
        XCTAssertThrowsError(try BookPath.resolve("../../outside", relativeTo: "OPS/book.opf"))
        XCTAssertThrowsError(try BookPath.resolve("file:///etc/passwd", relativeTo: "OPS/book.opf"))
        XCTAssertEqual(try BookPath.resolve("../images/a%20b.png", relativeTo: "OPS/text/ch1.xhtml"), "OPS/images/a b.png")
    }
    func testTextEncodingsAndMarkdown() throws {
        for name in ["garden.txt", "utf16.txt", "gb18030.txt", "garden.md"] {
            let book = try load(name), text = try book.fullText()
            XCTAssertTrue(text.contains(sentence)); XCTAssertTrue(text.contains("中文") || text.contains("上下文"))
        }
        let md = try load("garden.md"), html = String(decoding: md.resources["book.html"]!, as: UTF8.self)
        XCTAssertTrue(html.contains("<h1>Reading garden</h1>")); XCTAssertTrue(html.contains("<strong>EPUB</strong>")); XCTAssertTrue(html.contains("<code>"))
    }
    func testLegacyMOBI() throws {
        let book = try load("garden.mobi")
        XCTAssertTrue(try book.fullText().contains(sentence))
    }
    func testRealMOBIAndKF8Fixtures() throws {
        guard FileManager.default.fileExists(atPath: Self.fixtures.appendingPathComponent("sample-kf8.azw3").path) else { throw XCTSkip("Run make_format_fixtures.py --upstream for pinned upstream fixtures (required in CI).") }
        for name in ["sample-kf8.azw3", "sample-cp1252.mobi", "sample-unicode-huffdic.mobi"] {
            let book = try load(name)
            XCTAssertGreaterThan(try book.fullText().count, 1000, name)
            XCTAssertFalse(book.chapters.isEmpty, name)
        }
        XCTAssertThrowsError(try load("sample-drm_pidLTKULBB^5V-v2.mobi")) { error in XCTAssertTrue((error as? ReaderError)?.message(true).contains("DRM") == true) }
    }
    func testArchiveKeepsEBookExtensionAndAnnotations() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("DeepReader-Ebook-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try LibraryStore(root: root.appendingPathComponent("profile")), book = try load("garden.epub")
        let entry = try store.ensureBook(book.url), rated = try store.updateBook(id: entry.id, rating: 5, finished: true)
        let mark = EBookMark(chapter: book.chapters[0].path, start: 10, length: 4, quote: "bank")
        try store.saveHighlights([mark], bookID: entry.id, fingerprint: book.fingerprint)
        let archive = root.appendingPathComponent("archive/5星")
        try FileManager.default.createDirectory(at: archive, withIntermediateDirectories: true)
        try Data("collision".utf8).write(to: archive.appendingPathComponent("garden.epub"))
        let result = try store.archive(book: rated, source: book.url, root: root.appendingPathComponent("archive"))
        XCTAssertEqual(result.lastPathComponent, "garden (2).epub")
        XCTAssertEqual(try Data(contentsOf: result), try Data(contentsOf: book.url))
        XCTAssertEqual(try store.ensureBook(result).id, entry.id)
        XCTAssertEqual(try store.highlights(bookID: entry.id, fingerprint: book.fingerprint), [mark])
        XCTAssertEqual(try store.highlights(bookID: entry.id, fingerprint: String(repeating: "0", count: 64)), [])
    }
    @MainActor func testWebReaderSelectionNavigationAndSavedHighlight() async throws {
        _ = NSApplication.shared
        let book = try load("garden.epub"), reader = EBookReader()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 850, height: 700), styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = reader.view; window.orderFront(nil); defer { window.orderOut(nil) }
        reader.open(book, marks: []); try await ready(reader)
        // Use the first sentence's two occurrences, not a global search for the word.
        try await reader.selectForTesting("The bank approved the loan.")
        let sentence = try await reader.selected()
        XCTAssertEqual(sentence.text, "The bank approved the loan."); XCTAssertTrue(sentence.context.contains("⟦The bank approved the loan.⟧"))
        try await reader.selectForTesting("bank", last: true)
        let selection = try await reader.selected()
        XCTAssertTrue(selection.context.contains("second ⟦bank⟧"))
        try await reader.setMarks(reader.toggled(selection))
        XCTAssertEqual(reader.marks.count, 1)
        reader.go(to: 1); try await ready(reader)
        let body = try await reader.javascript("return document.body.textContent;") as? String
        XCTAssertTrue(body?.contains("CHAPTER_TWO_SENTINEL") == true)
        reader.go(to: 0); try await ready(reader)
        let marked = try await reader.javascript("return CSS.highlights ? CSS.highlights.get('deepreader').size : document.querySelectorAll('mark[data-deepreader]').length;")
        XCTAssertEqual(marked as? Int, 1)
        let didRun = try await reader.javascript("return document.querySelector('script') !== null;")
        XCTAssertEqual(didRun as? Bool, false)
        try await reader.setMarks(reader.toggled(selection)); XCTAssertTrue(reader.marks.isEmpty)
    }
    @MainActor private func ready(_ reader: EBookReader) async throws {
        for _ in 0..<600 { if reader.ready { return }; try await Task.sleep(nanoseconds: 50000000) }
        throw ReaderError("测试页面加载超时。", "Web reader fixture timed out.")
    }
}
