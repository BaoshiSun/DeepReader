// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import CryptoKit
import CMobi

public enum BookFormat {
    public static let extensions = ["pdf", "epub", "txt", "md", "markdown", "mobi", "azw3"]
    public static func supports(_ url: URL) -> Bool { url.isFileURL && extensions.contains(url.pathExtension.lowercased()) }
}
enum EBookError {
    static var invalid: ReaderError { ReaderError("无法解析此电子书，文件可能损坏或格式不受支持。", "Could not parse this ebook. It may be damaged or unsupported.") }
    static var tooLarge: ReaderError { ReaderError("电子书超出大小限制（文件 128 MB，解压后 256 MB）。", "The ebook exceeds the size limit (128 MB file, 256 MB expanded).") }
    static var drm: ReaderError { ReaderError("此电子书有 DRM 保护，暂不支持。请使用未加 DRM 的 EPUB、MOBI 或 AZW3。", "This ebook is DRM-protected. Use a DRM-free EPUB, MOBI or AZW3 file.") }
}
public struct EBookChapter: Sendable {
    public let path: String
    public let title: String
    public let text: String
}
public struct EBookDocument: Sendable {
    public let url: URL
    public let title: String
    public let fingerprint: String
    public let chapters: [EBookChapter]
    public let resources: [String: Data]

