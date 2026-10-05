# 密钥与隐私 / Security and privacy

发布包不附带 API Key。新配置默认 DeepSeek 官方 API，使用者需要自己的 DeepSeek Key 与 API 余额或赠送额度，按量计费。可选免费模型同样需要账号，额度以服务商为准。

- 原生阅读器用 Windows DPAPI 加密保存各服务的密钥，文件为 `AIReader.json`。旧版配置还可能是 `DeepSeek.json` 或 `config.json`。密文也不应提交到 GitHub。
- `AIHistory/` 包含原文片段、AI 回答、日期和本地文档路径，以明文保存在电脑上。备份时按个人阅读资料对待。
- `SumatraPDF-settings.txt` 可能包含近期打开的文件。不要直接上传整个运行目录；发布脚本会用干净的默认设置替代它。
- 解释发送选文及附近上下文，追问还会发送本次对话与新问题，单文件总结发送提取的全文文字，周期总结发送相应历史记录。默认请求直接发往 DeepSeek。手动选择其他服务时，请求发往该服务；选择 OpenRouter 时由其继续转发给对应供应商。
- 本程序固定 HTTPS 服务地址，禁止带密钥跟随重定向。可选 OpenRouter 免费模式限制最高价格为零，失败时不会自动改用付费模型。

清除密钥前请先关闭阅读器。将 `AIReader.json` 中 `Keys` 的所有值设为空字符串，并清空旧 `DeepSeek.json` / `config.json` 的 `ProtectedKey` 值；保留其他字段和 `AIHistory/`。删除本地值不等于在服务商后台撤销 Key；如果曾公开过密钥，应在服务商后台撤销并重新生成。

向项目报告问题时，不要在 Issue、日志或截图中附带 API Key、配置密文或私人 PDF。优先提供合成短文和去掉个人路径的复现步骤。发现漏洞时请使用仓库提供的私密漏洞报告入口（若已启用），不要公开可利用的密钥或用户内容。

The public source and release ZIP contain no preconfigured API credentials or reading history. API keys are encrypted for the current Windows user, but encrypted configuration is still private data. Local removal does not revoke the provider-side key. Never attach private PDFs, keys, or profile files to public issues.
