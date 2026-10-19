// SPDX-License-Identifier: AGPL-3.0-or-later
import XCTest
import PDFKit
import SwiftUI
import ZIPFoundation
@testable import DeepReaderMobile

final class MobileTests: XCTestCase {
    var root: URL!
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }
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
    func testSplitBoundsAcrossWindowSizes() {
        for width: CGFloat in [320, 393, 600, 663, 664, 700, 852, 1024, 1366] {
            let layout = ReaderSplitLayout(width: width)
            if width < 664 {
                XCTAssertFalse(layout.canDock)
                XCTAssertEqual(layout.assistantWidth(fraction: 0.5), 0)
            } else {
                XCTAssertTrue(layout.canDock)
                for fraction in [-1.0, 0.25, 0.38, 0.65, 2.0, .nan, .infinity] {
                    let panel = layout.assistantWidth(fraction: fraction)
                    XCTAssertGreaterThanOrEqual(panel, 300)
                    XCTAssertGreaterThanOrEqual(width - 24 - panel, 340)
                }
                let start = layout.assistantWidth(fraction: 0.38)
                let expanded = layout.assistantWidth(fraction: layout.resizedFraction(startWidth: start, translation: -10000))
                let reduced = layout.assistantWidth(fraction: layout.resizedFraction(startWidth: start, translation: 10000))
                XCTAssertGreaterThanOrEqual(expanded, start)
                XCTAssertLessThanOrEqual(reduced, start)
            }
        }
    }
    @MainActor func testReaderLayoutPersistsWithoutSendingOrLosingReadingState() throws {
        let model = MobileModel(root: root)
        XCTAssertEqual(model.assistantPresentation, .sidebar)
        XCTAssertEqual(model.assistantWidthFraction, 0.38)
        let book = try XCTUnwrap(model.library).importFile(write("layout.txt", "The bank approved the loan."))
        model.open(book); model.select("bank", surrounding: "The bank approved the loan.")
        model.answer = "Existing explanation"; model.question = "Why?"
        model.setAssistantPresentation(.floating)
        model.assistantWidthFraction = 0.52; model.persistReaderLayout()
        let restored = MobileModel(root: root)
        XCTAssertEqual(restored.assistantPresentation, .floating)
        XCTAssertEqual(restored.assistantWidthFraction, 0.52)
        model.setAssistantPresentation(.sidebar)
        XCTAssertEqual(model.selected, "bank")
        XCTAssertEqual(model.answer, "Existing explanation")
        XCTAssertEqual(model.question, "Why?")
        XCTAssertEqual(model.book?.id, book.id)
        model.dismissAssistant()
        XCTAssertFalse(model.showAI)
        XCTAssertEqual(model.assistantWidthFraction, 0.52)
        // Older libraries have neither field; unknown modes safely fall back.
        try model.library?.update { $0.assistantPresentation = "future-mode"; $0.assistantWidthFraction = nil }
        XCTAssertEqual(MobileModel(root: root).assistantPresentation, .sidebar)
    }
    @MainActor func testAdaptiveAssistantLayouts() async throws {
        let model = MobileModel(root: root)
        let book = try XCTUnwrap(model.library).importFile(write("Adaptive reading.txt", String(repeating: "The river bank is green. Read at your own pace.\n\n", count: 20)))
        model.open(book); model.settings.english = true
        let reader = NavigationStack { ReaderScreen() }.environmentObject(model)
        let answer = {
            model.select("bank", surrounding: "The river bank is green.")
            model.answer = "In this passage, bank means the land beside the river. The phrase ‘river bank’ gives the word its context."
        }
        await capture(reader, name: "iPad-sidebar-default", size: CGSize(width: 1024, height: 768), beforeCapture: answer)
        model.assistantWidthFraction = 0.58
        await capture(reader, name: "iPad-sidebar-wide", size: CGSize(width: 1024, height: 768), beforeCapture: answer)
        await capture(reader, name: "compact-window-fallback", size: CGSize(width: 600, height: 768), beforeCapture: answer)
        await capture(reader, name: "iPhone-landscape-sidebar", size: CGSize(width: 852, height: 393), beforeCapture: answer)
        model.setAssistantPresentation(.floating)
        await capture(reader, name: "iPad-floating-option", size: CGSize(width: 1024, height: 768), beforeCapture: answer)
        model.setAssistantPresentation(.sidebar)
        await capture(reader.environment(\.colorScheme, .dark), name: "iPad-sidebar-dark", size: CGSize(width: 1024, height: 768), beforeCapture: answer)
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
