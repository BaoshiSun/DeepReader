# 第三方组件与授权

DeepReader 1.0.0 是基于 SumatraPDF 3.6.1rel 的独立修改版，修改日期 2026-10-05。原创增量及保留的旧版助手原创代码采用 AGPL-3.0-or-later，Copyright 2026 DeepReader contributors；完整许可见 LICENSE-AGPL-3.0.txt。上游代码保留各自许可证；本声明不重新许可上游代码。

## 当前原生阅读器

- SumatraPDF 主体：GPLv3；部分 utils / mui 代码为 BSD。保留上游 COPYING、COPYING.BSD 与 AUTHORS，Copyright 2006–2025 the SumatraPDF project authors。
- MuPDF：AGPLv3；许可位于上游源码的 mupdf/COPYING。
- SumatraPDF 的其他内嵌组件：保留 ext/ 等目录中的各自版权与许可。
- Microsoft WebView2 Loader SDK 1.0.992.28：保留锁定 SDK 包内的三条款 BSD 风格 Microsoft 授权原文，见 WebView2-LICENSE.txt；AI 侧栏本身不使用 WebView2。
- Microsoft C++ 编译器、Windows SDK、MSBuild：构建时下载官方组件到本地，受各自许可约束；不将编译工具链打入运行包。

便携发布包的 source/upstream/sumatrapdf-3.6.1rel.zip 包含完整对应上游源码、上述原有授权与作者文件；新增源码及重建步骤位于 source/。GitHub 源码仓库中的 native/source-lock.json 固定了上游下载 URL 与 SHA-256。

上游项目：https://github.com/sumatrapdfreader/sumatrapdf

上游 AUTHORS 明确指出，因 MuPDF，AGPLv3 第 13 条亦适用于 SumatraPDF。GPLv3 与 AGPLv3 的第 13 条允许相关组合；各部分原许可不变。允许按这些许可修改、再分发，无任何担保。完整核对见源码中的 docs/LICENSE-REVIEW.md。

## 图标、字体与其他组件

当前绿色应用图标改编自上游图标，原作者 **Alex**（koo.studios at gmail.com，原地址 zenon38 at gmail.com），使用 **CC BY 3.0**：https://creativecommons.org/licenses/by/3.0/ 。来源：上游 gfx/SumatraPDF*.png、gfx/SumatraPDF.ico 及 AUTHORS。DeepReader 于 2026-10-05 使用 AI 辅助将图标改为绿色，并转换为多尺寸 Windows ICO；改编图标继续按 CC BY 3.0 提供，位于 source/assets/。不表示原作者认可本项目。

其他图标作者包括 Zenon、Sonke Tesch、George Georgiou、Robert Hegner、FAMFAMFAM 和 Yusuke Kamiyamane。Fugue Icons 由 Yusuke Kamiyamane 创作，CC BY 3.0，https://p.yusukekamiyamane.com/ 。完整原始声明保留在上游归档内。

其余上游组件包括 bzip2、CHMLIB、FreeType、jbig2dec、libjpeg-turbo、DjVuLibre、OpenJPEG、SyncTeX、zlib、lzma、libwebp、unarr，以及 MuPDF 内的 CMap、字体和其他资源。各组件的完整版权、授权条件和免责声明均在随包 source/upstream/sumatrapdf-3.6.1rel.zip 内；AUTHORS 提供路径索引，不以本概述替代原文。翻译者见同归档 TRANSLATORS。

本软件部分基于 FreeType Team 的工作。Portions of this software are based on the work of the FreeType Team. FreeType 原许可见上游 ext/freetype/docs/FTL.TXT，https://freetype.org/ 。

**UnRAR 未编译或链接进 DeepReader。** 上游固定归档内保留其原始源码和 ext/unrar/license.txt（Alexander Roshal 所有，具有用途限制，并非普通自由软件许可），作为未使用的独立上游材料随原归档提供，不将其重新许可为 GPL / AGPL。补丁移除所有 UnRAR 链接项及备用调用，仅保留开源 unarr；部分 RAR / CBR 因此可能不受支持。

## 保留的 1.x 外部助手与测试依赖

旧版 src/context_worker.py 以及合成 PDF 测试使用 PyMuPDF / MuPDF（AGPLv3 或商业许可）。原生阅读器运行时不需要 Python。

旧版 context-worker 分发包包含 Python（PSF 许可）及 PyMuPDF 等依赖，保留 PyInstaller 收集的 dist-info 与许可文件。PyInstaller 采用 GPL 及允许分发生成程序的引导加载器例外。

相关名称和标志属于各自权利人。本项目不代表上述项目或模型服务商。
