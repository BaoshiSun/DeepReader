# DeepReader for macOS · 1.2.0 preview

macOS 13 Ventura 或更新版本，通用应用同时支持 Apple Silicon（M 系列）和 Intel。使用 Apple PDFKit、AppKit 与 SwiftUI 重新实现阅读界面，无需 Python、Wine 或外部助手。目前支持 PDF；不包含 Windows SumatraPDF 的 EPUB、漫画等格式功能。本版为首个 Mac 测试版。

## 安装

打开 `DeepReader-v1.2.0-macos-universal.dmg`，将 DeepReader 拖到 Applications，然后从 Applications 启动。也可以解压 universal ZIP，将其中的 DeepReader.app 拖到 Applications。不要从只读磁盘映像运行。

本测试版仅经过 ad-hoc 本地代码签名，**尚无 Apple Developer ID 签名或 Apple 公证**。从网络下载后，macOS 可能阻止首次打开。确认文件来自本项目并核对 SHA-256 后，尝试打开，再到“系统设置 → 隐私与安全性 → 仍要打开”按系统提示操作。受组织管理的 Mac 可能不允许此操作。不要全局关闭 Gatekeeper。正式的 Developer ID 签名和公证需要维护者提供 Apple 开发者凭据。

## 开始使用

1. 右侧 AI 面板默认可见；首次启动在“设置”页显示引导，后续不再重复弹出。
2. 默认使用 DeepSeek。选择模型，填写自己的 API Key 并保存；密钥仅存入 macOS 钥匙串。空白密钥框保留已有 Key。OpenRouter 免费路由也需要您自己的账号和 Key，不承诺永久免费额度。
3. 按 **⌘O** 打开 PDF，拖动选中文字，按 **⌘⇧D** 获取简短语境解释。扫描 PDF 需先通过其他工具 OCR。
4. 解释下方可继续追问，**⌘↩** 发送。成功查询和追问自动保存到本机。
5. 拖动侧栏边界调整宽度；顶部窗口按钮切换悬浮和停靠。选文与解释初始各占一半，细分隔线可调整比例。**⌘⇧A** 重新显示侧栏。
6. “高亮／不高亮”只切换 DeepReader 对该选区生成的批注，按 **⌘S** 写入 PDF。关闭或换文件前会提示未保存改动；可用“文件 → 保存 PDF 副本”另存。
7. 点 1–5 星、选择“阅读中／读完”，再归档。程序复制到指定目录下 `1星`–`5星`，保留原文件，不覆盖同名不同内容的 PDF。书单可搜索、筛选、打开和导出。
8. “总结”中选择文件／日／周／月，先预览真实本地统计和预计 API 请求数，再生成 AI 总结。长文分段处理全部可提取文本；没有文字的页面会明确提示，暂不提供 OCR。周从周一开始。日、周、月依据保存的记录，手动生成。

点击 EN／中文可同时切换界面和后续 AI 回答。已有历史保留生成时的语言。

## 隐私与数据

个人文件保存在 `~/Library/Application Support/DeepReader/`，包括 `settings.json`、`AIHistory/`、`BookLibrary/`；API Key 单独存入系统钥匙串。Mac 与 Windows 使用独立配置，不会自动迁移 Windows 的 DPAPI 密钥或路径。

仅主动执行 AI 操作时联网：解释发送选文及附近语境，追问增加当前对话，全文总结发送提取的全文，周期总结发送该日期范围的记录。PDF 二进制不会上传；程序不会把本机目录路径主动加入提示词。文字中原本包含的信息仍会发送。无遥测、无内置共享 Key、无自动付费后备模型。API 费用与服务可用性由用户选定服务商决定。

查询失败、取消或截断的回答不计入成功查询。API Key 不写入设置 JSON、日志和发行包。归档、评分、书单与本地统计不需要 API。AI 可能出错，请结合原文核对。

## 源码构建与验证

安装 Xcode 15 或更新版本以及其命令行工具。没有第三方 Swift 包依赖。

```sh
cd macos
swift test
bash build.sh
```

输出在 `macos/dist/`：Universal `.app` ZIP、DMG、对应源码 ZIP、SHA-256，以及离线应用启动测试结果。脚本分别编译 arm64 和 x86_64，再通过 lipo 合并；只进行 ad-hoc 签名，不使用 Apple 账户凭据。GitHub Actions 分别在 Apple Silicon 和 Intel macOS 15 上执行离线测试，并在 ARM 主机上运行打包应用的启动测试。最低目标版本为 macOS 13；CI 结果不代表已在每个 macOS 版本或实体设备上人工测试。

## 开源说明

此 Mac 实现是 DeepReader 项目的一部分，采用 **AGPL-3.0-or-later**；源码与构建脚本随应用保存在 `DeepReader.app/Contents/Resources/Source.zip`，可通过 Finder“显示包内容”查看。PDFKit、AppKit、SwiftUI 为系统框架，没有复制 SumatraPDF 的 Windows 阅读器引擎。Windows 代码及其上游许可证、署名继续保留。

新增代码和文档主要由 AI 制作，日常维护托管给 AI，管理者不定期审查。项目：[BaoshiSun/DeepReader](https://github.com/BaoshiSun/DeepReader)。

## English quick start

Requires macOS 13+, Apple Silicon or Intel. This native PDFKit preview supports PDF files. Mount the DMG and drag DeepReader to Applications. The app is **ad-hoc signed and not notarized**; macOS may require an explicit “Open Anyway” in Privacy & Security after the first attempt. Do not disable Gatekeeper globally.

Open Setup, click EN, choose a provider and save your own API key. DeepSeek is the default; free OpenRouter models still require an account and key. Keys are stored in macOS Keychain. Open a PDF with **⌘O**, select text, press **⌘⇧D**, and ask follow-ups with **⌘Return**. Resize or float the AI sidebar; use **⌘⇧A** to show it again. Save highlights with **⌘S**. Rate and mark books as Reading/Finished, copy them into star-rating archive folders, and export your book list. Summary supports full extracted document text and daily/weekly/monthly reading records, with local statistics and a request preview before sending.

The app stores its data in `~/Library/Application Support/DeepReader/`. It does not migrate Windows settings automatically. No OCR, telemetry, shared API keys or automatic paid fallback. AGPL-3.0-or-later; corresponding source and licenses are embedded in the app. Development and maintenance are primarily AI-assisted, with periodic human review.
