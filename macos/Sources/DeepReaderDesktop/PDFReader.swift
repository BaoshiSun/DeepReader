// SPDX-License-Identifier: AGPL-3.0-or-later
import AppKit
import PDFKit
import CryptoKit
import DeepReaderCore

public struct SelectedText {
    public let text: String
    public let context: String
    public let page: Int
    public let selection: PDFSelection
    public let marker: String
}

@MainActor public final class ReaderPDFView: PDFView {
    public override func setFrameSize(_ newSize: NSSize) {
        // PDFKit rescales the page but preserves the old scroll-view offset when its
        // viewport grows. Keep the PDF-space reading position through that resize.
        let previous = window != nil && frame.size != newSize ? currentDestination : nil
        let position = previous.flatMap { destination in
            destination.page.map { PDFDestination(page: $0, at: destination.point) }
        }
        super.setFrameSize(newSize)
        if let position = position { layoutDocumentView(); go(to: position) }
    }
}

@MainActor public final class PDFReader {
    public let view = ReaderPDFView()
    public private(set) var url: URL?
    public private(set) var dirty = false
    private var openedModification: Date?
    private var openedSize: Int?
    public init() {
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .underPageBackgroundColor
    }
    public func open(_ url: URL, password: String? = nil) throws {
        guard url.isFileURL, url.pathExtension.lowercased() == "pdf", let document = PDFDocument(url: url) else {
            throw ReaderError("无法打开此 PDF。请检查文件是否存在或损坏。", "Could not open this PDF. Check whether it exists or is damaged.")
        }
        if document.isLocked {
            guard let password = password, document.unlock(withPassword: password) else {
                throw ReaderError("PDF 已加密，请输入正确的密码。", "This PDF is locked. Enter its password.")
            }
        }
        guard document.pageCount > 0 else { throw ReaderError("PDF 没有可显示的页面。", "The PDF has no pages.") }
        self.url = url.standardizedFileURL
        view.document = document; dirty = false
        rememberModification()
    }
    private func rememberModification() {
        guard let url = url, let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]) else { return }
        openedModification = values.contentModificationDate; openedSize = values.fileSize
    }
    public func selected() throws -> SelectedText {
        guard let document = view.document, document.allowsCopying,
              let selection = view.currentSelection?.copy() as? PDFSelection,
              let raw = selection.string, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ReaderError("请先在 PDF 中拖动选中文字。扫描图片需要先进行 OCR。", "Select text in the PDF first. Scanned images require OCR first.")
        }
        guard raw.utf16.count <= 2200, selection.pages.count <= 3 else {
            throw ReaderError("选中内容过长，请选取 2200 字符以内的词句。", "Select a shorter passage, up to 2,200 characters.")
        }
        var snippets: [String] = [], identity = ""
        let perPage = max(600, 3000 / max(1, selection.pages.count))
        for page in selection.pages {
            let index = document.index(for: page), source = (page.string ?? "") as NSString
            var ranges: [NSRange] = []
            for n in 0..<selection.numberOfTextRanges(on: page) {
                let range = selection.range(at: n, on: page)
                if range.location != NSNotFound && range.length > 0 && NSMaxRange(range) <= source.length { ranges.append(range) }
            }
            guard let first = ranges.first, let last = ranges.last else { continue }
            let start = max(0, first.location - 400)
            let end = min(source.length, max(NSMaxRange(last), first.location + perPage - 400))
            let safeRange = source.rangeOfComposedCharacterSequences(for: NSRange(location: start, length: end-start))
            let mutable = NSMutableString(string: source.substring(with: safeRange))
            for range in ranges.reversed() where range.location >= safeRange.location && NSMaxRange(range) <= NSMaxRange(safeRange) {
                mutable.insert("⟧", at: NSMaxRange(range)-safeRange.location)
                mutable.insert("⟦", at: range.location-safeRange.location)
            }
            snippets.append("[Page \(index+1)]\n\(mutable)")
            identity += "\(index):" + ranges.map { "\($0.location),\($0.length)" }.joined(separator: ";") + "|"
        }
        guard !snippets.isEmpty else { throw ReaderError("无法定位选中文字，请重新选择。", "Could not locate the selected text. Select it again.") }
        let context = snippets.joined(separator: "\n\n")
        guard context.utf16.count <= 5000 else { throw ReaderError("所选内容跨度太大，请缩短选择。", "The selection spans too much text. Choose a shorter passage.") }
        let marker = "DeepReader:" + SHA256.hash(data: Data(identity.utf8)).map { String(format: "%02x", $0) }.joined()
        return SelectedText(text: raw, context: context, page: document.index(for: selection.pages[0])+1, selection: selection, marker: marker)
    }
    public func fullText() throws -> (text: String, blankPages: Int) {
        guard let document = view.document, document.allowsCopying else {
            throw ReaderError("请打开允许复制文字的 PDF。", "Open a PDF that permits copying text.")
        }
        var source = "", empty = 0
        for index in 0..<document.pageCount {
            let text = (document.page(at: index)?.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty { empty += 1; continue }
            source += "[Page \(index+1)]\n\(text)\n\n"
            guard source.utf16.count <= 2000000 else {
                throw ReaderError("文件文字超过 200 万字符，请拆分后总结。", "The PDF exceeds 2 million text characters. Split it before summarizing.")
            }
        }
        guard !source.isEmpty else { throw ReaderError("此 PDF 没有可提取的文字，需要先进行 OCR。", "This PDF has no extractable text. Run OCR first.") }
        return (source, empty)
    }
    public func toggleHighlight(_ selected: SelectedText) throws {
        guard let document = view.document, document.allowsCommenting else {
            throw ReaderError("此 PDF 不允许添加批注。", "This PDF does not permit annotations.")
        }
        let pages = selected.selection.pages
        guard pages.allSatisfy({ document.index(for: $0) != NSNotFound }) else { return }
        let existing = pages.flatMap { page in page.annotations.filter { $0.contents == selected.marker }.map { (page, $0) } }
        if !existing.isEmpty { for (page, annotation) in existing { page.removeAnnotation(annotation) } }
        else {
            for line in selected.selection.selectionsByLine() {
                for page in line.pages {
                    let bounds = line.bounds(for: page)
                    guard !bounds.isEmpty else { continue }
                    let annotation = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
                    annotation.color = NSColor.systemGreen.withAlphaComponent(0.35)
                    annotation.contents = selected.marker; annotation.userName = "DeepReader"
                    page.addAnnotation(annotation)
                }
            }
        }
        dirty = true; view.setNeedsDisplay(view.bounds)
    }
    public func save() throws {
        guard dirty, let url = url, let document = view.document else { return }
        let values = try url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey, .isWritableKey])
        guard values.isWritable == true else { throw ReaderError("PDF 为只读，无法保存批注。", "The PDF is read-only; annotations cannot be saved.") }
        guard values.contentModificationDate == openedModification, values.fileSize == openedSize else {
            throw ReaderError("磁盘上的 PDF 已被其他程序修改，请先保留改动副本。", "Another app changed this PDF on disk. Save your changes to a copy first.")
        }
        // An open-panel grant covers the selected file, not arbitrary siblings.
        // Request an OS-managed replacement directory on the destination volume.
        let replacement = try FileManager.default.url(for: .itemReplacementDirectory, in: .userDomainMask,
                                                       appropriateFor: url, create: true)
        let temporary = replacement.appendingPathComponent("DeepReader.pdf")
        defer { try? FileManager.default.removeItem(at: replacement) }
        guard document.write(to: temporary) else { throw ReaderError("保存 PDF 失败。", "Could not save the PDF.") }
        _ = try FileManager.default.replaceItemAt(url, withItemAt: temporary)
        dirty = false; rememberModification()
    }
    public func saveCopy(_ destination: URL) throws {
        guard let document = view.document, document.write(to: destination) else { throw ReaderError("保存副本失败。", "Could not save the copy.") }
    }
    public func find(_ query: String, backwards: Bool = false) {
        guard !query.isEmpty, let document = view.document else { return }
        let options: NSString.CompareOptions = backwards ? [.caseInsensitive, .backwards] : [.caseInsensitive]
        if let result = document.findString(query, fromSelection: view.currentSelection, withOptions: options) ?? document.findString(query, fromSelection: nil, withOptions: options) {
            view.setCurrentSelection(result, animate: true); view.scrollSelectionToVisible(nil)
        } else { NSSound.beep() }
    }
}
