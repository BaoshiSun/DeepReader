// SPDX-License-Identifier: AGPL-3.0-or-later
import AppKit
import WebKit
import DeepReaderCore

public struct EBookSelection {
    public let text: String
    public let context: String
    public let page: Int
    public let mark: EBookMark
    public let fingerprint: String
}

private final class BookResources: NSObject, WKURLSchemeHandler {
    var book: EBookDocument?
    var host = UUID().uuidString.lowercased()
    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url, url.scheme == "deepreader-book", url.host == host,
              let book = book, let path = try? BookPath.resolve(String(url.path.dropFirst()), relativeTo: ""), let data = book.resources[path] else {
            task.didFailWithError(URLError(.fileDoesNotExist)); return
        }
        task.didReceive(URLResponse(url: url, mimeType: EBookDocument.mimeType(path), expectedContentLength: data.count, textEncodingName: "utf-8"))
        task.didReceive(data); task.didFinish()
    }
    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}
}

@MainActor public final class EBookReader: NSObject, WKNavigationDelegate {
    public let view: WKWebView
    public private(set) var book: EBookDocument?
    public private(set) var chapter = 0
    public private(set) var ready = false
    public private(set) var marks: [EBookMark] = []
    public var changed: (() -> Void)?
    public var failed: ((Error) -> Void)?
    private let resources = BookResources()
    private var zoom = 1.0
    private var navigation: WKNavigation?
    private var generation = 0
    public override init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        config.setURLSchemeHandler(resources, forURLScheme: "deepreader-book")
        view = WKWebView(frame: .zero, configuration: config)
        super.init(); view.navigationDelegate = self
        view.allowsBackForwardNavigationGestures = false
        view.setValue(false, forKey: "drawsBackground")
    }
    public func open(_ book: EBookDocument, marks: [EBookMark]) {
        self.book = book; self.marks = marks; resources.book = book; resources.host = UUID().uuidString.lowercased()
        zoom = 1; view.pageZoom = zoom; go(to: 0)
    }
    public func go(to index: Int) {
        guard let book = book, book.chapters.indices.contains(index) else { return }
        chapter = index; ready = false; generation += 1
        var url = URLComponents(); url.scheme = "deepreader-book"; url.host = resources.host; url.path = "/" + book.chapters[index].path
        if let url = url.url { navigation = view.load(URLRequest(url: url)) }; changed?()
    }
    public func zoomBy(_ factor: Double) { zoom = min(2.5, max(0.65, zoom * factor)); view.pageZoom = zoom }
    public func fit() { zoom = 1; view.pageZoom = 1 }
    public func find(_ value: String, backwards: Bool) {
        guard !value.isEmpty else { return }
        let options = WKFindConfiguration(); options.backwards = backwards; options.caseSensitive = false; options.wraps = true
        view.find(value, configuration: options) { _ in }
    }
    public func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url, url.scheme == "deepreader-book", url.host == resources.host,
              action.targetFrame?.isMainFrame == true, let book = book,
              let index = book.chapters.firstIndex(where: { "/" + $0.path == url.path }) else { decisionHandler(.cancel); return }
        chapter = index; changed?(); decisionHandler(.allow)
    }
    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        self.navigation = navigation; generation += 1; ready = false
    }
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard navigation === self.navigation else { return }
        let token = generation
        Task { @MainActor in
            do {
                try await renderHighlights(); guard generation == token else { return }
                ready = true; changed?()
            } catch { if generation == token { ready = false; failed?(error) } }
        }
    }
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard navigation === self.navigation, (error as NSError).code != NSURLErrorCancelled else { return }
        ready = false; failed?(error)
    }
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { self.webView(webView, didFail: navigation, withError: error) }
    public func javascript(_ code: String, arguments: [String: Any] = [:]) async throws -> Any? {
        try await view.callAsyncJavaScript(code, arguments: arguments, in: nil, contentWorld: .defaultClient)
    }
    public func selected() async throws -> EBookSelection {
        guard ready, let book = book else { throw ReaderError("电子书仍在加载，请稍候。", "The ebook is still loading. Please wait.") }
        let expected = book.fingerprint, page = chapter, token = generation
        let result = try await javascript(Self.selectionScript)
        guard ready, generation == token, self.book?.fingerprint == expected, chapter == page, let result = result as? [String: Any],
              let text = result["text"] as? String, let context = result["context"] as? String,
              let start = result["start"] as? Int, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ReaderError("请先在正文中拖动选中文字，再按 ⌘⇧D。", "Select text in the book, then press ⌘⇧D.")
        }
        guard text.utf16.count <= 2200, context.utf16.count <= 5000 else { throw ReaderError("请选取 2200 字符以内的词句。", "Select a passage up to 2,200 characters.") }
        let mark = EBookMark(chapter: book.chapters[page].path, start: start, length: text.utf16.count, quote: text)
        guard mark.valid else { throw ReaderError("无法定位选文，请重新选择。", "Could not locate the text. Select it again.") }
        return EBookSelection(text: text, context: "[Chapter \(page + 1): \(book.chapters[page].title)]\n" + context, page: page + 1, mark: mark, fingerprint: expected)
    }
    public func toggled(_ selection: EBookSelection) throws -> [EBookMark] {
        guard selection.fingerprint == book?.fingerprint else { throw ReaderError("文档已切换，请重新选择。", "The document changed. Select the text again.") }
        var next = marks
        if let index = next.firstIndex(of: selection.mark) { next.remove(at: index) } else { next.append(selection.mark) }
        return next
    }
    public func setMarks(_ next: [EBookMark]) async throws { marks = next; if ready { try await renderHighlights() } }
    private func renderHighlights() async throws {
        guard let book = book else { return }
        let ranges: [[String: Any]] = marks.filter { $0.chapter == book.chapters[chapter].path }.map { ["start": $0.start, "length": $0.length, "quote": $0.quote] }
        _ = try await javascript(Self.rangeScript + """
        const ranges = marks.map(m => makeRange(m.start, m.length, m.quote)).filter(Boolean);
        if (CSS.highlights && typeof Highlight !== 'undefined') {
            CSS.highlights.set('deepreader', new Highlight(...ranges));
        } else {
            // Safari before the CSS Highlight API: wrappers retain exactly the same text offsets.
            document.querySelectorAll('mark[data-deepreader]').forEach(m => m.replaceWith(...m.childNodes));
            document.body.normalize();
            for (const m of [...marks].sort((a,b) => b.start-a.start)) {
                const r = makeRange(m.start, m.length, m.quote); if (!r) continue;
                const nodes = []; const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
                let n, offset = 0;
                while (n = walker.nextNode()) { const end = offset+n.length; if (end > m.start && offset < m.start+m.length) nodes.push([n, Math.max(0,m.start-offset),Math.min(n.length,m.start+m.length-offset)]); offset=end; }
                for (const [node,start,end] of nodes.reverse()) {
                    const piece = node.splitText(start); piece.splitText(end-start);
                    const wrapper = document.createElement('mark'); wrapper.dataset.deepreader='1'; wrapper.style.background='#ffe59a';
                    piece.replaceWith(wrapper); wrapper.appendChild(piece);
                }
            }
        }
        return ranges.length;
        """, arguments: ["marks": ranges])
    }
    // Offsets use DOM textContent / UTF-16, not Range.toString across synthetic paragraph breaks.
    static let rangeScript = """
    function makeRange(start, length, quote) {
        const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT); let n, offset=0, a=null, b=null;
        while (n=walker.nextNode()) { const end=offset+n.length;
            if (!a && start>=offset && start<end) a=[n,start-offset];
            if (start+length>offset && start+length<=end) { b=[n,start+length-offset]; break; } offset=end;
        }
        if (!a || !b) return null; const r=document.createRange(); r.setStart(...a); r.setEnd(...b);
        return !quote || r.toString()===quote ? r : null;
    }
    """
    static let selectionScript = """
    const s=getSelection(); if (!s || !s.rangeCount || s.isCollapsed) return null;
    const r=s.getRangeAt(0); if (!document.body.contains(r.commonAncestorContainer)) return null;
    const before=document.createRange(); before.selectNodeContents(document.body); before.setEnd(r.startContainer,r.startOffset);
    const start=before.toString().length, text=r.toString(), all=document.body.textContent;
    if (all.slice(start,start+text.length)!==text) return null;
    return {text,start,context:all.slice(Math.max(0,start-900),start)+'⟦'+text+'⟧'+all.slice(start+text.length,start+text.length+900)};
    """
    public func selectForTesting(_ text: String, last: Bool = false) async throws {
        _ = try await javascript(Self.rangeScript + """
        const source=document.body.textContent; const start=last ? source.lastIndexOf(text) : source.indexOf(text);
        const range=makeRange(start,text.length,text); if (!range) throw new Error('Fixture text missing');
        const selection=getSelection(); selection.removeAllRanges(); selection.addRange(range); return true;
        """, arguments: ["text": text, "last": last])
    }
}
