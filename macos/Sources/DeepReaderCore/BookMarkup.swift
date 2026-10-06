// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import CoreFoundation

enum BookMarkup {
    static func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
    }
    static func decode(_ data: Data) throws -> String {
        if data.starts(with: [0xff, 0xfe]) || data.starts(with: [0xfe, 0xff]), let text = String(data: data, encoding: .utf16) { return text }
        if let text = String(data: data, encoding: .utf8) { return text.replacingOccurrences(of: "\u{feff}", with: "") }
        let gb = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))
        if let text = String(data: data, encoding: String.Encoding(rawValue: gb)) { return text }
        if let text = String(data: data, encoding: .windowsCP1252) { return text }
        throw ReaderError("无法识别文本编码，请另存为 UTF-8。", "Unrecognized text encoding. Save the file as UTF-8.")
    }
    static func xml(_ data: Data) throws -> XMLDocument {
        guard data.count <= 8 * 1024 * 1024 else { throw EBookError.tooLarge }
        let text = try decode(data)
        guard !text.localizedCaseInsensitiveContains("<!ENTITY") else { throw EBookError.invalid }
        return try XMLDocument(xmlString: text, options: [.nodeLoadExternalEntitiesNever])
    }
    static func elements(_ node: XMLNode, named name: String) -> [XMLElement] {
        // The parser has a bounded depth; walk iteratively to avoid a recursive Swift stack.
        var pending = [node], found: [XMLElement] = [], count = 0
        while let next = pending.popLast() {
            count += 1; if count > 100000 { break }
            if let element = next as? XMLElement, element.localName?.lowercased() == name { found.append(element) }
            pending.append(contentsOf: (next.children ?? []).reversed())
        }
        return found
    }
    static let blocked: Set<String> = ["script", "iframe", "frame", "frameset", "object", "embed", "applet", "form", "input", "button", "textarea", "select", "base", "meta", "audio", "video"]
    static let blocks: Set<String> = ["p", "div", "section", "article", "h1", "h2", "h3", "h4", "h5", "h6", "li", "br", "tr", "blockquote", "pre"]
    static func chapter(_ data: Data) throws -> (html: String, text: String, title: String) {
        guard data.count <= 8 * 1024 * 1024 else { throw EBookError.tooLarge }
        let decoded = try decode(data)
        guard !decoded.localizedCaseInsensitiveContains("<!ENTITY") else { throw EBookError.invalid }
        let document = try XMLDocument(xmlString: decoded, options: [.documentTidyHTML, .nodeLoadExternalEntitiesNever])
        guard let root = document.rootElement() else { throw EBookError.invalid }
        var pending: [(XMLNode, Int)] = [(root, 0)], count = 0
        while let (node, depth) = pending.popLast() {
            count += 1; guard count <= 100000, depth <= 180 else { throw EBookError.tooLarge }
            if let element = node as? XMLElement {
                let name = (element.localName ?? "").lowercased()
                if blocked.contains(name) { element.detach(); continue }
                for attribute in element.attributes ?? [] {
                    let key = (attribute.name ?? "").lowercased(), value = (attribute.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    if key.hasPrefix("on") || ["srcdoc", "action", "formaction", "ping"].contains(key) ||
                        (["href", "src", "xlink:href"].contains(key) && ["javascript:", "vbscript:", "file:"].contains(where: value.hasPrefix)) {
                        element.removeAttribute(forName: attribute.name ?? "")
                    }
                }
            }
            pending.append(contentsOf: (node.children ?? []).reversed().map { ($0, depth + 1) })
        }
        let body = elements(root, named: "body").first ?? root
        var text = "", stack: [XMLNode] = [body]
        while let node = stack.popLast() {
            let name = (node.localName ?? "").lowercased()
            if ["style", "head", "title"].contains(name) { continue }
            if blocks.contains(name) { text += "\n" }
            if node.kind == .text { text += node.stringValue ?? "" }
            stack.append(contentsOf: (node.children ?? []).reversed())
        }
        let title = elements(root, named: "h1").first?.stringValue ?? elements(root, named: "title").first?.stringValue ?? ""
        let head = elements(root, named: "head").first
        let styles = (head?.children ?? []).filter { ["style", "link"].contains(($0.localName ?? "").lowercased()) }.map { $0.xmlString }.joined()
        let content = (body.children ?? []).map { $0.xmlString }.joined()
        let html = """
        <!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src deepreader-book: data:; style-src deepreader-book: 'unsafe-inline'; font-src deepreader-book: data:; script-src 'none'; connect-src 'none'; object-src 'none'; frame-src 'none'; base-uri 'none'; form-action 'none'">
        \(styles)<style>
        :root { color-scheme: light; } html { background:#f5f6f3; } body { box-sizing:border-box; max-width:850px; margin:0 auto; padding:38px 42px 100px; background:#fffefa; color:#243229; font:18px/1.85 Georgia, 'Times New Roman', serif; overflow-wrap:anywhere; }
        p { margin:0.8em 0; } img,svg { max-width:100%; height:auto; } pre { white-space:pre-wrap; background:#f0f3ee; padding:16px; } code { font-family:Menlo,monospace; font-size:.88em; } a { color:#23774e; } blockquote { border-left:3px solid #8bba9b; margin-left:0; padding-left:18px; color:#526258; } table { border-collapse:collapse; max-width:100%; } td,th { border:1px solid #ccd5cc; padding:6px; } ::selection { background:#b7dec7; } ::highlight(deepreader) { background:#ffe59a; color:inherit; }
        @media (max-width:500px) { body { padding:24px 22px 80px; } }
        </style></head><body>\(content)</body></html>
        """
        return (html, text.trimmingCharacters(in: .whitespacesAndNewlines), String(title.prefix(160)))
    }
    static func textHTML(_ text: String) -> String { "<html><body><pre style=\"font:inherit;white-space:pre-wrap;background:transparent;padding:0\">\(escape(text))</pre></body></html>" }
    static func markdown(_ text: String) -> String {
        var output: [String] = [], paragraph: [String] = [], code: [String] = [], fence: String?, list: String?
        func inline(_ source: String) -> String {
            var value = escape(source)
            for (pattern, template) in [("`([^`]+)`", "<code>$1</code>"), ("\\*\\*([^*]+)\\*\\*", "<strong>$1</strong>"), ("__([^_]+)__", "<strong>$1</strong>"), ("\\*([^*]+)\\*", "<em>$1</em>"), ("\\[([^\\]]+)\\]\\(([^\\s)]+)\\)", "<a href=\"$2\">$1</a>")] {
                if let regex = try? NSRegularExpression(pattern: pattern) { value = regex.stringByReplacingMatches(in: value, range: NSRange(value.startIndex..., in: value), withTemplate: template) }
            }
            return value
        }
        func flush() { if !paragraph.isEmpty { output.append("<p>\(inline(paragraph.joined(separator: "\n")))</p>"); paragraph = [] } }
        func closeList() { if let tag = list { output.append("</\(tag)>"); list = nil } }
        for raw in text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if let marker = fence {
                if line.hasPrefix(marker) { output.append("<pre><code>\(escape(code.joined(separator: "\n")))</code></pre>"); code = []; fence = nil }
                else { code.append(raw) }; continue
            }
            if line.hasPrefix("```") || line.hasPrefix("~~~") { flush(); closeList(); fence = String(line.prefix(3)); continue }
            if line.isEmpty { flush(); closeList(); continue }
            let hashes = line.prefix(while: { $0 == "#" }).count
            if (1...6).contains(hashes), line.dropFirst(hashes).hasPrefix(" ") { flush(); closeList(); output.append("<h\(hashes)>\(inline(String(line.dropFirst(hashes + 1))))</h\(hashes)>"); continue }
            if ["---", "***", "___"].contains(line) { flush(); closeList(); output.append("<hr>"); continue }
            if line.hasPrefix("> ") { flush(); closeList(); output.append("<blockquote>\(inline(String(line.dropFirst(2))))</blockquote>"); continue }
            let unordered = ["- ", "* ", "+ "].contains(where: line.hasPrefix)
            let ordered = line.range(of: "^[0-9]+[.)]\\s+", options: .regularExpression)
            if unordered || ordered != nil {
                flush(); let tag = unordered ? "ul" : "ol"
                if list != tag { closeList(); output.append("<\(tag)>"); list = tag }
                let item = unordered ? String(line.dropFirst(2)) : String(line[ordered!.upperBound...])
                output.append("<li>\(inline(item))</li>"); continue
            }
            closeList(); paragraph.append(raw)
        }
        flush(); closeList()
        if fence != nil { output.append("<pre><code>\(escape(code.joined(separator: "\n")))</code></pre>") }
        return "<html><body>" + output.joined(separator: "\n") + "</body></html>"
    }
}
