// SPDX-License-Identifier: AGPL-3.0-or-later
import XCTest
import AppKit
import PDFKit
@testable import DeepReaderCore
@testable import DeepReaderDesktop

final class PDFTests: XCTestCase {
    @MainActor func testResizePreservesReadingPosition() throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("DeepReader-resize-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("test.pdf"); try SmokeTest.makePDF(at: url)
        let reader = PDFReader()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 550), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = reader.view; window.orderFront(nil)
        defer { window.orderOut(nil) }
        try reader.open(url); reader.view.layoutDocumentView()
        let anchor = reader.view.currentDestination!.point, scale = reader.view.scaleFactor
        window.setContentSize(NSSize(width: 900, height: 550)); reader.view.layoutDocumentView()
        XCTAssertGreaterThan(reader.view.scaleFactor, scale)
        XCTAssertEqual(reader.view.currentDestination!.point.y, anchor.y, accuracy: 12)
        window.setContentSize(NSSize(width: 420, height: 550)); reader.view.layoutDocumentView()
        XCTAssertEqual(reader.view.currentDestination!.point.y, anchor.y, accuracy: 12)
    }
    @MainActor func testExactContextAndPersistentHighlight() throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("DeepReader-PDF-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("test.pdf")
        try SmokeTest.makePDF(at: url)
        let reader = PDFReader(); try reader.open(url)
        let page = reader.view.document!.page(at: 0)!, source = page.string! as NSString
        let other = PDFAnnotation(bounds: NSRect(x: 10, y: 10, width: 25, height: 15), forType: .text, withProperties: nil)
        other.contents = "Other application note"; page.addAnnotation(other)
        reader.view.setCurrentSelection(page.selection(for: source.range(of: "bank", options: .backwards)), animate: false)
        let selection = try reader.selected()
        XCTAssertEqual(selection.text, "bank"); XCTAssertTrue(selection.context.contains("The ⟦bank⟧ approved"))
        XCTAssertFalse(selection.context.contains("river ⟦bank⟧"))
        try reader.toggleHighlight(selection); XCTAssertTrue(reader.dirty); try reader.save()
        XCTAssertFalse(reader.dirty)
        try reader.open(url)
        let reopened = reader.view.document!.page(at: 0)!
        reader.view.setCurrentSelection(reopened.selection(for: (reopened.string! as NSString).range(of: "bank", options: .backwards)), animate: false)
        let again = try reader.selected(); XCTAssertEqual(selection.marker, again.marker)
        try reader.toggleHighlight(again); try reader.save()
        XCTAssertFalse(reopened.annotations.contains { $0.contents == again.marker })
        XCTAssertTrue(reopened.annotations.contains { $0.contents == "Other application note" })
        XCTAssertTrue(try reader.fullText().text.contains(SmokeTest.sentence))
    }
    @MainActor func testExternalPDFChangeIsNotOverwritten() throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("test.pdf"); try SmokeTest.makePDF(at: url)
        let reader = PDFReader(); try reader.open(url)
        let page = reader.view.document!.page(at: 0)!
        reader.view.setCurrentSelection(page.selection(for: NSRange(location: 0, length: 3)), animate: false)
        try reader.toggleHighlight(reader.selected())
        let replacement = Data("externally-changed".utf8); try replacement.write(to: url)
        XCTAssertThrowsError(try reader.save()); XCTAssertEqual(try Data(contentsOf: url), replacement)
    }
}
