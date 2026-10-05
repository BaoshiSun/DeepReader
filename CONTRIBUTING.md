# 参与开发

当前维护入口是 `native/` 的原生 SumatraPDF 侧栏。`src/` 和旧构建脚本保留了 1.x 外部助手；原生窗口测试也复用了其中的 DDE 测试支持。

1. 阅读根目录 README 和 `native/README.md`，按锁定的源码与工具链构建。
2. 编辑 `native/` 中的文件；不要直接修改 `build/native/` 的生成源码。上游集成修改写在 `native/apply-native.py`。
3. 原生行为修改运行 `native/test-core.ps1` 和 `native/test-native.ps1`；发布脚本修改运行 `python -m unittest discover -s tests -p test_release.py -v`。
4. 提交前运行 `python tools/public_release.py`。新增公开文件需加入该脚本的明确文件清单。

默认测试使用合成文本，不需要在线 API。不要把个人密钥加到自动化测试、源码、Issue 或 PR；在线测试是显式可选项。自动化源码检查不能替代人工复核，也不证明任意文件夹可以直接公开。

提交内容按 AGPL-3.0-or-later 提供，现有第三方组件保留其原有许可。请说明触发问题的操作、修改后的行为和验证结果。