    public static func load(_ url: URL) throws -> EBookDocument {
        guard BookFormat.supports(url), url.pathExtension.lowercased() != "pdf" else { throw EBookError.invalid }
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard values.isRegularFile == true, let size = values.fileSize, size > 0, size <= BookArchive.maxFile else { throw EBookError.tooLarge }
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        guard data.count <= BookArchive.maxFile else { throw EBookError.tooLarge }
        let fingerprint = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let title = url.deletingPathExtension().lastPathComponent
        switch url.pathExtension.lowercased() {
        case "epub": return try epub(url, data: data, fingerprint: fingerprint)
        case "mobi", "azw3": return try mobi(url, fingerprint: fingerprint)
        default:
            guard data.count <= 8 * 1024 * 1024 else { throw EBookError.tooLarge }
            let text = try BookMarkup.decode(data)
            let html = url.pathExtension.lowercased() == "txt" ? BookMarkup.textHTML(text) : BookMarkup.markdown(text)
            return try build(url, title: title, fingerprint: fingerprint, files: ["book.html": Data(html.utf8)], spine: ["book.html"])
        }
    }
    static func build(_ url: URL, title: String, fingerprint: String, files: [String: Data], spine: [String], labels: [String: String] = [:]) throws -> EBookDocument {
        guard !spine.isEmpty, spine.count <= 5000 else { throw EBookError.invalid }
        var resources = files, chapters: [EBookChapter] = [], seen = Set<String>()
        for path in spine {
            try Task.checkCancellation()
            guard let data = files[path] else { throw EBookError.invalid }
            if !seen.insert(path).inserted { continue }
            let content = try BookMarkup.chapter(data)
            resources[path] = Data(content.html.utf8)
            let label = labels[path] ?? (content.title.isEmpty ? "\(chapters.count + 1) · \((path as NSString).lastPathComponent)" : content.title)
            chapters.append(EBookChapter(path: path, title: label, text: content.text))
        }
        return EBookDocument(url: url.standardizedFileURL, title: title, fingerprint: fingerprint, chapters: chapters, resources: resources)
    }
    static func epub(_ url: URL, data: Data, fingerprint: String) throws -> EBookDocument {
        let files = try BookArchive.read(data)
        guard let container = files["META-INF/container.xml"] else { throw EBookError.invalid }
        if let encryption = files["META-INF/encryption.xml"] {
            let xml = try BookMarkup.xml(encryption)
            let algorithms = BookMarkup.elements(xml, named: "encryptionmethod").compactMap { $0.attribute(forName: "Algorithm")?.stringValue }
            // Font obfuscation is not DRM. Unsupported obfuscated fonts use the reader's fallback font.
            guard algorithms.allSatisfy({ ["http://www.idpf.org/2008/embedding", "http://ns.adobe.com/pdf/enc#RC"].contains($0) }) else { throw EBookError.drm }
        }
        let xml = try BookMarkup.xml(container)
        guard let path = BookMarkup.elements(xml, named: "rootfile").first?.attribute(forName: "full-path")?.stringValue,
              let package = files[try BookPath.entry(path)] else { throw EBookError.invalid }
        let opf = try BookMarkup.xml(package)
        var manifest: [String: (String, String)] = [:]
        for item in BookMarkup.elements(opf, named: "item") {
            guard let id = item.attribute(forName: "id")?.stringValue, let href = item.attribute(forName: "href")?.stringValue else { continue }
            manifest[id] = (try BookPath.resolve(href, relativeTo: path), item.attribute(forName: "media-type")?.stringValue ?? "")
        }
        var spine: [String] = []
        for item in BookMarkup.elements(opf, named: "itemref") {
            guard let id = item.attribute(forName: "idref")?.stringValue, let (resource, type) = manifest[id],
                  ["application/xhtml+xml", "text/html"].contains(type) else { throw EBookError.invalid }
            spine.append(resource)
        }
        let title = BookMarkup.elements(opf, named: "title").first?.stringValue ?? url.deletingPathExtension().lastPathComponent
        return try build(url, title: title, fingerprint: fingerprint, files: files, spine: spine)
    }
    static func mobi(_ url: URL, fingerprint: String) throws -> EBookDocument {
        guard let document = mobi_init() else { throw EBookError.invalid }
        defer { mobi_free(document) }
        guard mobi_load_filename(document, url.path) == MOBI_SUCCESS, let header = document.pointee.rh else { throw EBookError.invalid }
        guard header.pointee.encryption_type == 0, document.pointee.next?.pointee.rh?.pointee.encryption_type ?? 0 == 0 else { throw EBookError.drm }
        guard mobi_get_text_maxsize(document) <= BookArchive.maxTotal else { throw EBookError.tooLarge }
        guard let raw = mobi_init_rawml(document) else { throw EBookError.invalid }
        defer { mobi_free_rawml(raw) }
        guard mobi_parse_rawml_opt(raw, document, true, false, true) == MOBI_SUCCESS else { throw EBookError.invalid }
        var files: [String: Data] = [:], spine: [String] = [], total = 0, count = 0
        func collect(_ first: UnsafeMutablePointer<MOBIPart>?, prefix: String) throws {
            var current = first
            while let pointer = current {
                try Task.checkCancellation()
                let part = pointer.pointee
                count += 1; total += part.size
                guard count <= 10000, part.size <= BookArchive.maxEntry, total <= BookArchive.maxTotal else { throw EBookError.tooLarge }
                var meta = mobi_get_filemeta_by_type(part.type)
                let ext = withUnsafeBytes(of: &meta.extension) { String(cString: $0.bindMemory(to: CChar.self).baseAddress!) }
                let name = String(format: "%@%05d.%@", prefix, part.uid, ext)
                if let data = part.data, part.size > 0 {
                    files[name] = Data(bytes: data, count: part.size)
                    if prefix == "part" { spine.append(name) }
                }
                current = part.next
            }
        }
        try collect(raw.pointee.markup, prefix: "part")
        try collect(raw.pointee.flow?.pointee.next, prefix: "flow")
        try collect(raw.pointee.resources, prefix: "resource")
        var name = [CChar](repeating: 0, count: 4096)
        let title = mobi_get_fullname(document, &name, name.count) == MOBI_SUCCESS ? String(cString: name) : url.deletingPathExtension().lastPathComponent
        return try build(url, title: title, fingerprint: fingerprint, files: files, spine: spine)
    }
    public func fullText() throws -> String {
        var text = ""
        for (index, chapter) in chapters.enumerated() {
            text += "[Chapter \(index + 1): \(chapter.title)]\n\(chapter.text)\n\n"
            guard text.utf16.count <= 2000000 else { throw ReaderError("全文超过 200 万字符，请分章阅读和查询。", "The book exceeds two million characters. Read and query smaller sections.") }
        }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw EBookError.invalid }
        return text
    }
    public static func mimeType(_ path: String) -> String {
        switch (path as NSString).pathExtension.lowercased() {
        case "html", "xhtml", "htm": return "text/html"
        case "css": return "text/css"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "svg": return "image/svg+xml"
        case "ttf": return "font/ttf"
        case "otf": return "font/otf"
        case "woff": return "font/woff"
        case "woff2": return "font/woff2"
        default: return "application/octet-stream"
        }
    }
}
