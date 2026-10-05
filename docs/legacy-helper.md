# 旧版外部助手（1.x）

此目录说明仅适用于保留的旧版源码。当前发布使用原生侧栏，请先阅读仓库根目录 README。

Windows 上的 SumatraPDF 外部工具扩展。选中 PDF 中的词语或句子，按 **Ctrl + Alt + D**，弹窗会结合附近段落用中文简短解释。按 **Esc** 关闭弹窗，继续阅读。

## 开始使用

1. 将发布包完整解压到一个固定、可写的文件夹，保留所有文件及 `context-worker` 子文件夹。
2. 双击 `DeepSeekReader.exe`，在设置窗口填写你的 **DeepSeek API Key**，点击“保存设置”。可通过窗口内的“获取 API Key”按钮前往官方平台。不要把密钥发到聊天中。
3. 关闭所有 SumatraPDF 窗口，点击“接入 SumatraPDF”。程序会备份原设置，再添加外部工具和快捷键。便携版请先选择与 SumatraPDF 同目录的 `SumatraPDF-settings.txt`。
4. 重新打开 SumatraPDF，打开一份有文字层的 PDF，拖动鼠标选中单词或句子，然后松开 **Ctrl + Alt + D**。
5. 如果只有一个匹配语境，会自动解释；如果选文出现于多个段落，请从下拉框选择正确段落并点击“解释”。“查看 / 补充上下文”可以检查或粘贴附近段落。

“划线”在这里指拖动鼠标选中文字；已有的高亮批注需要重新选中文字后触发快捷键。此版本面向 PDF，支持 SumatraPDF **3.6+**。Windows 10/11 的 .NET Framework 4.8 可运行主程序，发布包无需安装 Python、AutoHotkey 或其他插件运行环境。

## 解释方式

- 单词、短语：解释当前语境最贴切的含义，必要时说明语气或搭配。
- 句子：自然说明作者的实际意思，仅在必要时解释语法。
- 专业概念：用简短、易懂的话说明其在文章中的作用。
- 提示词要求通常 1～3 个短句，简单词可更短；实际内容由模型生成。

上下文从本地 PDF 的当前页提取，支持常见连字、换行断词、跨段落和跨页选句。只在当前页无法定位时查找前后相邻页。重复词语会提供段落选择。连续或双页浏览时，同一选词也可能出现在当前页和旁页，遇到歧义可改选完整句子，或手动检查上下文。只选择一个很常见的词时，选择完整短语通常更准确。

## 密钥、网络及文件

API Key 使用 Windows DPAPI 加密，写入程序旁的 `config.json`，仅当前 Windows 账户可以解密；也支持读取 `DEEPSEEK_API_KEY` 环境变量，已保存密钥优先。文件夹移动到其他账户或电脑后应重新设置密钥。

每次解释会通过 HTTPS 发送**选中文字及最多约 3000 字符的附近上下文**到 `https://api.deepseek.com/chat/completions`。本工具不上传整份 PDF、不发送文件路径、不保存阅读历史或解释结果；API 服务本身的数据处理以 DeepSeek 政策为准。DeepSeek API 使用独立 API 余额。

默认模型为官方当前文档所列的 `deepseek-flash`，关闭思考模式，限制回答长度。模型可在设置中修改为 DeepSeek API 支持的型号。

快捷键通过 SumatraPDF `ExternalViewers` 的 `Key` 字段接入；主程序向当前阅读窗口发送原生 `CmdCopySelection` 命令，完成复制后读取选文并尝试恢复原剪贴板的格式。v1.0.1 修复了“手动 Ctrl+C 正常，但快捷键提示没有读取到所选文字”的问题：不再模拟 Ctrl+C，也不再先清空剪贴板后阻塞等待。复制失败时不会使用旧剪贴板内容；恢复前会检查剪贴板是否又被更改。

## 常见问题

- **没有解释窗口**：完整解压后重新接入；快捷键仅在 SumatraPDF 的 PDF 文档中有效。若 `Ctrl + Alt + D` 被其他命令占用，接入会提示冲突。
- **没有选文**：请拖选可复制的正文；扫描版 PDF 需要先做 OCR。SumatraPDF 与插件应以相同权限运行。
- **上下文无法定位**：公式、复杂双栏、特殊字体、扫描件可能无法提取。弹窗会提示粘贴附近段落，不会自动编造上下文。
- **密码 PDF**：请先保存一份可直接读取的已解密副本。
- **密钥无效、余额不足、限流或网络超时**：窗口会给出对应提示，可修改设置后重试。
- **移动文件夹后快捷键失效**：关闭 SumatraPDF，在新位置运行主程序并重新接入。
- **移除插件**：关闭 SumatraPDF，打开主程序设置，点击“移除接入”。移除后可删除插件文件夹；其中 `config.json` 也会随之删除。

## 从源代码构建及验证

需要 Windows x64、Python 3.10+ 和 .NET Framework 4.8。在 PowerShell 中运行：

```powershell
./build.ps1
```

脚本会从官方 PyPI 下载固定版本的构建组件，校验 SHA-256 并解压到项目内 `build/packages`，执行真实 PDF 上下文测试，再生成 `dist/SumatraDeepSeek/DeepSeekReader.exe` 及上下文组件，最后执行离线 API 合约、DPAPI 和 Sumatra 设置修改测试。构建不改变系统 Python 安装；测试不请求真实 DeepSeek 服务、不消耗 API 余额。

取词回归测试可运行 `./tests/test-selection.ps1`。它会使用已安装的 SumatraPDF 启动独立隐藏测试实例，打开生成的测试 PDF，验证单词、短语、整段文字、无选区及剪贴板恢复。测试使用项目内独立设置，不操作用户当前打开的 PDF，不调用 AI。

命令行接入和移除（均需先关闭 SumatraPDF）：

```powershell
./DeepSeekReader.exe --install "$env:LOCALAPPDATA\SumatraPDF\SumatraPDF-settings.txt"
./DeepSeekReader.exe --uninstall "$env:LOCALAPPDATA\SumatraPDF\SumatraPDF-settings.txt"
```

完整安装片段如下，由程序自动合并到原 `ExternalViewers` 区块。不要创建重复区块：

```text
ExternalViewers [
    [
        CommandLine = "C:\固定插件目录\DeepSeekReader.exe" --file "%1" --page %p
        Name = DeepSeek AI Explain
        Filter = *.pdf
        Key = Ctrl + Alt + D
    ]
]
```

官方参考：[SumatraPDF 外部工具接口](https://www.sumatrapdfreader.org/docs/Customize-external-viewers)、[DeepSeek API](https://api-docs.deepseek.com/)、[PyMuPDF 文本提取](https://pymupdf.readthedocs.io/en/latest/recipes-text.html)。

项目及所分发程序采用 **AGPL-3.0-or-later**，完整源代码随包提供；第三方授权见 `THIRD-PARTY-NOTICES.md`。程序尚需用户填写真实密钥后验证账户、网络环境和模型的实际解释质量。
