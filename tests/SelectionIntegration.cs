// Uses a separate hidden Sumatra instance and generated test PDF, with no AI calls.
using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Windows.Forms;
using SumatraDeepSeek;

public static class SelectionIntegration {
    delegate bool EnumCallback(IntPtr window,IntPtr state);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumCallback callback,IntPtr state);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr window,out uint pid);
    [DllImport("user32.dll",CharSet=CharSet.Unicode)] static extern int GetClassName(IntPtr window,StringBuilder text,int length);
    [DllImport("user32.dll")] static extern bool PostMessage(IntPtr window,uint message,IntPtr a,IntPtr b);
    [DllImport("user32.dll")] static extern uint GetClipboardSequenceNumber();
    static IntPtr FindFrame(int processId) {
        IntPtr found=IntPtr.Zero;
        EnumWindows(delegate(IntPtr window,IntPtr state) {
            uint pid; GetWindowThreadProcessId(window,out pid);
            if (pid!=processId) return true;
            var name=new StringBuilder(128); GetClassName(window,name,name.Capacity);
            if (name.ToString()=="SUMATRA_PDF_FRAME") { found=window; return false; }
            return true;
        },IntPtr.Zero);
        return found;
    }
    static void Check(bool valid,string label) {
        if (!valid) throw new Exception(label);
        Console.WriteLine("PASS: "+label);
    }
    static void Pump(int milliseconds) {
        var timer=Stopwatch.StartNew();
        while (timer.ElapsedMilliseconds<milliseconds) { Application.DoEvents(); Thread.Sleep(15); }
    }
    static void Search(IntPtr frame,string file,string term) {
        Check(Selection.ExecuteCommand(frame,"[Search(\""+file+"\",\""+term+"\")]"),"search command accepted");
        Pump(350);
    }
    [STAThread] public static int Main(string[] args) {
        string settings=Path.GetFullPath("artifacts/selection-integration-settings");
        string file=Path.GetFullPath(args[1]);
        Directory.CreateDirectory(settings);
        File.WriteAllText(Path.Combine(settings,"SumatraPDF-settings.txt"),
            "ReuseInstance = false\nRememberOpenedFiles = false\nRememberStatePerDocument = false\nRestoreSession = false\nCheckForUpdates = false\n");
        var start=new ProcessStartInfo(args[0],"-appdata \""+settings+"\" -new-window \""+file+"\"") {
            UseShellExecute=false,CreateNoWindow=true,WindowStyle=ProcessWindowStyle.Hidden
        };
        DataObject original=Selection.SnapshotClipboard();
        using (var process=Process.Start(start)) {
            IntPtr frame=IntPtr.Zero;
            try {
                var timer=Stopwatch.StartNew();
                while (frame==IntPtr.Zero && timer.ElapsedMilliseconds<8000 && !process.HasExited) {
                    frame=FindFrame(process.Id); Pump(80);
                }
                Check(frame!=IntPtr.Zero,"isolated installed Sumatra window available");
                Pump(300);
                string sentinel="clipboard regression 中文 "+Guid.NewGuid().ToString("N");
                var saved=new DataObject(); saved.SetText(sentinel,TextDataFormat.UnicodeText);
                saved.SetData(DataFormats.Html,"<b>clipboard-regression</b>");
                Clipboard.SetDataObject(saved,true);
                bool rejected=false;
                try { Selection.CaptureFromWindow(frame,false); } catch (UserError) { rejected=true; }
                Check(rejected,"no selection rejects stale clipboard text");
                Check(Clipboard.GetText()==sentinel,"no selection preserves previous clipboard");
                Search(frame,file,"bank");
                // Reproduce the original clear + asynchronous copy + sleeping STA.
                Clipboard.Clear();
                uint cleared=GetClipboardSequenceNumber();
                PostMessage(frame,0x111,new IntPtr(234),IntPtr.Zero);
                bool legacyRead=false;
                timer.Restart();
                while (timer.ElapsedMilliseconds<1500) {
                    if (GetClipboardSequenceNumber()!=cleared && Clipboard.ContainsText()) { legacyRead=true; break; }
                    Thread.Sleep(25);
                }
                Console.WriteLine("Legacy asynchronous copy succeeded: "+legacyRead);
                Pump(300);
                Clipboard.SetDataObject(saved,true);
                Check(Selection.CaptureFromWindow(frame,false)=="bank","native command captures selected word");
                Check(Clipboard.GetText()==sentinel,"successful copy restores previous Unicode clipboard");
                Check(Clipboard.GetData(DataFormats.Html).ToString()=="<b>clipboard-regression</b>","successful copy restores HTML clipboard");
                Search(frame,file,"bank approved a loan");
                Check(Selection.CaptureFromWindow(frame,false)=="bank approved a loan","captures newly selected phrase without stale text");
                Check(Selection.ExecuteCommand(frame,"[CmdSelectAll]"),"select-all command accepted");
                string paragraph=Selection.CaptureFromWindow(frame,false);
                Check(paragraph.Contains("river bank") && paragraph.Contains("approved a loan"),"captures a full paragraph from real PDF");
                return 0;
            } catch (Exception ex) { Console.WriteLine("FAIL: "+ex); return 1; }
            finally {
                if (frame!=IntPtr.Zero) PostMessage(frame,0x10,IntPtr.Zero,IntPtr.Zero);
                if (!process.WaitForExit(3000)) process.Kill();
                Clipboard.SetDataObject(original,true);
            }
        }
    }
}
