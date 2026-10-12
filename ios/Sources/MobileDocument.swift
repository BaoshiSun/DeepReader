// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import PDFKit
import ZIPFoundation

struct MobileChapter: Identifiable, Sendable {
    let id: String
    let title: String
    let text: String
}
struct MobileDocument {
    let url: URL
    let chapters: [MobileChapter]
    let pdf: PDFDocument?
    static let extensions = ["pdf", "epub", "txt", "md", "markdown"]
    static let invalid = ReaderError("文件损坏、加密或格式暂不支持。", "The document is damaged, encrypted, or unsupported.")
    static let oversized = ReaderError("文件过大：最大 128 MB，单章最大 8 MB，全文最多 200 万字符。", "Document too large: 128 MB file, 8 MB chapter, two million text characters.")
    static func load(_ url: URL) throws -> Self {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max
        guard size > 0, size <= 128 * 1024 * 1024 else { throw oversized }
        switch url.pathExtension.lowercased() {
        case "pdf":
            guard let pdf = PDFDocument(url: url), !pdf.isLocked, pdf.pageCount > 0 else { throw invalid }
            return Self(url: url, chapters: [], pdf: pdf)
        case "epub": return Self(url: url, chapters: try EPUBText.read(url), pdf: nil)
        case "txt", "md", "markdown":
            guard size <= 8 * 1024 * 1024 else { throw oversized }
            let data = try Data(contentsOf: url)
            guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16), !text.isEmpty else { throw invalid }
            return Self(url: url, chapters: [.init(id: url.lastPathComponent, title: "", text: text)], pdf: nil)
        default: throw invalid
        }
    }
    func fullText() throws -> String {
        var result = ""
        if let pdf {
            for index in 0..<pdf.pageCount {
                try Task.checkCancellation()
                result += (pdf.page(at: index)?.string ?? "") + "\n\n"
                guard result.utf16.count <= 2_000_000 else { throw Self.oversized }
            }
        } else {
            for chapter in chapters {
                result += chapter.title + "\n" + chapter.text + "\n\n"
                guard result.utf16.count <= 2_000_000 else { throw Self.oversized }
            }
        }
        guard !result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ReaderError("没有可提取的文字；暂不支持扫描件 OCR。", "No extractable text; scanned-document OCR is not supported.")
        }
        return result
    }
}

