using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

namespace SumatraDeepSeek {
    public static class Selection {
        [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
        [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
        [DllImport("user32.dll")] static extern uint GetClipboardSequenceNumber();
        [DllImport("user32.dll")] static extern IntPtr GetClipboardOwner();
        [DllImport("user32.dll")] static extern bool OpenClipboard(IntPtr window);
        [DllImport("user32.dll")] static extern bool CloseClipboard();
        [DllImport("user32.dll")] static extern IntPtr GetClipboardData(uint format);
        [DllImport("kernel32.dll")] static extern IntPtr GlobalLock(IntPtr memory);
        [DllImport("kernel32.dll")] static extern bool GlobalUnlock(IntPtr memory);
        [DllImport("kernel32.dll")] static extern UIntPtr GlobalSize(IntPtr memory);
        [DllImport("user32.dll", EntryPoint="SendMessageTimeoutW", SetLastError=true)]
        static extern IntPtr SendMessageTimeout(IntPtr window, uint message, IntPtr sender,
            ref COPYDATA data, uint flags, uint timeout, out UIntPtr result);
        [StructLayout(LayoutKind.Sequential)] struct COPYDATA {
            public IntPtr kind;
            public int length;
            public IntPtr data;
        }

        // Sumatra's own DDE transport uses WM_COPYDATA / DdeW for named commands.
        // Target this reader window without injecting keyboard input or choosing
        // whichever instance a global DDE connection happens to find first.
        internal static bool ExecuteCommand(IntPtr window, string command) {
            IntPtr text = Marshal.StringToHGlobalUni(command);
            try {
                var data = new COPYDATA { kind = new IntPtr(0x44646557),
                    length = (command.Length + 1) * 2, data = text };
                UIntPtr result;
                // SMTO_ABORTIFHUNG, deliberately without SMTO_BLOCK: incoming
                // clipboard/OLE messages must be dispatched while Sumatra copies.
                return SendMessageTimeout(window,0x4a,IntPtr.Zero,ref data,2,4000,out result) != IntPtr.Zero
                    && result.ToUInt64() != 0;
            } finally { Marshal.FreeHGlobal(text); }
        }

        internal static DataObject SnapshotClipboard() {
            var saved = new DataObject();
            IDataObject previous = Clipboard.GetDataObject();
            if (previous != null) {
                foreach (string format in previous.GetFormats(false)) {
                    object value = previous.GetData(format,false);
                    if (value != null) saved.SetData(format,false,value);
                }
            }
            return saved;
        }

        static bool ReadUnicodeText(out string text, out uint sequence, out uint owner) {
            text = ""; sequence = 0; owner = 0;
            if (!OpenClipboard(IntPtr.Zero)) return false;
            try {
                GetWindowThreadProcessId(GetClipboardOwner(),out owner);
                IntPtr memory = GetClipboardData(13); // CF_UNICODETEXT
                if (memory != IntPtr.Zero) {
                    IntPtr pointer = GlobalLock(memory);
                    if (pointer != IntPtr.Zero) {
                        try {
                            int chars = (int)Math.Min(GlobalSize(memory).ToUInt64() / 2,2202UL);
                            text = Marshal.PtrToStringUni(pointer,chars) ?? "";
                            int terminator = text.IndexOf('\0');
                            if (terminator >= 0) text = text.Substring(0,terminator);
                            text = text.Trim();
                        } finally { GlobalUnlock(memory); }
                    }
                }
                sequence = GetClipboardSequenceNumber();
                return true;
            } finally { CloseClipboard(); }
        }

        public static string Capture() { return CaptureFromWindow(GetForegroundWindow(),true); }

        internal static string CaptureFromWindow(IntPtr window, bool requireForeground) {
            uint pid;
            GetWindowThreadProcessId(window,out pid);
            if (pid == 0) throw new UserError("请在 SumatraPDF 中选择文字后再按 Ctrl + Alt + D。");
            using (var process = Process.GetProcessById((int)pid)) {
                if (!process.ProcessName.StartsWith("SumatraPDF",StringComparison.OrdinalIgnoreCase))
                    throw new UserError("请在 SumatraPDF 正文中选中文字，再按 Ctrl + Alt + D。");
            }
            var saved = SnapshotClipboard();
            uint before = GetClipboardSequenceNumber();
            uint copied = 0;
            try {
                if (requireForeground && GetForegroundWindow() != window)
                    throw new UserError("阅读窗口已切换，请重新选择文字并触发快捷键。");
                // Do not clear the clipboard: making this waiting STA its owner can
                // block Sumatra's EmptyClipboard/WM_DESTROYCLIPBOARD exchange.
                if (!ExecuteCommand(window,"[CmdCopySelection]"))
                    throw new UserError("SumatraPDF 未响应复制命令。请确认两个程序以相同权限运行后重试。");
                if (GetClipboardSequenceNumber() == before)
                    throw new UserError("当前没有可复制的选文。请重新拖选正文，再按 Ctrl + Alt + D。");
                var clock = Stopwatch.StartNew();
                do {
                    string text;
                    uint sequence, owner;
                    if (ReadUnicodeText(out text,out sequence,out owner)) {
                        // Sumatra 3.6.1 intentionally uses OpenClipboard(NULL).
                        if ((owner != 0 && owner != pid)
                            || (requireForeground && GetForegroundWindow() != window))
                            throw new UserError("剪贴板或阅读窗口同时被其他程序更改，请重试。");
                        copied = sequence;
                        if (text.Length > 2200)
                            throw new UserError("选中文字过长，请缩小到一个词、句子或段落。");
                        if (text.Length > 0) return text;
                        throw new UserError("选区未包含可复制文字。请拖选正文；已有高亮批注需要重新选择文字。");
                    }
                    Application.DoEvents();
                    Thread.Sleep(20);
                } while (clock.ElapsedMilliseconds < 1800);
                throw new UserError("剪贴板正被其他程序占用，请稍后重试。");
            } finally {
                if (copied != 0 && GetClipboardSequenceNumber() == copied) {
                    try { Clipboard.SetDataObject(saved,true,5,40); } catch { }
                }
            }
        }
    }
}
