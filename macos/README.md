# DeepReader for macOS · 1.2.1 preview

macOS 13 Ventura 或更新版本，通用应用同时支持 Apple Silicon（M 系列）和 Intel。使用 Apple PDFKit、AppKit、SwiftUI 与 WebKit 实现阅读界面，无需 Python、Wine、Calibre 或外部助手。1.2.1 在原有 PDF 阅读功能上新增 EPUB、TXT、Markdown、MOBI 和 AZW3，继续共用 AI 解释、追问、历史、总结、评分、阅读状态、归档和书单。

| 格式 | 阅读支持 |
| --- | --- |
| PDF | 保留原生 PDFKit 阅读、搜索、保存高亮批注；扫描图片仍需另行 OCR |
| EPUB | 按书内 spine 顺序切换章节，显示内嵌图片和样式；顶部目录切换章节 |
| TXT | UTF-8、带 BOM 的 UTF-16、GB18030，兼容部分西文文本 |
| Markdown（.md / .markdown） | 标题、段落、列表、引用、粗体、斜体、代码块；原始 HTML 按文字显示；不执行脚本 |
| MOBI / AZW3 | 内置 libmobi 读取旧 MOBI 和 KF8/AZW3，包括正文、图片、章节；无需外部转换 |

仅支持未加 DRM 的电子书；Kindle KFX、漫画档案、音视频和交互式电子书不在本版范围内。电子书采用连续滚动排版，顶部数字为章节数，搜索作用于当前章节。书内的远程资源与脚本不会加载；仅允许在本书章节之间跳转。EPUB 字体混淆使用系统替代字体，复杂固定版式可能与原阅读器不同。

电子书文件上限 128 MB，解包总量 256 MB，单个资源 32 MB、单个正文或 XML 文件 8 MB。全文 AI 总结最多提取 200 万 UTF-16 字符，超过时会明确提示，不会悄悄截断。

## 安装