/// EPUB is displayed as readable chapter text. No book scripts, network resources, or HTML execute.
enum EPUBText {
    static func path(_ raw: String, relativeTo base: String = "") throws -> String {
        guard let value = raw.components(separatedBy: "#")[0].removingPercentEncoding,
              !value.isEmpty, !value.hasPrefix("/"), !value.contains(":"), !value.contains("\\"), !value.contains("\0") else { throw MobileDocument.invalid }
        var parts = base.split(separator: "/").dropLast().map(String.init)
        for component in value.split(separator: "/") {
            if component == "." { continue }
            if component == ".." {
                guard !parts.isEmpty else { throw MobileDocument.invalid }; parts.removeLast()
            } else { parts.append(String(component)) }
        }
        guard !parts.isEmpty else { throw MobileDocument.invalid }
        return parts.joined(separator: "/")
    }
    static func read(_ url: URL) throws -> [MobileChapter] {
        let archive = try Archive(url: url, accessMode: .read)
        var files: [String: Data] = [:], total = 0, count = 0
        for entry in archive {
            try Task.checkCancellation()
            count += 1
            guard count <= 10000, entry.type != .symlink, !entry.path.split(separator: "/").contains("..") else { throw MobileDocument.invalid }
            let name = try path(entry.path)
            if entry.type == .directory { continue }
            guard files[name] == nil, entry.uncompressedSize <= 32 * 1024 * 1024 else { throw MobileDocument.oversized }
            var data = Data()
            let crc = try archive.extract(entry) { chunk in
                total += chunk.count
                guard total <= 256 * 1024 * 1024, data.count + chunk.count <= 32 * 1024 * 1024 else { throw MobileDocument.oversized }
                data.append(chunk)
            }
            guard crc == entry.checksum else { throw MobileDocument.invalid }
            files[name] = data
        }
        guard let container = files["META-INF/container.xml"] else { throw MobileDocument.invalid }
        let roots = try EPUBXML.parse(container)
        guard let root = roots.elements.first(where: { $0.name == "rootfile" })?.attributes["full-path"],
              let package = files[try path(root)] else { throw MobileDocument.invalid }
        if let encrypted = files["META-INF/encryption.xml"] {
            let allowed = ["http://www.idpf.org/2008/embedding", "http://ns.adobe.com/pdf/enc#RC"]
            guard try EPUBXML.parse(encrypted).elements.filter({ $0.name == "encryptionmethod" }).allSatisfy({ allowed.contains($0.attributes["Algorithm"] ?? "") }) else { throw MobileDocument.invalid }
        }
        let opf = try EPUBXML.parse(package)
        var manifest: [String: String] = [:]
        for item in opf.elements where item.name == "item" {
            if let id = item.attributes["id"], let href = item.attributes["href"],
               ["application/xhtml+xml", "text/html"].contains(item.attributes["media-type"] ?? "") {
                manifest[id] = try path(href, relativeTo: root)
            }
        }
        var chapters: [MobileChapter] = [], seen = Set<String>(), characters = 0
        for item in opf.elements where item.name == "itemref" {
            guard let id = item.attributes["idref"], let name = manifest[id], let data = files[name] else { throw MobileDocument.invalid }
            if !seen.insert(name).inserted { continue }
            guard data.count <= 8 * 1024 * 1024, chapters.count < 5000 else { throw MobileDocument.oversized }
            let parsed = try EPUBXML.parse(data)
            let text = parsed.body.trimmingCharacters(in: .whitespacesAndNewlines)
            characters += text.utf16.count
            guard characters <= 2_000_000 else { throw MobileDocument.oversized }
            chapters.append(.init(id: name, title: parsed.title.isEmpty ? "\(chapters.count + 1)" : parsed.title, text: text))
        }
        guard !chapters.isEmpty else { throw MobileDocument.invalid }
        return chapters
    }
}

final class EPUBXML: NSObject, XMLParserDelegate {
    struct Element { let name: String; let attributes: [String: String] }
    var elements: [Element] = []
    var body = "", title = ""
    private var stack: [String] = []
    private var denied = 0
    static func parse(_ data: Data) throws -> EPUBXML {
        guard data.count <= 8 * 1024 * 1024 else { throw MobileDocument.oversized }
        // Reject entity declarations; external DTD resolution remains disabled.
        let probe = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16) ?? ""
        guard !probe.isEmpty, !probe.localizedCaseInsensitiveContains("<!ENTITY") else { throw MobileDocument.invalid }
        let parser = XMLParser(data: data), delegate = EPUBXML()
        parser.shouldResolveExternalEntities = false
        parser.delegate = delegate
        guard parser.parse() else { throw MobileDocument.invalid }
        return delegate
    }
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        let name = elementName.split(separator: ":").last.map(String.init)?.lowercased() ?? elementName.lowercased()
        elements.append(.init(name: name, attributes: attributes)); stack.append(name)
        if ["script", "style", "head"].contains(name) { denied += 1 }
        if ["p", "div", "h1", "h2", "h3", "li", "br"].contains(name), denied == 0 { body += "\n" }
        if elements.count > 100000 || stack.count > 128 { parser.abortParsing() }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if stack.last == "title" { title += string }
        if denied == 0, stack.contains("body") { body += string }
    }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        let name = stack.popLast() ?? ""
        if ["script", "style", "head"].contains(name) { denied -= 1 }
        if ["p", "div", "h1", "h2", "h3", "li"].contains(name), denied == 0 { body += "\n" }
    }
}
