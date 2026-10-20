# DeepReader · AI 阅读器

**iPhone / iPad：** [`iOS 工程`](ios/README.md)现已统一为内置 Qwen3 0.6B 的离线阅读器，支持 iOS 17+。阅读和 AI 问答免费，无广告、API Key、订阅或问答次数配额。答案可能不准确，请核对原文。上架进度见[提交记录](docs/app-store/ios-readiness.md)。

基于 **SumatraPDF 3.6.1rel** 的 Windows x64 原生定制版，提供可调宽度、可收起或悬浮的 AI 侧栏。选中词句、按 **Ctrl + Alt + D**，即可结合附近上下文获得简短解释。

项目地址：[BaoshiSun/DeepReader](https://github.com/BaoshiSun/DeepReader)。**1.0.0 是首个公开发行版本。**

这是独立开源项目，不是 SumatraPDF 官方发布。当前版本 **1.2.0**；[下载 Windows 便携版](https://github.com/BaoshiSun/DeepReader/releases/tag/v1.2.0)。代码采用 **AGPL-3.0-or-later**，上游组件保留原有许可证。

**macOS 1.3.2 直接下载版**：[下载 Mac 安装包（DMG / ZIP）](https://github.com/BaoshiSun/DeepReader/releases/tag/v1.3.2-macos)。macOS 13+，支持 Apple Silicon 与 Intel，保留多服务商 API、回答依据切换、追问、总结，以及可记住／撤销的发送授权。此下载版使用用户自己的 API Key；详情见 [Mac 版说明](macos/README.md)。

**Mac App Store 版**：1.3.1（9）已提交审核，内置 Qwen3 0.6B，免费离线、无广告、API Key、内购或次数限制，需要 macOS 13.3+。包含可调／悬浮助手；小模型答案可能不准确。它与上面的 GitHub 多服务商安装包是不同构建，审核状态见[提交记录](docs/app-store/readiness.md)。

## 多服务商与回答依据

### 回答依据切换

iOS/iPadOS、macOS、Windows 原生侧栏和旧版 Windows 助手均可在阅读助手内选择“回答依据”：

- **仅书中内容**（默认）：要求 AI 仅依据本次提供的选文、附近语境或总结材料作答，材料不足时明确说明；不表示每次解释都读取整本书。
- **结合通用知识**：允许使用模型已有知识补充背景、概念和例子，并要求区分原文依据与通用知识，不能把补充内容归于作者。总结仍忠实于原文，额外背景单独说明。

选择保存在本机，应用于之后的解释、追问和总结；切换不会自动发送请求或重新生成已有回答。通用知识**不是联网搜索**，不保证最新或正确。这是对模型的指令约束，不能保证模型绝不引入书外内容。未创建新 API Key，未加入搜索服务；各下载包包含的功能以对应 Release 的源码提交为准，源码更新不会自动替换已安装应用。

追问修正：切到通用知识后，要求模型重新判断问题，避免沿用上一次“原文未说明”的答复。量化问题可补充计算方法、条件和明确标注的假设算例；不能编造书中设备的实测值或通用范围。Windows 新追问的回答标题记录该次请求的实际模式，旧记录保留原样。此修正仍需重新构建下载包才能供已安装版本使用；离线测试验证请求与模式传递，不代表实测模型一定遵循指令。

以下多服务商说明适用于 GitHub macOS 直接下载版、Windows 原生阅读器和旧版 Windows 助手；当前 iOS 和 Mac App Store 版仅使用内置离线 Qwen。桌面源码提供的服务选择：DeepSeek、OpenAI、Claude、Gemini、Qwen、Kimi、GLM、Doubao、MiniMax、Grok、Mistral、OpenRouter，以及自定义 OpenAI 兼容接口。支持阅读所需的**文字对话**，不表示支持图像生成、视频、语音、工具调用，或每家所有专用 API。

在设置中选择服务商 → 选择或填写模型 ID → 核对完整 HTTPS 接口地址 → 填入该服务的 Key → 保存。豆包须填写账户可用的模型 / 推理接入点 ID；自定义接口也须填写模型 ID。模型预设只是起点，可输入新 ID，实际可用性由服务商、账户权限和地区决定。OpenRouter 可接入其提供的其他模型，例如 Llama；DeepReader 不会自动切换服务商或付费线路。

Qwen 默认地址属于美国 Virginia 地区，GLM 使用 Z.AI 国际接口，Kimi 和 MiniMax 使用国际接口。需要其他地区时，在服务商控制台复制**完整请求地址**并使用同地区的 Key。地址应包含 `/chat/completions`，Claude 原生接口包含 `/messages`；不要只填域名或 `/v1`，也不要在地址中放 Key。仅支持 HTTPS，不跟随重定向；不支持 Azure / Bedrock 等需要其他认证协议的接口，也不支持直接连接 HTTP localhost。

Apple 版本使用钥匙串并按服务商和完整地址隔离 Key；已有官方 DeepSeek Key 继续可用。Windows 使用当前用户 DPAPI 加密；原生版修改地址会清除该服务原地址的 Key 槽，必须重新填写，旧助手则保留分别绑定各地址的加密 Key。模型、接口地址和非敏感偏好保存在本机配置。聊天产品订阅不等同于 API 额度。

Windows 在首次向某接收方发送时请求授权，可在设置中撤销；macOS 新版也可选择“同意并记住”，并在设置中撤销；旧版仍按操作确认。提示显示实际接口和内容范围；OpenRouter 还会转发给模型供应商。Gemini 和 OpenRouter 有 18 岁要求，开发版加入年龄确认。重新上架前仍需复核整体受众、年龄分级、各服务条款、可用地区和隐私标签，年龄确认本身不代表已满足全部条款。

以下为 2026-10-12 的历史验证记录，后续 iOS 已改为免费离线 Qwen（见上方链接）。当时只进行离线开发和测试，不创建 Key、不调用真实模型。已送审的 macOS 1.2.1 (5) 和 iOS 1.0.0 (1) 仍是原来的 DeepSeek 首发构建；开发源码改动不会自动上传或替换它们。Windows CI 已通过原生 AI 面板编译和核心回归测试，以及旧版助手的编译与离线测试；完整安装包和人工界面回归仍需在发布前验证。

离线验证：macOS 30 项、iOS 模拟器 21 项（包括新增的同服务商切换接口隔离测试）通过；Windows 原生核心 121 项、旧助手 67 项通过。Python 共 31 项，其中 3 项仅适用于 Windows 成品包的测试跳过。已在 iPad 模拟器检查服务商菜单及 OpenAI 切换后的模型、接口和空 Key 状态。真实模型账户、配额、区域权限及完整 Windows GUI 尚未验证。参见 [Windows 验证记录](https://github.com/BaoshiSun/DeepReader/actions/runs/38213582902)。

接口依据：[OpenAI Chat Completions](https://developers.openai.com/api/reference/resources/chat/subresources/completions/methods/create)、[Claude Messages](https://platform.claude.com/docs/en/api/overview)、[Gemini 兼容接口](https://ai.google.dev/gemini-api/docs/openai)、[Qwen 兼容接口](https://www.alibabacloud.com/help/en/model-studio/compatibility-of-openai-with-dashscope)、[Kimi](https://platform.kimi.ai/docs/guide/use-thinking-models)、[GLM](https://docs.z.ai/guides/llm/glm-4.7)、[Doubao](https://docs.volcengine.com/docs/ark/chat-api?lang=zh)、[MiniMax](https://platform.minimax.io/docs/api-reference/text-openai-api)、[Grok](https://docs.x.ai/developers/model-capabilities/legacy/chat-completions)、[Mistral](https://docs.mistral.ai/api)。


## AI 制作与维护声明

DeepReader 的新增功能与项目文档主要由 AI 制作。项目日常开发和维护托管给 AI，管理者会不定期审查。本项目基于 SumatraPDF 等上游开源项目，上游作者的署名与许可证均予以保留。

## 功能

- 在同一阅读器窗口中解释单词、短语或句子，按原生文字位置提取语境，不使用剪贴板取词。
- 中英文界面和 AI 回答切换。
- 当前 PDF 可评 1–5 星、标记“阅读中 / 读完”；按星级复制归档到指定目录，保留原文件。
- 书单汇总在读、读完本数和平均评分，可搜索、筛选、继续打开、查看已保存的全文总结并导出。
- 拖动侧栏左侧边界调整宽度；点击“悬浮”后可拖动标题栏移动、拖动边框缩放，再点击“停靠”回到阅读器。切换保留当前内容，宽度、悬浮状态和悬浮窗口大小自动记住。
- 解释区下方支持连续追问：输入问题后点击“发送”或按 Ctrl + Enter，沿用当前选文、语境和对话，并保存到同一条历史。
- 查询与总结成功后自动保存，可搜索、查看语境、导出和删除。
- 默认直连 DeepSeek 官方 API；可选 OpenRouter 免费路由及 GPT、Claude、Gemini、Qwen、Kimi 等模型，也支持 Gemini 官方 API。
- 当前文件全文总结，以及基于已保存查询和文件总结的日、周、月复习总结。
- 总结页直接显示累计与本范围的成功查询次数、不同词句、重复查询、涉及文件及活跃日期；统计无需 API。
- 选文与解释初始各占一半，可拖动分隔条并记住比例；“高亮 / 取消高亮”生成 PDF 批注，点击“保存批注”写入文件。

## 快速开始

1. 从 [v1.2.0 发布页](https://github.com/BaoshiSun/DeepReader/releases/tag/v1.2.0)下载 `DeepReader-v1.2.0-win64.zip`，完整解压到可写文件夹。
2. 运行其中的 `DeepReader.exe`；右侧栏默认展开，简短引导仅在新配置首次启动时显示。之后可从“设置 → 查看使用引导”重新打开。
3. 点击“配置 API”或“设置”，完成下方的 DeepSeek API 配置，再打开具有文字层的 PDF。
4. 拖选文字，按 **Ctrl + Alt + D**。使用“English / 中文”切换语言，使用“收起”恢复阅读区域。

**1.2.0 新增**星级评分、阅读状态、按评分归档和书单。1.1.0 提供的侧栏宽度调整、悬浮窗口和细分隔条继续保留；点击浮窗的关闭按钮只收起侧栏，可从“查看 → AI 阅读侧栏”重新打开。

从 1.0.0 / 1.1.0 升级：关闭阅读器，将新版便携包完整解压到原文件夹并覆盖程序、说明和源码文件。已有 `AIReader.json`、`AIHistory/`、`BookLibrary/` 等个人文件请保留；如果提示覆盖 `SumatraPDF-settings.txt`，选择保留原文件，以保留阅读器偏好。也可先解压到新文件夹试用。

运行原生阅读器不需要 Python、.NET 或外部悬浮助手。扫描 PDF 需要先 OCR；已经做过的高亮批注需要重新拖选文字。

为避免 UnRAR 的用途限制与 GPL 组合，本版使用开源 unarr，移除了 UnRAR 备用解压路径；部分 RAR / CBR 漫画可能不受支持。PDF 阅读和 AI 功能不受影响。

## 1.2.0：评分、归档与书单

侧栏上方点选星级，选择“阅读中 / 读完”。点击“归档”，首次选择目标文件夹后，程序按评分将 PDF 复制到 `1星` 至 `5星` 子文件夹，保留原文件。同名不同内容自动加编号，不覆盖已有副本。含未保存批注时，先点击“保存批注”。归档目录可在设置中更改。

“书单”页集中显示 PDF 的评分、状态、完成日期、已保存全文总结及阅读数量；支持筛选、搜索、打开和导出。书单与归档无需 API。书单会收录新打开的 PDF 和旧查询历史中的 PDF；是否读完由用户标记。信息保存在本地 `BookLibrary/`，升级时请和 `AIHistory/` 一并保留。详见 [评分、归档与书单说明](native/README.md#评分阅读状态与归档)。

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

Version 1.2.0 adds 1–5 star PDF ratings, Reading / Finished status with completion dates, archive copies organized into rating folders, and a searchable reading list with local totals, saved document summaries and export. Archive copies preserve the original PDF and existing destination files. These features work without an API key. [Download 1.2.0](https://github.com/BaoshiSun/DeepReader/releases/tag/v1.2.0).

The resizable sidebar and Float / Dock switching introduced in 1.1.0 remain available. Drag the sidebar's left edge to change its width, or move and resize its floating window using the title bar and borders. Current content and drafts survive switching; mode and sizes are saved. The floating window follows its reader when minimized or closed. Closing the floating window hides the panel; reopen it from View → AI reader sidebar.

After an explanation, use the follow-up field and Send or Ctrl + Enter to ask another question; Enter inserts a line break. Each question carries the selected passage, nearby context and the current conversation. Successful turns are appended to the original history record. Failed or canceled requests keep your question and prior answers. New selections and document changes reset the conversation.

Extract the portable ZIP and run `DeepReader.exe`. The sidebar opens automatically. New profiles see a short guide once; reopen it from Settings when needed. The selection and explanation panes initially share the space equally; drag the divider to resize them. Summary shows local reading statistics without an API key. Highlight / Unhighlight creates PDF annotations; Save PDF writes them to the document. New profiles default to the official DeepSeek API with `deepseek-flash`, using your own DeepSeek key and API balance. No OpenRouter account is needed for this route. Existing provider preferences are preserved. OpenRouter free routing remains optional and requires its own key; its zero-price limit and no-paid-fallback protection still apply. No shared key, anonymous cloud endpoint, or local model is bundled. Select English in the sidebar to switch the reader UI and future AI responses.

All new code is AGPL-3.0-or-later. The portable release includes corresponding upstream source, licenses, and build instructions. This is not an official SumatraPDF release.
