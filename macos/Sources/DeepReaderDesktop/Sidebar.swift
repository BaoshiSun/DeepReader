// SPDX-License-Identifier: AGPL-3.0-or-later
import AppKit
import SwiftUI
import DeepReaderCore

struct ReadOnlyText: NSViewRepresentable {
    let text: String
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        let view = scroll.documentView as! NSTextView
        view.isEditable = false; view.isSelectable = true
        view.font = .systemFont(ofSize: 14)
        view.textContainerInset = NSSize(width: 10, height: 10)
        view.autoresizingMask = [.width]; view.isHorizontallyResizable = false; view.isVerticallyResizable = true
        view.textContainer?.widthTracksTextView = true
        view.backgroundColor = .textBackgroundColor
        scroll.hasVerticalScroller = true; scroll.autohidesScrollers = true
        return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        let view = scroll.documentView as! NSTextView
        if view.string != text { view.string = text; view.textColor = .textColor }
    }
}

private final class TextSplitView: NSSplitView, NSSplitViewDelegate {
    var onRatio: ((Double) -> Void)?
    var initial = true
    var ratio = 0.5
    let texts: [NSTextView]
    let labels: [NSTextField]
    init() {
        var editors: [NSTextView] = [], titles: [NSTextField] = []
        var panes: [NSView] = []
        for _ in 0..<2 {
            let label = NSTextField(labelWithString: "")
            label.font = .systemFont(ofSize: 12, weight: .medium); label.textColor = .secondaryLabelColor
            let scroll = NSTextView.scrollableTextView(), text = scroll.documentView as! NSTextView
            text.isEditable = false; text.isSelectable = true; text.font = .systemFont(ofSize: 14)
            text.textContainerInset = NSSize(width: 10, height: 8)
            text.isHorizontallyResizable = false; text.autoresizingMask = [.width]; text.textContainer?.widthTracksTextView = true
            scroll.hasVerticalScroller = true; scroll.autohidesScrollers = true
            let pane = NSView()
            label.translatesAutoresizingMaskIntoConstraints = false; scroll.translatesAutoresizingMaskIntoConstraints = false
            pane.addSubview(label); pane.addSubview(scroll)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: pane.leadingAnchor, constant: 6), label.topAnchor.constraint(equalTo: pane.topAnchor, constant: 5),
                scroll.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 5), scroll.leadingAnchor.constraint(equalTo: pane.leadingAnchor),
                scroll.trailingAnchor.constraint(equalTo: pane.trailingAnchor), scroll.bottomAnchor.constraint(equalTo: pane.bottomAnchor)])
            editors.append(text); titles.append(label); panes.append(pane)
        }
        texts = editors; labels = titles
        super.init(frame: .zero)
        isVertical = false; dividerStyle = .thin; delegate = self
        panes.forEach { addArrangedSubview($0) }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layout() {
        super.layout()
        if initial && bounds.height > 120 { initial = false; setPosition(bounds.height * ratio, ofDividerAt: 0) }
    }
    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat { bounds.height * 0.2 }
    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat { bounds.height * 0.8 }
    func splitViewDidResizeSubviews(_ notification: Notification) {
        guard !initial, bounds.height > 120 else { return }
        let next = min(0.8, max(0.2, arrangedSubviews[0].frame.height / bounds.height))
        if abs(next - ratio) > 0.01 { ratio = next; onRatio?(next) }
    }
}

private struct LookupSplit: NSViewRepresentable {
    @ObservedObject var model: ReaderModel
    func makeNSView(context: Context) -> TextSplitView {
        let view = TextSplitView(); view.ratio = model.settings.lookupSplit
        view.onRatio = { [weak model] value in
            DispatchQueue.main.async { guard let model = model else { return }; model.settings.lookupSplit = value; model.persist() }
        }
        return view
    }
    func updateNSView(_ view: TextSplitView, context: Context) {
        let values = [model.selected.isEmpty ? model.t("在左侧正文 中选词，然后按 ⌘⇧D。", "Select text in the book, then press ⌘⇧D.") : model.selected, model.answer]
        for index in 0..<2 where view.texts[index].string != values[index] { view.texts[index].string = values[index]; view.texts[index].textColor = .textColor }
        view.labels[0].stringValue = model.t("选中内容", "Selection")
        view.labels[1].stringValue = model.t("解释", "Explanation")
    }
}

