// SPDX-License-Identifier: AGPL-3.0-or-later
import AppKit
import DeepReaderCore

public enum ReaderSelection {
    case pdf(SelectedText)
    case ebook(EBookSelection)
    public var text: String { switch self { case .pdf(let s): return s.text; case .ebook(let s): return s.text } }
    public var context: String { switch self { case .pdf(let s): return s.context; case .ebook(let s): return s.context } }
    public var page: Int { switch self { case .pdf(let s): return s.page; case .ebook(let s): return s.page } }
}

@MainActor public final class DocumentReader {
    public let pdf = PDFReader()
    public private(set) lazy var ebook = EBookReader()
    public let view = NSView()
    public private(set) var isPDF = true
    public var url: URL? { isPDF ? pdf.url : ebook.book?.url }
    public init() { show(pdf.view) }
    private func show(_ child: NSView) {
        for existing in view.subviews { existing.removeFromSuperview() }
        child.frame = view.bounds; child.autoresizingMask = [.width, .height]; view.addSubview(child)
    }
    public func openPDF(_ url: URL, password: String? = nil) throws { try pdf.open(url, password: password); isPDF = true; show(pdf.view) }
    public func openEBook(_ book: EBookDocument, marks: [EBookMark]) { isPDF = false; show(ebook.view); ebook.open(book, marks: marks) }
    public func selected() async throws -> ReaderSelection { if isPDF { return .pdf(try pdf.selected()) }; return .ebook(try await ebook.selected()) }
    public func fullText() throws -> (text: String, blankPages: Int) {
        if isPDF { return try pdf.fullText() }
        guard let book = ebook.book else { throw ReaderError("请先打开文件。", "Open a file first.") }
        return (try book.fullText(), 0)
    }
    public func move(_ delta: Int) { if isPDF { if delta > 0 { pdf.view.goToNextPage(nil) } else { pdf.view.goToPreviousPage(nil) } } else { ebook.go(to: ebook.chapter + delta) } }
    public func zoom(_ factor: Double) { if isPDF { if factor > 1 { pdf.view.zoomIn(nil) } else { pdf.view.zoomOut(nil) } } else { ebook.zoomBy(factor) } }
    public func fit() { if isPDF { pdf.view.autoScales = true } else { ebook.fit() } }
    public func find(_ text: String, backwards: Bool = false) { if isPDF { pdf.find(text, backwards: backwards) } else { ebook.find(text, backwards: backwards) } }
}
