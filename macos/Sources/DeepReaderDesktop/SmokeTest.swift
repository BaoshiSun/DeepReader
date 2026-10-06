// SPDX-License-Identifier: AGPL-3.0-or-later
// Offline fixtures used by CI; never reads a user's profile or calls an AI provider.
import AppKit
import CoreText
import PDFKit
import DeepReaderCore

@MainActor public enum SmokeTest {
    public static let sentence = "The river bank is green. The bank approved the loan."
    public static func makePDF(at url: URL) throws {
        var bounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let context = CGContext(url as CFURL, mediaBox: &bounds, nil) else { throw ReaderError("无法创建测试 PDF。", "Could not create the test PDF.") }
        context.beginPDFPage(nil)
        context.textPosition = CGPoint(x: 50, y: 700)
        let text = NSAttributedString(string: sentence, attributes: [.font: NSFont.systemFont(ofSize: 16)])
        CTLineDraw(CTLineCreateWithAttributedString(text), context)
        context.textPosition = CGPoint(x: 50, y: 660)
        CTLineDraw(CTLineCreateWithAttributedString(NSAttributedString(string: "DeepReader offline macOS validation", attributes: [.font: NSFont.systemFont(ofSize: 12)])), context)
        context.endPDFPage(); context.closePDF()
    }
    public static func run(controller: ReaderWindow, folder: URL) throws {
        let m = controller.model, url = folder.appendingPathComponent("sample.pdf")
        try makePDF(at: url); controller.open(url)
        guard let page = m.pdf.view.document?.page(at: 0), let source = page.string else { throw ReaderError("测试失败。", "Fixture PDF did not open.") }
        let range = (source as NSString).range(of: "bank", options: .backwards)
        guard let selection = page.selection(for: range) else { throw ReaderError("测试失败。", "Fixture selection failed.") }
        m.pdf.view.setCurrentSelection(selection, animate: false)
        let selected = try m.pdf.selected()
        guard selected.text == "bank", selected.context.contains("The ⟦bank⟧ approved") else { throw ReaderError("测试失败。", "Context selected the wrong occurrence.") }
        try m.pdf.toggleHighlight(selected); try m.pdf.save()
        guard PDFDocument(url: url)?.page(at: 0)?.annotations.contains(where: { $0.contents == selected.marker }) == true else { throw ReaderError("测试失败。", "Highlight did not persist.") }
        m.rate(4); m.finish(true)
        guard let book = m.book, book.rating == 4, book.finished else { throw ReaderError("测试失败。", "Book state did not persist.") }
        let archived = try m.store.archive(book: book, source: url, root: folder.appendingPathComponent("archive"))
        guard FileManager.default.fileExists(atPath: url.path), FileManager.default.fileExists(atPath: archived.path) else { throw ReaderError("测试失败。", "Archive lost a file.") }
        try m.reload()
        let anchor = m.pdf.view.currentDestination
        controller.setFloating(true)
        controller.window?.contentView?.layoutSubtreeIfNeeded()
        if let before = anchor?.point, let after = m.pdf.view.currentDestination?.point {
            guard abs(before.y-after.y) < 12 else { throw ReaderError("测试失败。", "Floating moved the reading position off screen.") }
        }
        controller.setFloating(false)
        controller.window?.contentView?.layoutSubtreeIfNeeded()
        if let before = anchor?.point, let after = m.pdf.view.currentDestination?.point {
            guard abs(before.y-after.y) < 12 else { throw ReaderError("测试失败。", "Docking moved the reading position off screen.") }
        }
        m.selected = selected.text
        m.answer = "离线界面测试示例：此处 bank 指银行，因为它批准了贷款。\n\nOffline UI fixture: bank means a financial institution here, because it approved a loan."
        m.tab = 0; m.status = "Offline validation — no network requests or real API keys."
        guard try m.store.books().items.count == 1 else { throw ReaderError("测试失败。", "Duplicate book created.") }
    }
}