struct Sidebar: View {
    @ObservedObject var m: ReaderModel
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "book.closed.fill").foregroundStyle(.green)
                Text("DeepReader").font(.headline)
                Spacer()
                Button(m.settings.english ? "中文" : "EN") { m.language() }.help(m.t("切换界面和回答语言", "Switch interface and answer language"))
                Button { m.floatAction?() } label: { Image(systemName: m.settings.floating ? "sidebar.right" : "macwindow") }
                    .help(m.t(m.settings.floating ? "停靠" : "悬浮", m.settings.floating ? "Dock" : "Float"))
                Button { m.hideAction?() } label: { Image(systemName: "xmark") }.help(m.t("收起侧栏", "Hide sidebar"))
            }
            if let book = m.book {
                VStack(alignment: .leading, spacing: 5) {
                    Text(book.title).lineLimit(1).font(.subheadline).help(book.file)
                    HStack(spacing: 5) {
                        ForEach(1...5, id: \.self) { star in
                            Button { m.rate(star) } label: {
                                Image(systemName: book.rating >= star ? "star.fill" : "star").foregroundStyle(.green).font(.system(size: 17))
                            }.buttonStyle(.plain).help(m.t("\(star) 星", "\(star) stars")).accessibilityLabel(m.t("\(star) 星", "\(star) stars"))
                        }
                        Spacer()
                        Picker("", selection: Binding(get: { book.finished }, set: { m.finish($0) })) {
                            Text(m.t("阅读中", "Reading")).tag(false); Text(m.t("读完", "Finished")).tag(true)
                        }.labelsHidden().frame(width: 95)
                        Button(m.t("归档", "Archive")) { m.archive() }
                    }.disabled(m.busy)
                }
                Divider()
            }
            Picker("", selection: $m.tab) {
                Text(m.t("解释", "Ask")).tag(0); Text(m.t("历史", "Log")).tag(1)
                Text(m.t("总结", "Summary")).tag(2); Text(m.t("书单", "Books")).tag(3); Text(m.t("设置", "Setup")).tag(4)
            }.pickerStyle(.segmented).labelsHidden()
            Group {
                switch m.tab {
                case 0: lookup
                case 1: history
                case 2: summary
                case 3: library
                default: settings
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            HStack(alignment: .top) {
                if m.busy { ProgressView().controlSize(.small); Button(m.t("取消", "Cancel")) { m.stop() } }
                ScrollView { Text(m.status).font(.caption).foregroundStyle(.secondary).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }.frame(maxHeight: 70)
            }.frame(height: 64, alignment: .top)
        }.padding(12).frame(minWidth: 336, minHeight: 480).tint(.green)
    }
    private var lookup: some View {
        VStack(spacing: 8) {
            LookupSplit(model: m).frame(minHeight: 150)
            HStack {
                Button(m.t("解释选中内容", "Explain selection")) { m.explain() }.disabled(m.busy)
                Button(m.t("高亮／不高亮", "Highlight / off")) { m.highlight() }
                Spacer(minLength: 0)
                if m.isPDF { Button(m.t("保存 PDF", "Save PDF")) { m.savePDF() }.disabled(!m.dirty) }
            }.controlSize(.small)
            Text(m.t("继续追问", "Follow-up")).font(.caption).frame(maxWidth: .infinity, alignment: .leading)
            TextEditor(text: $m.followup).font(.system(size: 13)).frame(height: 62).overlay(RoundedRectangle(cornerRadius: 4).stroke(.secondary.opacity(0.3)))
                .accessibilityLabel(m.t("追问输入框", "Follow-up input"))
            HStack { Text("⌘↩").font(.caption).foregroundStyle(.secondary); Spacer(); Button(m.t("发送追问", "Send follow-up")) { m.ask() }.disabled(m.busy || m.followup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }
    }
    private var history: some View {
        VStack(spacing: 8) {
            TextField(m.t("搜索词句、回答或日期", "Search text, answers or dates"), text: $m.historySearch)
            List(selection: $m.historyID) {
                ForEach(m.records.filter { $0.matches(m.historySearch) }) { record in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.selected.isEmpty ? record.title : record.selected).lineLimit(1)
                        Text("\(record.time.prefix(10)) · \(record.kind) · \(record.title)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }.tag(record.id)
                }
            }.frame(minHeight: 90, maxHeight: 160)
            ReadOnlyText(text: m.history?.text(english: m.settings.english) ?? m.t("选择一条已保存记录。", "Select a saved record."))
            HStack {
                Button(m.t("导出", "Export")) { if let record = m.history { m.export(record.text(english: m.settings.english), name: "DeepReader-Record") } }
                Spacer(); Button(m.t("删除", "Delete")) { m.deleteHistory() }
            }.disabled(m.history == nil || m.busy)
        }
    }
    private var summary: some View {
        VStack(spacing: 8) {
            Picker(m.t("范围", "Scope"), selection: $m.summaryScope) {
                Text(m.t("当前文件", "Current book")).tag(0); Text(m.t("日总结", "Daily")).tag(1)
                Text(m.t("周总结", "Weekly")).tag(2); Text(m.t("月总结", "Monthly")).tag(3)
            }.onChange(of: m.summaryScope) { _ in m.clearSummary() }.disabled(m.busy)
            if m.summaryScope > 0 { DatePicker(m.t("日期", "Date"), selection: $m.summaryDate, displayedComponents: .date).onChange(of: m.summaryDate) { _ in m.clearSummary() }.disabled(m.busy) }
            HStack {
                Button(m.t("统计／预览", "Stats / preview")) { m.prepareSummary() }.disabled(m.busy)
                Spacer(); Button(m.t("生成 AI 总结", "Summarize with AI")) { m.summarize() }.disabled(m.busy || !m.canSummarize)
            }
            if !m.summaryPreview.isEmpty { ScrollView { Text(m.summaryPreview).font(.caption).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }.frame(maxHeight: 135) }
            ReadOnlyText(text: m.summaryAnswer.isEmpty ? m.t("先预览本地统计与将发送的文字量，再生成总结。日、周、月总结依据已保存查询记录。", "Preview local statistics and the amount of text before generating a summary. Daily, weekly and monthly summaries use saved reading records.") : m.summaryAnswer)
            Button(m.t("导出总结", "Export summary")) { m.export(m.summaryAnswer, name: "DeepReader-Summary") }.disabled(m.summaryAnswer.isEmpty)
        }
    }
    private var library: some View {
        VStack(spacing: 8) {
            TextField(m.t("搜索书名或日期", "Search title or date"), text: $m.bookSearch)
            Picker("", selection: $m.bookFilter) {
                Text(m.t("全部", "All")).tag(0); Text(m.t("阅读中", "Reading")).tag(1); Text(m.t("读完", "Finished")).tag(2)
            }.pickerStyle(.segmented).labelsHidden()
            Text(Book.overview(m.filteredBooks, english: m.settings.english)).font(.caption).frame(maxWidth: .infinity, alignment: .leading)
            List(selection: $m.bookID) {
                ForEach(m.filteredBooks) { book in
                    VStack(alignment: .leading) {
                        Text(book.title).lineLimit(1)
                        Text(String(repeating: "★", count: book.rating) + " · " + (book.finished ? m.t("读完", "Finished") : m.t("阅读中", "Reading"))).font(.caption).foregroundStyle(.secondary)
                    }.tag(book.id)
                }
            }.frame(minHeight: 90, maxHeight: 160)
            ReadOnlyText(text: m.libraryBook?.text(records: m.records, english: m.settings.english) ?? m.t("打开文档或电子书 后会自动加入书单。", "Books are added to your book list when opened."))
            HStack {
                Button(m.t("打开书籍", "Open book")) { if let book = m.libraryBook { m.openBook(book) } }.disabled(m.libraryBook == nil || m.busy)
                Spacer(); Button(m.t("导出当前书单", "Export this list")) { m.exportBooks() }
            }
        }
    }
    private var settings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(m.t("AI 服务", "AI provider")).font(.headline)
                Picker(m.t("服务商", "Provider"), selection: Binding(get: { m.settings.provider }, set: { m.chooseProvider($0) })) {
                    ForEach(Provider.available()) { provider in Text(provider.rawValue).tag(provider) }
                }
                Picker(m.t("常用模型", "Model preset"), selection: Binding(get: { m.settings.provider.models.contains(m.modelDraft) ? m.modelDraft : "custom" }, set: { if $0 != "custom" { m.modelDraft = $0 } })) {
                    ForEach(m.settings.provider.models, id: \.self) { Text($0).tag($0) }
                    Text(m.t("自定义模型 ID", "Custom model ID")).tag("custom")
                }
                TextField(m.t("模型 ID", "Model ID"), text: $m.modelDraft)
                SecureField(m.t("API Key（留空保留已有密钥）", "API key (empty keeps saved key)"), text: $m.keyDraft)
                HStack {
                    Button(m.t("获取 API Key", "Get API key")) { NSWorkspace.shared.open(m.settings.provider.keyURL) }
                    Spacer(); Button(m.t("保存设置", "Save settings")) { m.saveConfiguration() }.buttonStyle(.borderedProminent)
                }
                Button(m.t("删除此服务的已存密钥", "Remove this provider's saved key")) { m.removeKey() }
                Text(Provider.isAppStoreBuild
                     ? m.t("AI 功能需要您自己的 DeepSeek API Key；费用、额度与可用性由 DeepSeek 决定。密钥只保存到 macOS 钥匙串。本地阅读不需要密钥。", "AI features require your own DeepSeek API key; DeepSeek fees, quotas and availability apply. Keys are stored in macOS Keychain. Local reading does not require a key.")
                     : m.t("默认 DeepSeek，需要您自行配置 API。OpenRouter 的免费模型也需要账户和密钥，额度与可用性由服务商决定。密钥只保存到 macOS 钥匙串。", "DeepSeek is the default and requires your own API key. OpenRouter free models also require an account and key; provider quotas and availability apply. Keys are stored in macOS Keychain.")).font(.caption).foregroundStyle(.secondary)
                Divider()
                Text(m.t("归档文件夹", "Archive folder")).font(.headline)
                Text(m.settings.archiveFolder.isEmpty ? m.t("尚未选择", "Not selected") : m.settings.archiveFolder).font(.caption).textSelection(.enabled)
                Button(m.t("选择文件夹…", "Choose folder…")) { m.chooseArchiveFolder() }
                Text(m.t("文件按 1星–5星文件夹复制保存，保留原文件；同名且内容不同的文件会自动编号。", "Files are copied into 1星–5星 folders, preserving originals. Different files with the same name receive a numbered suffix.")).font(.caption).foregroundStyle(.secondary)
                Divider()
                Text(m.t("使用方法", "Getting started")).font(.headline)
                Text(m.t("• 打开文档或电子书，拖动选词，按 ⌘⇧D。\n• 解释下方可追问，⌘↩ 发送。\n• 拖动侧栏边缘及选文／解释分隔线调整大小。\n• 右上角窗口按钮切换悬浮和停靠。\n• PDF 高亮后按 ⌘S 保存；电子书高亮自动保存在本机。", "• Open a document or ebook, select text, press ⌘⇧D.\n• Ask follow-ups below; ⌘↩ sends.\n• Drag sidebar and selection/answer dividers to resize.\n• Use the window button to float or dock the panel.\n• Save PDF highlights with ⌘S; ebook highlights are saved locally.")).font(.callout)
                Text(m.t("解释发送选文与附近上下文；全文总结发送提取的全文；周期总结发送该范围的历史记录。只在您点击 AI 操作时发送。", "Lookups send selected text and nearby context. Document summaries send extracted full text; period summaries send that period's records. Data is sent only when you request an AI action.")).font(.caption).foregroundStyle(.secondary)
                Link(m.t("源代码与许可证", "Source and license"), destination: URL(string: "https://github.com/BaoshiSun/DeepReader")!)
                Link(m.t("隐私政策", "Privacy policy"), destination: URL(string: "https://github.com/BaoshiSun/DeepReader/blob/codex/macos-native/docs/app-store/privacy-policy.md")!)
                Text("DeepReader for macOS · \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development") · AGPL-3.0-or-later").font(.caption2).foregroundStyle(.secondary)
            }.padding(3).textFieldStyle(.roundedBorder).disabled(m.busy)
        }
    }
}
