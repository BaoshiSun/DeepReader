# DeepReader for macOS · 1.3.2 离线千问版

内置 **Qwen3 0.6B · Q4_K_M**，选文解释和追问在 Mac 上运行。免费，无广告、账户、API Key、订阅或问答次数限制。模型随安装包提供，无需首次下载，不调用云端 AI，也不联网搜索。**答案可能不准确、不完整或产生虚构信息，请核对原文。**

需要 macOS **13.3 或更新版本**；同一安装包支持 Apple Silicon（M 系列）与 Intel。应用约需 550 MB 磁盘空间，生成答案还需要额外运行内存。速度、耗电和发热取决于设备。小模型适合简单词句释义，复杂推理、专业知识及计算可能不可靠。

## 下载与安装

从 [macOS 1.3.2 发布页](https://github.com/BaoshiSun/DeepReader/releases/tag/v1.3.2-macos)下载 `DeepReader-v1.3.2-macos-universal.dmg`，打开后将 DeepReader 拖到 Applications，再从 Applications 启动。也可使用 universal ZIP。更新前退出旧应用并保存文档。

正式 Release 附件在 Developer ID 签名、Apple 公证、票据及 Gatekeeper 验证通过后发布。自行构建的包仅有 ad-hoc 签名。公证与 Mac App Store 审核是独立流程；本安装包不会替换商店送审构建。

旧 GitHub 直接安装版的书单、设置、高亮和历史使用相同本机资料目录。新版本不读取旧 API Key，钥匙串中的旧条目可能仍保留。Mac App Store 使用独立沙盒，数据不会自动迁移到 GitHub 版。

## 阅读与问答

1. 按 **⌘O** 打开文档，或在设置中选择“打开示例文章”。
2. 选择短句，按 **⌘⇧D** 解释选文；输入追问后按 **⌘Return**。
3. “仅书中内容”要求依据提供的选文和附近语境回答；“结合通用知识”允许使用本地模型已有知识。两种模式都离线，也都可能出错。
4. 拖动侧栏边界调整空间，或切换为悬浮助手；按 **⌘⇧A** 重新显示助手。
5. PDF 高亮按 **⌘S** 保存，或“保存 PDF 副本”。电子书高亮保存在本机，不改写原文件。
6. 可评分、标记阅读状态、归档原书副本、搜索和导出书单。成功问答保存到本机历史；界面支持中文和英文。

问答使用选文前 500 字、附近语境前 600 字；追问前 300 字和历史末尾 250 字。输入上限 1536 tokens、回答上限 320 tokens。**本版不提供全文或日／周／月 AI 总结。**

| 格式 | 支持范围 |
| --- | --- |
| PDF | 原生 PDFKit 阅读、搜索、保存高亮；不提供扫描 OCR |
| EPUB | 章节、内嵌图片和样式；复杂固定版式可能有差异 |
| TXT | UTF-8、带 BOM 的 UTF-16、GB18030，兼容部分西文文本 |
| Markdown | 常用 Markdown 排版；原始 HTML 显示为文字，不执行脚本 |
| MOBI / AZW3 | 内置 libmobi，读取无 DRM 的旧 MOBI 和 KF8/AZW3 |

不支持 DRM、Kindle KFX、漫画档案、音视频和交互式电子书。电子书连续滚动，搜索限当前章节；书内脚本及远程资源被阻止。文件上限 128 MB，解包总量 256 MB，单个资源 32 MB，单个正文/XML 文件 8 MB。

## 隐私与源码

阅读资料保存在 `~/Library/Application Support/DeepReader/`，包括设置、AIHistory、BookLibrary、BookHighlights 和文件访问书签。问答、选文和附近语境不会为 AI 推理上传。无广告、遥测或开发者服务器；主动导出、分享和打开外部链接由用户控制。备份此目录可以保留阅读资料。详见[隐私政策](https://github.com/BaoshiSun/DeepReader/blob/codex/main/docs/app-store/privacy-policy.md)。

代码采用 **AGPL-3.0-or-later**，对应源码和提交号随应用放在 `Contents/Resources/Source.zip`、`SOURCE-COMMIT.txt`。libmobi 保留 LGPL-3.0-or-later，Qwen 模型为 Apache 2.0，llama.cpp 为 MIT；许可和第三方署名随包提供。构建脚本使用固定版本、校验模型及推理依赖，并提供重新构建／链接方法。

## 构建与验证

安装完整 Xcode 及 Python 3.12+，在仓库根目录执行：

```sh
python3 tools/public_release.py --check-tracked
python3 -m unittest discover -s tests -p test_distribution.py -v
bash macos/build_offline.sh artifacts/macos-offline
```

输出目录必须不存在。脚本校验并准备模型/llama.cpp，编译 arm64 和 x86_64，嵌入推理框架与模型，生成开发 ZIP，并运行文档阅读烟雾检查及真实本地推理、追问、取消和示例文章检查。测试使用独立资料目录。

通过 `macos/distribute.sh` 对生成的 `.app` 做 Developer ID 签名，生成 DMG/ZIP；按 [发行工具说明](DISTRIBUTION.md)完成公证、票据和 Gatekeeper 验证后才上传正式 Release。发布版源码提交必须与 `SOURCE-COMMIT.txt`、源码包清单一致。

`macos/Package.swift` 和 `macos/build.sh` 仍保留可选在线多服务商开发构建，需要用户自己的 Key；它不是 1.3.2 离线 Release 的构建入口。其数据处理见[旧联网版本说明](../docs/app-store/privacy-policy-legacy.md)。Mac App Store 的独立构建见 [AppStore/README.md](AppStore/README.md)。

## English quick start

DeepReader 1.3.2 bundles Qwen3 0.6B for entirely on-device passage explanations and follow-up questions. Free, no ads, account, API key, subscription or question quota. Requires macOS 13.3+ on Apple Silicon or Intel. Allow approximately 550 MB of disk space plus runtime memory. AI answers may be inaccurate; verify against the source. Document and period summaries are unavailable.

Download the universal DMG or ZIP, quit the previous app, and drag DeepReader to Applications. Open a document with **⌘O**, select text and press **⌘⇧D**. Ask follow-ups with **⌘Return**. Resize or float the sidebar; **⌘⇧A** shows it again. Book only and General knowledge both use the bundled model without web search. Save PDF highlights with **⌘S**. EPUB/TXT/Markdown and DRM-free MOBI/AZW3 are also supported.

Published assets require Developer ID signing and accepted Apple notarization. Locally generated development ZIPs are ad-hoc signed. Reading data remains on the Mac; direct-download profiles persist across updates, while Mac App Store sandbox data does not migrate automatically. Corresponding source, licenses and build instructions are included. Development is assisted by AI and periodically reviewed by the maintainer.