从 [macOS 1.2.1 发布页](https://github.com/BaoshiSun/DeepReader/releases/tag/v1.2.1-macos)下载安装包；同页提供对应源码和 `SHA256SUMS.txt`。

打开 `DeepReader-v1.2.1-macos-universal.dmg`，将 DeepReader 拖到 Applications，然后从 Applications 启动。也可以解压 universal ZIP，将其中的 DeepReader.app 拖到 Applications。不要从只读磁盘映像运行。更新时替换应用即可，现有设置、钥匙串密钥、历史和书单沿用。

本测试版仅经过 ad-hoc 本地代码签名，**尚无 Apple Developer ID 签名或 Apple 公证**。从网络下载后，macOS 可能阻止首次打开。确认文件来自本项目并核对 SHA-256 后，尝试打开，再到“系统设置 → 隐私与安全性 → 仍要打开”按系统提示操作。受组织管理的 Mac 可能不允许此操作。不要全局关闭 Gatekeeper。正式的 Developer ID 签名和公证需要维护者提供 Apple 开发者凭据。

## 开始使用

1. 右侧 AI 面板默认可见；首次启动在“设置”页显示引导，后续不再重复弹出。
2. 默认使用 DeepSeek。选择模型，填写自己的 API Key 并保存；密钥仅存入 macOS 钥匙串。空白密钥框保留已有 Key。OpenRouter 免费路由也需要您自己的账号和 Key，不承诺永久免费额度。
3. 按 **⌘O** 打开文档或电子书，拖动选中文字，按 **⌘⇧D** 获取简短语境解释。扫描 PDF 需先通过其他工具 OCR。
4. 解释下方可继续追问，**⌘↩** 发送。成功查询和追问自动保存到本机。
5. 拖动侧栏边界调整宽度；顶部窗口按钮切换悬浮和停靠。选文与解释初始各占一半，细分隔线可调整比例。**⌘⇧A** 重新显示侧栏。
6. “高亮／不高亮”切换该选区的标记。PDF 按 **⌘S** 写入批注，关闭或换文件前会提示未保存改动；可用“文件 → 保存 PDF 副本”另存。电子书高亮自动保存在本机 `BookHighlights/`，重新打开可恢复，不改写 EPUB/MOBI 等原文件。文件内容变化后旧高亮不会错误地套用到新文字上。
7. 点 1–5 星、选择“阅读中／读完”，再归档。程序按原格式复制到指定目录下 `1星`–`5星`，保留原文件，不覆盖同名不同内容的文件。原书与归档副本使用同一条书单记录及本地高亮；仅把电子书文件拷到另一台电脑不包含本地高亮。书单可搜索、筛选、打开和导出。
8. “总结”中选择文件／日／周／月，先预览真实本地统计和预计 API 请求数，再生成 AI 总结。长文分段处理全部可提取文本；没有文字的页面会明确提示，暂不提供 OCR。周从周一开始。日、周、月依据保存的记录，手动生成。

点击 EN／中文可同时切换界面和后续 AI 回答。已有历史保留生成时的语言。

## 隐私与数据

个人文件保存在 `~/Library/Application Support/DeepReader/`，包括 `settings.json`、`AIHistory/`、`BookLibrary/`、`BookHighlights/`；API Key 单独存入系统钥匙串。备份此目录可保留阅读记录和电子书高亮。Mac 与 Windows 使用独立配置，不会自动迁移 Windows 的 DPAPI 密钥或路径。

仅主动执行 AI 操作时联网：解释发送选文及附近语境，追问增加当前对话，全文总结发送按章节顺序提取的全文，周期总结发送该日期范围的记录。文档二进制不会上传；程序不会把本机目录路径主动加入提示词。文字中原本包含的信息仍会发送。无遥测、无内置共享 Key、无自动付费后备模型。API 费用与服务可用性由用户选定服务商决定。

查询失败、取消或截断的回答不计入成功查询。API Key 不写入设置 JSON、日志和发行包。归档、评分、书单与本地统计不需要 API。AI 可能出错，请结合原文核对。

## 源码构建与验证

Developer ID 签名、公证工具及安装 Xcode 的步骤见 [发行工具说明](DISTRIBUTION.md)。商店文案、隐私政策草稿和尚未完成的沙盒／审核事项见 [Mac App Store 准备包](../docs/app-store/README.md)。这些准备材料不表示当前测试版已满足商店提交要求。

安装 Xcode 15 或更新版本以及其命令行工具。没有第三方 Swift 包依赖；libmobi 0.12 的固定版本源码随仓库提供，使用系统 libarchive 和 zlib。

```sh
cd macos
python3 Tests/make_format_fixtures.py
swift test
bash build.sh
```

CI 额外执行 `python3 macos/Tests/make_format_fixtures.py --upstream`，下载并校验固定 SHA-256 的 libmobi 官方 MOBI/KF8/DRM 样本，再离线测试；样本只在 `.build/` 中，不打入应用。没有下载官方样本时，仅这一项真实 MOBI/KF8 样本测试跳过，其余合成文档、界面和 AI 离线测试仍执行。

输出在 `macos/dist/`：Universal `.app` ZIP、DMG、对应源码 ZIP、SHA-256，以及离线应用启动测试结果。脚本分别编译 arm64 和 x86_64，再通过 lipo 合并；只进行 ad-hoc 签名，不使用 Apple 账户凭据。GitHub Actions 分别在 Apple Silicon 和 Intel macOS 15 上执行离线测试，并在 ARM 主机上运行打包应用的启动测试。最低目标版本为 macOS 13；CI 结果不代表已在每个 macOS 版本或实体设备上人工测试。

## 开源说明

此 Mac 实现是 DeepReader 项目的一部分，采用 **AGPL-3.0-or-later**；源码与构建脚本随应用保存在 `DeepReader.app/Contents/Resources/Source.zip`，可通过 Finder“显示包内容”查看。libmobi 保留 **LGPL-3.0-or-later** 原许可、版权、对应源码和重新链接构建步骤，详见 `Vendor/libmobi/` 及第三方声明。PDFKit、AppKit、SwiftUI、WebKit 为系统框架，没有复制 SumatraPDF 的 Windows 阅读器引擎。Windows 代码及其上游许可证、署名继续保留。

新增代码和文档主要由 AI 制作，日常维护托管给 AI，管理者不定期审查。项目：[BaoshiSun/DeepReader](https://github.com/BaoshiSun/DeepReader)。

## English quick start

Requires macOS 13+, Apple Silicon or Intel. Version 1.2.1 supports PDF, EPUB, TXT, Markdown, and DRM-free MOBI/KF8/AZW3. Mount the DMG and drag DeepReader to Applications. Existing settings, history and Keychain credentials are retained when replacing the app. The app is **ad-hoc signed and not notarized**; macOS may require an explicit “Open Anyway” in Privacy & Security after the first attempt. Do not disable Gatekeeper globally.

Open Setup, click EN, choose a provider and save your own API key. DeepSeek is the default; free OpenRouter models still require an account and key. Keys are stored in macOS Keychain. Open a document with **⌘O**, select text, press **⌘⇧D**, and ask follow-ups with **⌘Return**. Resize or float the AI sidebar; use **⌘⇧A** to show it again. Save PDF highlights with **⌘S**; ebook highlights save automatically in local BookHighlights data. Use the chapter menu or arrows to navigate ebooks; search applies to the current chapter. Remote resources and scripts are blocked. Rate and mark books as Reading/Finished, copy them in their original format into star-rating archive folders, and export your book list. Summary supports full extracted document text and daily/weekly/monthly reading records, with local statistics and a request preview before sending.

The app stores its data in `~/Library/Application Support/DeepReader/`. It does not migrate Windows settings automatically. No OCR, telemetry, shared API keys or automatic paid fallback. AGPL-3.0-or-later; corresponding source and licenses are embedded in the app. Development and maintenance are primarily AI-assisted, with periodic human review.
