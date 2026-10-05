using System;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;

namespace SumatraDeepSeek {
    public static class Integration {
        public const string Name = "DeepSeek AI Explain";
        public const string Shortcut = "Ctrl + Alt + D";
        public static string DefaultSettings {
            get { return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "SumatraPDF", "SumatraPDF-settings.txt"); }
        }
        // Sumatra's brackets are structural only on their own line or after a section name.
        // Paths/strings can contain brackets and must never be counted as structure.
        static int SectionEnd(string[] lines, int start) {
            int depth = 1;
            for (int i = start + 1; i < lines.Length; i++) {
                string line = lines[i].Trim();
                if (line == "[" || Regex.IsMatch(line, @"^[A-Za-z][A-Za-z0-9]*\s*\[$")) depth++;
                else if (line == "]") { depth--; if (depth == 0) return i; }
            }
            throw new UserError("SumatraPDF 设置的括号不完整，请先修复设置文件。");
        }
        static string NormalizeKey(string key) { return Regex.Replace(key.ToLowerInvariant(), @"\s|\+|-", ""); }
        public static string Patch(string text, string exe, bool remove) {
            if (exe.IndexOfAny(new char[] {'\r','\n','"'}) >= 0) throw new UserError("插件路径包含不支持的字符。");
            string newline = text.Contains("\r\n") ? "\r\n" : "\n";
            string[] lines = text.Replace("\r\n", "\n").Split('\n');
            int start = -1;
            for (int i = 0; i < lines.Length; i++) {
                if (Regex.IsMatch(lines[i].Trim(), @"^ExternalViewers\s*\[$")) {
                    if (start >= 0) throw new UserError("设置包含重复 ExternalViewers 区块，请先合并它们。");
                    start = i;
                }
            }
            int end = start < 0 ? -1 : SectionEnd(lines, start);
            var kept = new System.Collections.Generic.List<string>();
            if (start >= 0) {
                for (int i = start + 1; i < end; i++) {
                    if (lines[i].Trim() == "[") {
                        int blockEnd = SectionEnd(lines, i);
                        string block = String.Join("\n", lines, i, blockEnd - i + 1);
                        bool ours = Regex.IsMatch(block, @"(?m)^\s*Name\s*=\s*" + Regex.Escape(Name) + @"\s*$");
                        if (!ours) for (int j = i; j <= blockEnd; j++) kept.Add(lines[j]);
                        i = blockEnd;
                    } else kept.Add(lines[i]);
                }
            }
            if (!remove) {
                // Check the whole file after removing our previous entry for key collisions.
                string remaining = start < 0 ? text : String.Join("\n", lines, 0, start + 1)
                    + "\n" + String.Join("\n", kept) + "\n" + String.Join("\n", lines, end, lines.Length - end);
                foreach (Match match in Regex.Matches(remaining, @"(?m)^\s*Key\s*=\s*([^\r\n]+)")) {
                    if (NormalizeKey(match.Groups[1].Value) == NormalizeKey(Shortcut))
                        throw new UserError("Ctrl + Alt + D 已用于其他命令。请先在 SumatraPDF 设置中更改冲突的快捷键。");
                }
                kept.Add("\t[");
                kept.Add("\t\tCommandLine = \"" + exe + "\" --file \"%1\" --page %p");
                kept.Add("\t\tName = " + Name);
                kept.Add("\t\tFilter = *.pdf");
                kept.Add("\t\tKey = " + Shortcut);
                kept.Add("\t]");
            }
            if (start < 0) {
                if (remove) return text;
                return text.TrimEnd('\r','\n') + newline + newline + "ExternalViewers [" + newline
                    + String.Join(newline, kept) + newline + "]" + newline;
            }
            string before = String.Join(newline, lines, 0, start + 1);
            string after = String.Join(newline, lines, end, lines.Length - end);
            return before + newline + (kept.Count == 0 ? "" : String.Join(newline, kept) + newline) + after;
        }
        public static string Apply(string settings, bool remove) {
            foreach (Process proc in Process.GetProcesses()) {
                using (proc) {
                    if (proc.ProcessName.StartsWith("SumatraPDF", StringComparison.OrdinalIgnoreCase))
                        throw new UserError("请先关闭所有 SumatraPDF 窗口，再接入或移除插件，以免设置被覆盖。");
                }
            }
            if (!File.Exists(settings)) throw new UserError("找不到 SumatraPDF 设置文件。请先打开并关闭一次 SumatraPDF，或选择便携版的设置文件。");
            string exe = System.Reflection.Assembly.GetExecutingAssembly().Location;
            byte[] original = File.ReadAllBytes(settings);
            string text = Encoding.UTF8.GetString(original).TrimStart('\uFEFF');
            string patched = Patch(text, exe, remove);
            if (patched == text) return "设置无需更改。";
            string backup = settings + ".backup-" + DateTime.Now.ToString("yyyyMMdd-HHmmss-fff");
            File.WriteAllBytes(backup, original);
            string temp = settings + ".deepseek.tmp";
            File.WriteAllText(temp, patched, new UTF8Encoding(original.Length >= 3 && original[0] == 0xef));
            File.Replace(temp, settings, null);
            return (remove ? "已移除插件接入。" : "已接入。重新打开 SumatraPDF，选中文字后按 Ctrl + Alt + D。")
                + "\r\n原设置备份：" + backup;
        }
    }
}
