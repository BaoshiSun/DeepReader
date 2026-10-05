# DeepReader · AI 阅读器

基于 **SumatraPDF 3.6.1rel** 的 Windows x64 原生定制版，提供可调宽度、可收起或悬浮的 AI 侧栏。选中词句、按 **Ctrl + Alt + D**，即可结合附近上下文获得简短解释。

项目地址：[BaoshiSun/DeepReader](https://github.com/BaoshiSun/DeepReader)。**1.0.0 是首个公开发行版本。**

这是独立开源项目，不是 SumatraPDF 官方发布。当前源码版本 **1.1.0**，尚未发布到 GitHub Release；公开下载仍为 **1.0.0**。代码采用 **AGPL-3.0-or-later**，上游组件保留原有许可证。

## AI 制作与维护声明

DeepReader 的新增功能与项目文档主要由 AI 制作。项目日常开发和维护托管给 AI，管理者会不定期审查。本项目基于 SumatraPDF 等上游开源项目，上游作者的署名与许可证均予以保留。

## 功能

- 在同一阅读器窗口中解释单词、短语或句子，按原生文字位置提取语境，不使用剪贴板取词。
- 中英文界面和 AI 回答切换。
- 拖动侧栏左侧边界调整宽度；点击“悬浮”后可拖动标题栏移动、拖动边框缩放，再点击“停靠”回到阅读器。切换保留当前内容，宽度、悬浮状态和悬浮窗口大小自动记住。
- 解释区下方支持连续追问：输入问题后点击“发送”或按 Ctrl + Enter，沿用当前选文、语境和对话，并保存到同一条历史。
- 查询与总结成功后自动保存，可搜索、查看语境、导出和删除。
- 默认直连 DeepSeek 官方 API；可选 OpenRouter 免费路由及 GPT、Claude、Gemini、Qwen、Kimi 等模型，也支持 Gemini 官方 API。
- 当前文件全文总结，以及基于已保存查询和文件总结的日、周、月复习总结。
- 总结页直接显示累计与本范围的成功查询次数、不同词句、重复查询、涉及文件及活跃日期；统计无需 API。
- 选文与解释初始各占一半，可拖动分隔条并记住比例；“高亮 / 取消高亮”生成 PDF 批注，点击“保存批注”写入文件。

## 快速开始

1. 从 [v1.0.0 发布页](https://github.com/BaoshiSun/DeepReader/releases/tag/v1.0.0)下载 `DeepReader-v1.0.0-win64.zip`，完整解压到可写文件夹。
2. 运行其中的 `DeepReader.exe`；右侧栏默认展开，简短引导仅在新配置首次启动时显示。之后可从“设置 → 查看使用引导”重新打开。
3. 点击“配置 API”或“设置”，完成下方的 DeepSeek API 配置，再打开具有文字层的 PDF。
4. 拖选文字，按 **Ctrl + Alt + D**。使用“English / 中文”切换语言，使用“收起”恢复阅读区域。

从本源码构建的 **1.1.0** 还支持可调宽度与悬浮窗口；目前公开的 **1.0.0** 下载包不包含这两项新增功能。悬浮窗口随阅读器最小化、退出；点击浮窗的关闭按钮只收起侧栏，可从“查看 → AI 阅读侧栏”重新打开。

运行原生阅读器不需要 Python、.NET 或外部悬浮助手。扫描 PDF 需要先 OCR；已经做过的高亮批注需要重新拖选文字。

为避免 UnRAR 的用途限制与 GPL 组合，本版使用开源 unarr，移除了 UnRAR 备用解压路径；部分 RAR / CBR 漫画可能不受支持。PDF 阅读和 AI 功能不受影响。

## 默认 DeepSeek 怎么配置

**新配置默认使用 DeepSeek 官方 API → deepseek-flash，直接连接 api.deepseek.com，无需 OpenRouter 账号。** DeepSeek API 需要使用者自己的 Key，并按官方价格计费；这不是免注册或永久免费服务。

1. 在阅读器“设置”中保持服务 **DeepSeek**、模型 **deepseek-flash**。
2. 点击“打开服务的密钥 / 模型页面”，或访问 [DeepSeek 密钥页面](https://platform.deepseek.com/api_keys)。
3. 注册或登录 DeepSeek 开放平台，创建一个 API Key；将它粘贴到阅读器的密钥输入框，点击“保存设置”。确保 API 账户有可用余额或赠送额度。
4. 返回文章选中文字即可使用。密钥不要发到 Issue、截图或公开聊天中。

DeepSeek API 按输入与输出用量计费，具体以 [官方价格说明](https://api-docs.deepseek.com/quick_start/pricing/) 为准。发布包没有预置 Key；之前已保存的服务选择会继续使用，不会因升级被强制切换。

如需免费云端模型，可手动改选 **OpenRouter → openrouter/free**，并填写自己的 OpenRouter Key。免费路由受平台额度、地区和模型可用性限制；该模式将最高输入、输出和单次请求价格限制为零，失败时停止，不自动改用收费模型。[免费路由官方说明](https://openrouter.ai/docs/guides/routing/routers/free-router)

每个服务使用独立密钥。其他服务的配置入口及模型说明见 [完整使用说明](native/README.md)。

## 总结与保存

“总结”页面选择范围后，先点击“准备材料”查看页数、记录数及预计请求数，再点击“生成总结”。文件总结读取全部页面文字，长文分段后合并；日、周、月总结使用对应时间范围内已保存的查询与文件总结，当前版本手动生成。周从周一开始。

成功结果保存在本机 `AIHistory/`。原文片段、回答及文档路径是个人阅读资料；错误和不完整回答不会作为成功记录保存。保存目录、长文限制与导出方法见 [原生版说明](native/README.md)。

## 隐私

解释会向所选服务发送选文及附近语境；追问还会发送当前对话与新问题；文件总结发送提取的全文文字；周期总结发送选中的历史记录。不会上传 PDF 二进制，程序不主动发送本地目录路径。AI 回答可能出错，应结合原文核对。

API Key 使用 Windows 当前账户加密。公开源码和生成的 ZIP 排除密钥配置、阅读历史和个人打开文件记录；构建脚本不会复制旧 Key。请不要直接分发自己使用过的运行目录。详见 [密钥与隐私说明](SECURITY.md)。

## 从源码构建

环境：Windows x64、Python 3.10+、网络连接；原生窗口测试使用系统 .NET Framework 4.8 和 PyMuPDF。工具链与上游源码下载到当前目录，按锁定 SHA-256 校验。

```powershell
./native/build-native.ps1 -Prepare
python -m pip install -r requirements-build.txt
./native/test-core.ps1
./native/test-native.ps1
python -m unittest discover -s tests -p test_release.py -v
python tools/public_release.py --source-zip
python native/package-native.py
```

可在 PowerShell 脚本中用 `-Python 'C:\path\python.exe'` 指定 Python。构建结果位于 `build/native/sumatrapdf-3.6.1rel/out/rel64/SumatraPDF.exe`。通常只修改 `native/`，由 `apply-native.py` 应用到固定版本上游；不要直接修改生成目录。

- `native/`：原生侧栏、API、历史与总结、上游补丁、构建和原生测试。
- `tools/public_release.py`：公开文件清单、秘密检查和源码打包。
- `src/`、根目录 `build.ps1`：保留的旧版外部助手源码；见 [旧版说明](docs/legacy-helper.md)。
- [参与开发](CONTRIBUTING.md) · [发布步骤](docs/RELEASING.md) · [第三方组件](THIRD-PARTY-NOTICES.md)
- [许可核对](docs/LICENSE-REVIEW.md) · [修改及日期声明](docs/MODIFICATIONS.md)。请分发包含完整对应源码的 win64 ZIP；“帮助 → 关于 DeepReader”也提供许可与源码位置。

默认测试不调用在线 API，也不需要真实密钥。GitHub Actions 检查公开源码与打包边界；完整 C++ 编译和窗口测试按上述命令在 Windows 执行。

## English

DeepReader's added features and project documentation are primarily created by AI. Day-to-day development and maintenance are delegated to AI, with occasional review by the project maintainer. DeepReader builds on upstream open-source projects such as SumatraPDF, whose authorship and licenses are preserved.

An independent Windows x64 build of SumatraPDF with a native, collapsible AI sidebar. Select text and press **Ctrl + Alt + D** for a concise contextual explanation. Supports Chinese / English, saved lookups, multiple providers, full-document summaries, and daily / weekly / monthly reviews based on saved records.

The 1.1.0 source adds a resizable sidebar and Float / Dock switching. Drag the sidebar's left edge to change its width, or move and resize its floating window using the title bar and borders. Current content and drafts survive switching; mode and sizes are saved. The floating window follows its reader when minimized or closed. Closing the floating window hides the panel; reopen it from View → AI reader sidebar. These additions are not yet included in the public 1.0.0 release.

After an explanation, use the follow-up field and Send or Ctrl + Enter to ask another question; Enter inserts a line break. Each question carries the selected passage, nearby context and the current conversation. Successful turns are appended to the original history record. Failed or canceled requests keep your question and prior answers. New selections and document changes reset the conversation.

Extract the portable ZIP and run `DeepReader.exe`. The sidebar opens automatically. New profiles see a short guide once; reopen it from Settings when needed. The selection and explanation panes initially share the space equally; drag the divider to resize them. Summary shows local reading statistics without an API key. Highlight / Unhighlight creates PDF annotations; Save PDF writes them to the document. New profiles default to the official DeepSeek API with `deepseek-flash`, using your own DeepSeek key and API balance. No OpenRouter account is needed for this route. Existing provider preferences are preserved. OpenRouter free routing remains optional and requires its own key; its zero-price limit and no-paid-fallback protection still apply. No shared key, anonymous cloud endpoint, or local model is bundled. Select English in the sidebar to switch the reader UI and future AI responses.

All new code is AGPL-3.0-or-later. The portable release includes corresponding upstream source, licenses, and build instructions. This is not an official SumatraPDF release.
