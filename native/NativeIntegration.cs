// Test only: a separate Sumatra process, generated PDF, isolated settings, no API key.
using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Windows.Forms;
using System.Collections.Generic;
using System.Web.Script.Serialization;
using SumatraDeepSeek;

public static class NativeIntegration {
    delegate bool EnumCallback(IntPtr h, IntPtr p);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumCallback f, IntPtr p);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassName(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern IntPtr FindWindowEx(IntPtr parent, IntPtr after, string cls, string title);
    [DllImport("user32.dll")] static extern IntPtr GetDlgItem(IntPtr h, int id);
    [DllImport("user32.dll")] static extern IntPtr GetParent(IntPtr h);
    [DllImport("user32.dll")] static extern IntPtr GetWindow(IntPtr h, uint relation);
    [DllImport("user32.dll")] static extern bool IsWindow(IntPtr h);
    [DllImport("user32.dll")] static extern uint GetDpiForWindow(IntPtr h);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr h, int how);
    [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr h, IntPtr a, int x, int y, int w, int z, uint flags);
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out Rect r);
    [DllImport("user32.dll")] static extern bool PrintWindow(IntPtr h, IntPtr dc, uint flags);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, StringBuilder l);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, string l);
    [DllImport("user32.dll")] static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] static extern bool SetProcessDpiAwarenessContext(IntPtr context);
    [DllImport("user32.dll")] static extern uint GetClipboardSequenceNumber();
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern bool SetWindowText(IntPtr h,string text);
    [DllImport("user32.dll")] static extern bool IsWindowEnabled(IntPtr h);
    [StructLayout(LayoutKind.Sequential)] struct Rect { public int left, top, right, bottom; }
    static IntPtr Find(int pid,string className="SUMATRA_PDF_FRAME") {
        IntPtr found=IntPtr.Zero;
        EnumWindows(delegate(IntPtr h,IntPtr unused) {
            uint owner; GetWindowThreadProcessId(h,out owner);
            var name=new StringBuilder(100); GetClassName(h,name,100);
            if(owner==pid && name.ToString()==className) { found=h; return false; }
            return true;
        },IntPtr.Zero);
        return found;
    }
    static void Pump(int ms) {
        var t=Stopwatch.StartNew();
        while(t.ElapsedMilliseconds<ms) { Application.DoEvents(); Thread.Sleep(15); }
    }
    static void Check(bool ok,string label) {
        if(!ok) throw new Exception(label);
        Console.WriteLine("PASS: "+label);
    }
    static string Read(IntPtr panel,int id) {
        return WindowText(GetDlgItem(panel,id));
    }
    static string WindowText(IntPtr hwnd) {
        var b=new StringBuilder(20000);
        SendMessage(hwnd,0xD,new IntPtr(b.Capacity),b);
        return b.ToString();
    }
    static void Click(IntPtr panel,int id) {
        SendMessage(GetDlgItem(panel,id),0xF5,IntPtr.Zero,IntPtr.Zero); Pump(80);
    }
    static void Choose(IntPtr panel,int id,int index) {
        var control=GetDlgItem(panel,id);
        SendMessage(control,0x14E,new IntPtr(index),IntPtr.Zero);
        SendMessage(panel,0x111,new IntPtr(id | (1<<16)),control); Pump(100);
    }
    static void Edit(IntPtr panel,int id,string value) {
        SendMessage(GetDlgItem(panel,id),0xC,IntPtr.Zero,value); Pump(100);
        // Windows hides cross-process reads of password controls. Verify this field through DPAPI persistence below.
        if(id==9108) return;
        Check(Read(panel,id)==value,"test input reaches native edit control");
    }
    static void Fixture(string settings,string pdf) {
        string dir=Path.Combine(settings,"AIHistory"); Directory.CreateDirectory(dir);
        var record=new Dictionary<string,object> {
            {"Schema",1},{"id","11111111-1111-1111-1111-111111111111"},
            {"time",DateTime.Now.ToString("yyyy-MM-ddTHH:mm:sszzz")},{"file",pdf},{"title","Synthetic reading sample"},
            {"selected","bank"},{"context","the bank approved a loan"},{"answer","这里指银行。The financial institution approved a loan."},
            {"kind","explain"},{"provider","Fixture"},{"model","offline-fixture"},{"language","zh"},{"page",1}
        };
        File.WriteAllText(Path.Combine(dir,(string)record["id"]+".json"),new JavaScriptSerializer().Serialize(record),new UTF8Encoding(false));
    }
    static string WaitAnswer(IntPtr panel,int id) {
        var wait=Stopwatch.StartNew();
        while(Read(panel,id)=="" && wait.ElapsedMilliseconds<125000) Pump(200);
        return Read(panel,id);
    }
    static void Command(IntPtr frame,string command) {
        Check(Selection.ExecuteCommand(frame,command),command.StartsWith("[Search")?"native document search":"native command "+command);
        Pump(350);
    }
    static void Shot(IntPtr frame,string path) {
        Rect r; GetWindowRect(frame,out r);
        using(var bmp=new Bitmap(r.right-r.left,r.bottom-r.top))
        using(var g=Graphics.FromImage(bmp)) {
            var dc=g.GetHdc();
            try { PrintWindow(frame,dc,2); } finally {g.ReleaseHdc(dc);}
            bmp.Save(path,ImageFormat.Png);
        }
    }
    static int Height(IntPtr panel,int id) { Rect r; GetWindowRect(GetDlgItem(panel,id),out r); return r.bottom-r.top; }
    static Dictionary<string,object> BookData(string settings) {
        var files=Directory.GetFiles(Path.Combine(settings,"BookLibrary"),"*.json");
        Check(files.Length==1,"one PDF and its archives remain one book in the library");
        return new JavaScriptSerializer().Deserialize<Dictionary<string,object>>(File.ReadAllText(files[0]));
    }
    static void WaitArchive(IntPtr panel) {
        var wait=Stopwatch.StartNew();
        while(!IsWindowEnabled(GetDlgItem(panel,9159)) && wait.ElapsedMilliseconds<15000) Pump(100);
        Check(Read(panel,9160).Contains("Archived:"),"archive finishes in the sidebar without an API key");
    }
    static string CheckBooks(IntPtr panel,IntPtr frame,string settings,string pdf) {
        Click(panel,9152);
        Check(IsWindowVisible(GetDlgItem(panel,9164)) && Read(panel,9163).Contains("Finished: 1") && Read(panel,9165).Contains("★★★★"),
            "Books tab shows the finished PDF, its four-star rating and local totals");
        Choose(panel,9162,1);
        Check(SendMessage(GetDlgItem(panel,9164),0x18B,IntPtr.Zero,IntPtr.Zero).ToInt32()==0 && !IsWindowEnabled(GetDlgItem(panel,9166)),
            "Reading filter omits finished books without leaving an active stale selection");
        Choose(panel,9162,2);
        Check(Read(panel,9165).Contains("Completed:"),"Finished filter shows the saved completion date");
        Edit(panel,9161,"no-such-book");
        Check(SendMessage(GetDlgItem(panel,9164),0x18B,IntPtr.Zero,IntPtr.Zero).ToInt32()==0,"book search handles an empty result");
        Edit(panel,9161,Path.GetFileNameWithoutExtension(pdf));
        Check(Read(panel,9165).Contains(Path.GetFileName(pdf)),"book search matches Unicode filenames");
        Edit(panel,9161,"");
        uint readerPid; GetWindowThreadProcessId(frame,out readerPid);
        PostMessage(GetDlgItem(panel,9159),0xF5,IntPtr.Zero,IntPtr.Zero);
        var waitFolder=Stopwatch.StartNew(); IntPtr folderDialog=IntPtr.Zero;
        while(folderDialog==IntPtr.Zero && waitFolder.ElapsedMilliseconds<7000) { Pump(100); folderDialog=Find((int)readerPid,"#32770"); }
        Check(folderDialog!=IntPtr.Zero && WindowText(folderDialog).Contains("Choose archive folder"),
            "first archive opens the native folder picker with a clear destination prompt");
        SendMessage(folderDialog,0x10,IntPtr.Zero,IntPtr.Zero); Pump(200);
        Check((string)BookData(settings)["archivePath"]=="", "cancelling the folder picker leaves the PDF and book unarchived");
        Click(panel,9107);
        string root=Path.Combine(settings,"阅读归档");
        Edit(panel,9169,root); Click(panel,9110);
        Check(IsWindowVisible(GetDlgItem(panel,9164)),"saving the archive folder returns to the Books tab");
        Click(panel,9159); WaitArchive(panel);
        var book=BookData(settings); string archived=(string)book["archivePath"];
        Check(archived.StartsWith(Path.Combine(root,"4星")) && File.Exists(pdf) && File.Exists(archived) &&
            Convert.ToBase64String(File.ReadAllBytes(pdf))==Convert.ToBase64String(File.ReadAllBytes(archived)),
            "native archive preserves the original PDF and copies its saved annotations into the chosen star folder");
        Click(panel,9159); WaitArchive(panel);
        Check((string)BookData(settings)["archivePath"]==archived && Directory.GetFiles(root,"*.pdf",SearchOption.AllDirectories).Length==1,
            "repeated archive clicks do not create duplicate unchanged copies");
        Choose(panel,9158,0);
        Check(!(bool)BookData(settings)["finished"] && (string)BookData(settings)["finishedAt"]=="", "Reading state clears the prior completion date on disk");
        Choose(panel,9158,1);
        var record=new Dictionary<string,object> {
            {"Schema",1},{"id","22222222-2222-2222-2222-222222222222"},{"time",DateTime.Now.ToString("yyyy-MM-ddTHH:mm:sszzz")},
            {"file",archived},{"title","Synthetic book summary"},{"selected",""},{"context",""},
            {"answer","OFFLINE_BOOK_SUMMARY: 银行与河岸的区别。"},{"kind","file"},{"provider","Fixture"},{"model","offline-fixture"},{"language","zh"},{"page",0}
        };
        File.WriteAllText(Path.Combine(settings,"AIHistory",(string)record["id"]+".json"),new JavaScriptSerializer().Serialize(record),new UTF8Encoding(false));
        Click(panel,9152);
        Check(Read(panel,9165).Contains("OFFLINE_BOOK_SUMMARY"),"book detail reuses a saved AI document summary from its archived path");
        Click(panel,9117);
        Check(Read(panel,9152)=="书单" && Read(panel,9163).Contains("读完 1 本") && Read(panel,9158)=="读完", "ratings, reading state and book totals switch to Chinese");
        Shot(frame,Path.GetFullPath("artifacts/native-book-list.png"));
        Click(panel,9117);
        Click(panel,9118);
        return archived;
    }
    [STAThread] public static int Main(string[] args) {
        Console.WriteLine("STEP: initialize isolated native reader test");
        SetProcessDpiAwarenessContext(new IntPtr(-4));
        bool live=args.Length>3 && args[2]=="--live";
        string settings=Path.GetFullPath((live ? "artifacts/native-live-test-" : "artifacts/native-test-")+Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(settings);
        string keyFile=Path.Combine(settings,"DeepSeek.json");
        string aiConfig=Path.Combine(settings,"AIReader.json");
        if(live) {
            var json=new JavaScriptSerializer();
            var old=json.Deserialize<Dictionary<string,object>>(File.ReadAllText(args[3]));
            object encrypted=old.ContainsKey("ProtectedKey")?old["ProtectedKey"]:((Dictionary<string,object>)old["Keys"])["DeepSeek"];
            File.WriteAllText(aiConfig,json.Serialize(new Dictionary<string,object> {
                {"Schema",3},{"Provider","DeepSeek"},{"Language","zh"},
                {"Keys",new Dictionary<string,object>{{"DeepSeek",encrypted}}},
                {"Models",new Dictionary<string,object>{{"DeepSeek","deepseek-flash"}}}
            }),new UTF8Encoding(false));
        }
        else if(File.Exists(keyFile)) throw new Exception("Offline test folder must not contain a credential");
        // These synthetic test settings never contain the user's credential.
        File.WriteAllText(Path.Combine(settings,"SumatraPDF-settings.txt"),
            "ReuseInstance = false\nRememberOpenedFiles = false\nRememberStatePerDocument = false\nRestoreSession = false\nCheckForUpdates = false\nUiLanguage = en\nShowToc = false\n");
        string pdf=Path.GetFullPath(args[1]);
        if(!live) Fixture(settings,pdf);
        var info=new ProcessStartInfo(args[0],"-appdata \""+settings+"\" -new-window \""+pdf+"\"") {
            UseShellExecute=false,CreateNoWindow=true,WindowStyle=ProcessWindowStyle.Hidden
        };
        uint clipboardSequence=GetClipboardSequenceNumber();
        Console.WriteLine("STEP: launch reader with synthetic PDF and isolated settings");
        using(var process=Process.Start(info)) {
            IntPtr frame=IntPtr.Zero;
            try {
                var t=Stopwatch.StartNew();
                while(frame==IntPtr.Zero && t.ElapsedMilliseconds<15000 && !process.HasExited) {frame=Find(process.Id);Pump(100);}
                Check(frame!=IntPtr.Zero,"native reader starts with a real PDF");
                ShowWindow(frame,4);
                SetWindowPos(frame,IntPtr.Zero,20,20,1800,1250,0x14);
                Pump(400);
                if(live) {
                    Command(frame,"[Search(\""+pdf+"\",\"bank approved a loan\")]");
                    Command(frame,"[CmdDeepSeekExplain]");
                    IntPtr livePanel=FindWindowEx(frame,IntPtr.Zero,"SumatraDeepSeekPanel",null);
                    Check(livePanel!=IntPtr.Zero,"live request uses the internal sidebar");
                    Check(!IsWindowVisible(GetDlgItem(livePanel,9108)),"existing encrypted key loads in the native reader");
                    string answer=WaitAnswer(livePanel,9102);
                    Console.WriteLine("Synthetic live answer: "+answer);
                    Check(answer.Length>0 && !answer.Contains("失败") && !answer.Contains("无效") && !answer.Contains("不足")
                        && !answer.Contains("不可用") && !answer.Contains("未返回") && !answer.Contains("未被接受") && !answer.Contains("频繁"),
                        "DeepSeek returns an explanation in the reader");
                    Check(answer.Length<500,"live explanation is concise");
                    Check(Directory.GetFiles(Path.Combine(settings,"AIHistory"),"*.json").Length==1,"successful live explanation is automatically saved");
                    Click(livePanel,9117);
                    Click(livePanel,9106);
                    string english=WaitAnswer(livePanel,9102);
                    Check(english.Length>15 && Read(livePanel,9103).StartsWith("Saved to history"),"English explanation succeeds and is saved");
                    Check(english.ToLowerInvariant().Contains("loan"),"English response refers to the selected financial action");
                    Console.WriteLine("Synthetic English answer: "+english);
                    Click(livePanel,9120);
                    Click(livePanel,9135); Pump(700);
                    Check(Read(livePanel,9134).Contains("1 pages checked"),"single-file summary prepares the complete synthetic document");
                    Click(livePanel,9136);
                    string summary=WaitAnswer(livePanel,9137);
                    Check(summary.Length>10 && Read(livePanel,9134).StartsWith("Saved to history"),"full-document summary succeeds and is saved");
                    Console.WriteLine("Synthetic file summary: "+summary);
                    Choose(livePanel,9131,1); Click(livePanel,9135);
                    Check(Read(livePanel,9134).Contains("3 records"),"daily summary uses both lookups and the saved document summary");
                    Click(livePanel,9136);
                    string daily=WaitAnswer(livePanel,9137);
                    Check(daily.Length>10 && Read(livePanel,9134).StartsWith("Saved to history"),"daily reading review succeeds and is saved");
                    Console.WriteLine("Synthetic daily review: "+daily);
                    Check(Directory.GetFiles(Path.Combine(settings,"AIHistory"),"*.json").Length==4,"all four live results persist as separate records");
                    Pump(1600);
                    Shot(frame,Path.GetFullPath("artifacts/native-live-sidebar.png"));
                    Check(GetClipboardSequenceNumber()==clipboardSequence,"live AI lookup does not touch clipboard");
                    return 0;
                }
                IntPtr panel=FindWindowEx(frame,IntPtr.Zero,"SumatraDeepSeekPanel",null);
                uint owner;GetWindowThreadProcessId(panel,out owner);
                Check(panel!=IntPtr.Zero && GetParent(panel)==frame && owner==process.Id,"sidebar is a child in the reader process");
                Check(IsWindowVisible(panel),"sidebar is visible on startup without a command");
                var version=FileVersionInfo.GetVersionInfo(args[0]);
                Check(WindowText(frame).Contains("DeepReader") && Read(panel,9112)=="DeepReader" &&
                    version.ProductName=="DeepReader" && version.ProductVersion=="1.2.0","window, sidebar and executable metadata identify DeepReader 1.2.0");
                Check(IsWindowVisible(GetDlgItem(panel,9139)) && Read(panel,9139).Contains("欢迎使用 DeepReader") &&
                    Read(panel,9139).Contains("Ctrl + Alt + D") && Read(panel,9139).Contains("按量计费"),"new reader shows concise Chinese onboarding and pricing context");
                Check(File.ReadAllText(aiConfig).Contains("\"OnboardingSeen\":true"),"first-use guide is marked seen without requiring an API key");
                using(var icon=Icon.ExtractAssociatedIcon(args[0])) using(var pixels=icon.ToBitmap()) {
                    int green=0;
                    for(int y=0;y<pixels.Height;y++) for(int x=0;x<pixels.Width;x++) {
                        var c=pixels.GetPixel(x,y); if(c.A>128 && c.G>c.R*1.2 && c.G>c.B*1.1) green++;
                    }
                    Check(green>pixels.Width*pixels.Height/6,"executable embeds the green application icon");
                }
                Shot(frame,Path.GetFullPath("artifacts/deepreader-welcome-zh.png"));
                Click(panel,9117);
                Check(Read(panel,9139).Contains("Welcome to DeepReader") && Read(panel,9140)=="Configure API","onboarding switches to English");
                Shot(frame,Path.GetFullPath("artifacts/deepreader-welcome-en.png"));
                Click(panel,9117);
                Click(panel,9140);
                Check(IsWindowVisible(GetDlgItem(panel,9108)) && Read(panel,9121)=="DeepSeek","onboarding opens native API configuration");
                Click(panel,9111);
                Check(!IsWindowVisible(GetDlgItem(panel,9139)) && IsWindowVisible(GetDlgItem(panel,9142)),"leaving initial setup shows the regular reading panes");
                Check(IsWindowEnabled(GetDlgItem(panel,9153)) && Read(panel,9158)=="阅读中" && Read(panel,9160).Contains("未评分"),
                    "a newly opened PDF exposes unrated stars and Reading state in the native sidebar");
                Click(panel,9159);
                Check(Read(panel,9160).Contains("1–5"),"archive asks for a star rating before choosing a destination");
                Click(panel,9156); Choose(panel,9158,1);
                var initialBook=BookData(settings);
                Check(Convert.ToInt32(initialBook["rating"])==4 && (bool)initialBook["finished"] && ((string)initialBook["finishedAt"]).Length>=10,
                    "clicking four stars and Finished immediately persists this PDF's metadata");
                Check(Math.Abs(Height(panel,9101)-Height(panel,9102))<=2,"selected text and explanation initially share the available space equally");
                Shot(GetDlgItem(panel,9142),Path.GetFullPath("artifacts/native-divider.png"));
                Check(IsWindowVisible(GetDlgItem(panel,9147)) && IsWindowVisible(GetDlgItem(panel,9148)) &&
                    !IsWindowEnabled(GetDlgItem(panel,9148)) && Read(panel,9149).Contains("追问"),
                    "follow-up input and send button are integrated into the reading sidebar");
                var splitter=GetDlgItem(panel,9142); int beforeDrag=Height(panel,9101);
                SendMessage(splitter,0x201,new IntPtr(1),new IntPtr(10|(10<<16)));
                SendMessage(splitter,0x200,new IntPtr(1),new IntPtr(10|(40<<16)));
                int duringDrag=Height(panel,9101);
                SendMessage(splitter,0x200,new IntPtr(1),new IntPtr(10|(35<<16)));
                Check(Height(panel,9101)>duringDrag,"divider retains mouse capture for a continuous drag");
                Shot(splitter,Path.GetFullPath("artifacts/native-divider-active.png"));
                SendMessage(splitter,0x202,IntPtr.Zero,IntPtr.Zero); Pump(100);
                Check(Height(panel,9101)>beforeDrag,"dragging the divider resizes the selected text pane");
                SendMessage(splitter,0x100,new IntPtr(0x24),IntPtr.Zero);
                Check(Math.Abs(Height(panel,9101)-Height(panel,9102))<=2,"Home on the divider restores the equal split");
                for(int i=0;i<3;i++) SendMessage(splitter,0x100,new IntPtr(0x28),IntPtr.Zero);
                Check(File.ReadAllText(aiConfig).Contains("\"LookupSplit\":65"),"resized pane proportion is persisted");
                IntPtr grip=GetDlgItem(frame,9151);
                Rect oldSidebar,newSidebar; GetWindowRect(panel,out oldSidebar);
                Check(IsWindowVisible(grip) && Read(panel,9150)=="悬浮","docked sidebar exposes a resize grip and Float button");
                SendMessage(grip,0x201,new IntPtr(1),new IntPtr(3 | (40<<16)));
                SendMessage(grip,0x200,new IntPtr(1),new IntPtr(unchecked((ushort)-120) | (40<<16)));
                SendMessage(grip,0x202,IntPtr.Zero,IntPtr.Zero); Pump(100);
                GetWindowRect(panel,out newSidebar);
                Check(newSidebar.right-newSidebar.left>oldSidebar.right-oldSidebar.left,"dragging the left boundary widens the sidebar");
                SendMessage(grip,0x100,new IntPtr(0x24),IntPtr.Zero);
                for(int i=0;i<4;i++) SendMessage(grip,0x100,new IntPtr(0x25),IntPtr.Zero);
                Check(File.ReadAllText(aiConfig).Contains("\"PanelWidth\":500"),"sidebar width is saved independently of the selected/explanation split");
                Click(panel,9107); Click(panel,9143);
                Check(IsWindowVisible(GetDlgItem(panel,9139)),"guide can be reopened explicitly from settings");
                Click(panel,9141);
                Check(!IsWindowVisible(GetDlgItem(panel,9139)),"Start reading dismisses the guide");
                Command(frame,"[CmdHelpAbout]");
                var about=Find(process.Id,"SUMATRA_PDF_ABOUT");
                Check(about!=IntPtr.Zero && WindowText(about).Contains("DeepReader"),"native About window identifies DeepReader");
                Shot(about,Path.GetFullPath("artifacts/deepreader-about.png"));
                SendMessage(about,0x10,IntPtr.Zero,IntPtr.Zero);
                Command(frame,"[CmdDeepSeekExplain]");
                Check(Read(panel,9101)=="" && Read(panel,9103).Contains("2200"),"no selection gives inline guidance without old text");
                Command(frame,"[Search(\""+pdf+"\",\"bank\")]");
                Command(frame,"[CmdDeepSeekExplain]");
                Check(Read(panel,9101)=="bank","direct native selection captures word");
                Check(!IsWindowVisible(GetDlgItem(panel,9139)),"onboarding does not obscure a captured selection");
                Check(Read(panel,9104).Contains("river ⟦bank⟧"),"context marks the first bank by selected glyph position");
                Check(IsWindowVisible(GetDlgItem(panel,9108)),"missing key opens settings inside the panel");
                Check(Read(panel,9121)=="DeepSeek" && Read(panel,9109)=="deepseek-flash" && Read(panel,9114).Contains("DeepSeek") &&
                    Read(panel,9123).Contains("按量计费"),"new reader defaults to official DeepSeek Flash with its own key field and pricing notice");
                Shot(frame,Path.GetFullPath("artifacts/native-deepseek-default.png"));
                Check(GetClipboardSequenceNumber()==clipboardSequence,"selection and context never touch the clipboard");
                Click(panel,9111);
                Check(!IsWindowVisible(GetDlgItem(panel,9104)) && Read(panel,9105)=="高亮","highlight replaces the visible context toggle");
                Edit(panel,9147,"为什么这里这样用？\r\n请给一个例子。");
                Check(!IsWindowEnabled(GetDlgItem(panel,9148)),"follow-up cannot send without a successful initial explanation");
                Click(panel,9107); Click(panel,9111);
                Check(Read(panel,9147).Contains("请给一个例子"),"follow-up draft survives visiting settings");
                string keepSelection=Read(panel,9101),keepContext=Read(panel,9104),keepDraft=Read(panel,9147);
                Edit(panel,9102,"Offline answer retained across window modes");
                var readingCanvas=FindWindowEx(frame,IntPtr.Zero,"SUMATRA_PDF_CANVAS",null);
                Rect dockedCanvas,floatingCanvas; GetWindowRect(readingCanvas,out dockedCanvas);
                Click(panel,9150);
                IntPtr floating=Find(process.Id,"DeepReaderFloatingPanel");
                Check(floating!=IntPtr.Zero && GetParent(panel)==floating && GetWindow(floating,4)==frame && Read(panel,9150)=="停靠",
                    "Float reparents the same panel into a reader-owned window");
                GetWindowRect(readingCanvas,out floatingCanvas);
                Check(IsWindowVisible(floating) && !IsWindowVisible(grip) && floatingCanvas.right>dockedCanvas.right,
                    "floating sidebar returns its docked space to the document");
                Check(Read(panel,9101)==keepSelection && Read(panel,9104)==keepContext && Read(panel,9147)==keepDraft &&
                    Read(panel,9102).Contains("Offline answer retained"),"floating preserves selected text, context, explanation and follow-up draft");
                var workArea=Screen.FromHandle(floating).WorkingArea;
                int floatX=workArea.Left+40,floatY=workArea.Top+40;
                int floatWidth=Math.Min((int)(560*GetDpiForWindow(floating)/96),workArea.Width-80);
                int floatHeight=Math.Min((int)(640*GetDpiForWindow(floating)/96),workArea.Height-80);
                SetWindowPos(floating,IntPtr.Zero,floatX,floatY,floatWidth,floatHeight,0x14); Pump(100);
                SendMessage(floating,0x232,IntPtr.Zero,IntPtr.Zero);
                Rect floatBounds; GetWindowRect(floating,out floatBounds);
                var floatConfig=new JavaScriptSerializer().Deserialize<Dictionary<string,object>>(File.ReadAllText(aiConfig));
                int savedFloatWidth=Convert.ToInt32(floatConfig["PanelFloatingWidth"]),savedFloatHeight=Convert.ToInt32(floatConfig["PanelFloatingHeight"]);
                Check(floatBounds.left==floatX && floatBounds.top==floatY && floatBounds.right-floatBounds.left==floatWidth &&
                    Math.Abs(savedFloatWidth-floatWidth*96.0/GetDpiForWindow(floating))<=1 && Math.Abs(savedFloatHeight-floatHeight*96.0/GetDpiForWindow(floating))<=1,
                    "floating window can move and resize, and persists dimensions independently of screen scaling");
                Shot(floating,Path.GetFullPath("artifacts/native-floating-sidebar.png"));
                PostMessage(GetDlgItem(panel,9147),0x100,new IntPtr(0x1B),IntPtr.Zero); Pump(150);
                Check(!IsWindowVisible(floating) && IsWindow(floating) && Read(panel,9147)==keepDraft,"Escape in a floating edit hides the panel without destroying its content");
                Command(frame,"[CmdDeepSeekPanel]");
                Check(IsWindowVisible(floating),"the reader command reopens the same floating sidebar");
                ShowWindow(frame,6); Pump(150);
                Check(!IsWindowVisible(floating),"floating sidebar hides when its reader is minimized");
                ShowWindow(frame,9); Pump(150);
                Check(IsWindowVisible(floating),"floating sidebar returns when its reader is restored");
                SendMessage(floating,0x10,IntPtr.Zero,IntPtr.Zero); Pump(100);
                Check(!IsWindowVisible(floating) && !process.HasExited,"closing the floating sidebar keeps the reader alive");
                Command(frame,"[CmdDeepSeekPanel]"); Click(panel,9150);
                Check(GetParent(panel)==frame && !IsWindowVisible(floating) && Read(panel,9101)==keepSelection && Read(panel,9147)==keepDraft,
                    "Dock returns the existing panel and draft to the reader");
                Edit(panel,9102,"");
                // The DDE Search command does not populate the toolbar's find
                // box; use the reader's Find Next Selection command here.
                Command(frame,"[CmdFindNextSel]");
                Command(frame,"[CmdDeepSeekExplain]");
                Console.WriteLine("Synthetic second context: "+Read(panel,9104));
                Check(Read(panel,9104).Contains("the ⟦bank⟧ approved"),"repeated word uses the second selected occurrence");
                Check(Read(panel,9147)=="","new selection clears the previous follow-up draft");
                Click(panel,9111);
                Command(frame,"[Search(\""+pdf+"\",\"bank approved a loan\")]");
                Command(frame,"[CmdDeepSeekExplain]");
                Check(Read(panel,9101)=="bank approved a loan","continuous reading updates to the new phrase");
                Click(panel,9111);
                Command(frame,"[Search(\""+pdf+"\",\"bank\")]");
                Click(panel,9105);
                Check(Read(panel,9105)=="取消高亮" && IsWindowEnabled(GetDlgItem(panel,9144)),"captured phrase becomes a PDF highlight and can be saved");
                Click(panel,9159);
                Check(Read(panel,9160).Contains("保存批注"),"archive refuses to silently omit unsaved PDF highlights");
                Click(panel,9144); Pump(700);
                Check(Read(panel,9103).Contains("已保存到 PDF") && Read(panel,9101)=="bank approved a loan" && Read(panel,9105)=="取消高亮",
                    "saving PDF annotations keeps the query and recognizes the reloaded highlight");
                File.Copy(pdf,Path.GetFullPath("artifacts/highlight-added.pdf"),true);
                Click(panel,9117);
                Check(Read(panel,9148)=="Send" && Read(panel,9149).Contains("Follow-up"),"follow-up controls switch to English");
                Check(Read(panel,9112)=="DeepReader" && Read(panel,9118)=="Lookup" && File.ReadAllText(aiConfig).Contains("\"Language\":\"en\"") &&
                    File.ReadAllText(aiConfig).Contains("\"Provider\":\"DeepSeek\""),"language change saves the default DeepSeek provider and English preference");
                Click(panel,9107);
                Check(Read(panel,9123).Contains("DeepSeek official") && Read(panel,9123).Contains("billed by usage"),"DeepSeek settings and cost notice switch to English");
                Choose(panel,9121,0);
                Check(Read(panel,9109)=="openrouter/free" && Read(panel,9123).Contains("Free route"),"OpenRouter remains an optional protected free route");
                Choose(panel,9121,1);
                Check(Read(panel,9109)=="deepseek-flash" && Read(panel,9114).Contains("DeepSeek"),"provider selector keeps DeepSeek model and key slot separate");
                Choose(panel,9121,0); Choose(panel,9109,1);
                Check(Read(panel,9109)=="openai/gpt-6.1-sol" && Read(panel,9123).Contains("Paid"),"mainstream model selection clearly labels paid access");
                Edit(panel,9108,"synthetic-unsaved-key"); Click(panel,9117); Click(panel,9117);
                Check(Read(panel,9109)=="openai/gpt-6.1-sol","language switch preserves the unsaved model input");
                Click(panel,9150);
                Check(Read(panel,9150)=="Dock" && Read(panel,9109)=="openai/gpt-6.1-sol","floating preferences preserve the unsaved model and translate Dock");
                Click(panel,9150);
                Check(Read(panel,9150)=="Float" && IsWindowVisible(GetDlgItem(panel,9108)),"docking keeps the active preferences view");
                Choose(panel,9109,0); Click(panel,9110);
                var savedConfig=new JavaScriptSerializer().Deserialize<Dictionary<string,object>>(File.ReadAllText(aiConfig));
                var savedKeys=(Dictionary<string,object>)savedConfig["Keys"];
                var bytes=System.Security.Cryptography.ProtectedData.Unprotect(Convert.FromBase64String((string)savedKeys["OpenRouter"]),
                    Encoding.UTF8.GetBytes("SumatraDeepSeek/1"),System.Security.Cryptography.DataProtectionScope.CurrentUser);
                Check(Encoding.UTF8.GetString(bytes)=="synthetic-unsaved-key","language and floating/docking switches preserve the unsaved key, which is encrypted correctly on save");
                Array.Clear(bytes,0,bytes.Length);
                // Restore the isolated offline profile to no credentials before testing missing-key behavior.
                savedKeys["OpenRouter"]="";
                File.WriteAllText(aiConfig,new JavaScriptSerializer().Serialize(savedConfig),new UTF8Encoding(false));
                Click(panel,9107); Click(panel,9111);
                Click(panel,9119);
                Check(Read(panel,9130).Contains("1 saved") && Read(panel,9127).Contains("approved a loan"),"history displays saved contextual answers");
                Edit(panel,9125,"BANK");
                Check(Read(panel,9127).Contains("银行"),"history searches saved queries case-insensitively");
                Edit(panel,9125,"no-match-at-all");
                Check(Read(panel,9127)=="","history search handles no matches without stale detail");
                Edit(panel,9125,"");
                Shot(frame,Path.GetFullPath("artifacts/native-history-v3.png"));
                Click(panel,9120); Click(panel,9135); Pump(700);
                Check(IsWindowVisible(GetDlgItem(panel,9145)) && Read(panel,9145).Contains("All-time successful lookups: 1") &&
                    Read(panel,9145).Contains("In this scope: 1 lookups") && Read(panel,9145).Contains("failed requests are excluded"),
                    "summary shows verified reading statistics without an API key");
                Check(Read(panel,9134).Contains("1 pages checked") && IsWindowEnabled(GetDlgItem(panel,9136)),"file summary reads all pages and shows the request budget before sending");
                for(int scope=1;scope<=3;++scope) {
                    Choose(panel,9131,scope); Click(panel,9135);
                    Check(Read(panel,9134).Contains("1 records") && IsWindowEnabled(GetDlgItem(panel,9136)),"calendar summary scope "+scope+" selects saved records and enables generation");
                }
                Edit(panel,9132,"2026-02-30"); Click(panel,9135);
                Check(Read(panel,9134).Contains("valid YYYY-MM-DD") && !IsWindowEnabled(GetDlgItem(panel,9136)),"invalid summary dates are rejected without API calls");
                Edit(panel,9132,"2000-01-01"); Click(panel,9135);
                Check(Read(panel,9134).Contains("No saved"),"empty date ranges avoid an API request");
                Check(Read(panel,9145).Contains("All-time successful lookups: 1") && Read(panel,9145).Contains("In this scope: 0 lookups"),
                    "empty summary range shows zero scoped queries while retaining the cumulative count");
                Edit(panel,9132,DateTime.Today.ToString("yyyy-MM-dd")); Choose(panel,9131,2); Click(panel,9135);
                Shot(frame,Path.GetFullPath("artifacts/native-summary-v3.png"));
                Click(panel,9136);
                Check(IsWindowVisible(GetDlgItem(panel,9108)),"summary requires the selected provider's key within native settings");
                Click(panel,9111); Click(panel,9118);
                string archivedPdf=CheckBooks(panel,frame,settings,pdf);
                Shot(frame,Path.GetFullPath("artifacts/native-sidebar.png"));
                SetWindowPos(frame,IntPtr.Zero,20,20,1400,850,0x14); Pump(100);
                Click(panel,9107);
                SendMessage(panel,0x115,new IntPtr(7),IntPtr.Zero); Pump(100);
                Rect settingsPanel,saveButton; GetWindowRect(panel,out settingsPanel); GetWindowRect(GetDlgItem(panel,9110),out saveButton);
                Check(saveButton.top>=settingsPanel.top && saveButton.bottom<=settingsPanel.bottom,"settings remain reachable by scrolling a short window at high DPI");
                Click(panel,9111); SetWindowPos(frame,IntPtr.Zero,20,20,1800,1250,0x14); Pump(100);
                IntPtr canvas=FindWindowEx(frame,IntPtr.Zero,"SUMATRA_PDF_CANVAS",null);
                Rect before, after, side;GetWindowRect(canvas,out before);GetWindowRect(panel,out side);
                Check(canvas!=IntPtr.Zero && before.right<=side.left+2,"sidebar reserves document space without covering the page");
                Click(panel,9100);
                GetWindowRect(canvas,out after);
                Check(!IsWindowVisible(panel) && after.right>before.right,"collapsing sidebar returns space to the document");
                Command(frame,"[CmdDeepSeekPanel]");
                Click(panel,9120); Choose(panel,9131,0);
                Click(panel,9150);
                Check(IsWindowVisible(floating),"floating mode can be reused after history and summary workflows");
                // CmdCloseCurrentDocument exits on the last document; CmdClose keeps Home open.
                Command(frame,"[CmdClose]");
                Check(!process.HasExited && Find(process.Id)==frame,"closing the last document keeps the Home window alive");
                Check(Read(panel,9145).Contains("In this scope: 0 lookups") && Read(panel,9145).Contains("Open a document"),
                    "closing a document refreshes its statistics after the engine is removed");
                Click(panel,9118);
                Check(Read(panel,9101)=="" && Read(panel,9104)=="" && Read(panel,9102)=="","closing document clears its selection context and answer");
                Check(Read(panel,9147)=="" && !IsWindowEnabled(GetDlgItem(panel,9147)),"closing the document resets and disables the follow-up input");
                Check(!IsWindowEnabled(GetDlgItem(panel,9153)) && !IsWindowEnabled(GetDlgItem(panel,9159)),"closing a PDF disables current-book rating and archive actions");
                Check(!IsWindowVisible(GetDlgItem(panel,9139)) && IsWindowVisible(GetDlgItem(panel,9101)),"closing a document does not show onboarding again");
                Check(GetClipboardSequenceNumber()==clipboardSequence,"clipboard stays unchanged for the complete workflow");
                // Open a second isolated reader to verify persisted settings and history are read from disk.
                var emptyInfo=new ProcessStartInfo(args[0],"-appdata \""+settings+"\" -new-window") {
                    UseShellExecute=false,CreateNoWindow=true,WindowStyle=ProcessWindowStyle.Hidden
                };
                using(var reopened=Process.Start(emptyInfo)) {
                    IntPtr second=IntPtr.Zero;
                    try {
                        var retry=Stopwatch.StartNew();
                        while(second==IntPtr.Zero && retry.ElapsedMilliseconds<15000 && !reopened.HasExited) { second=Find(reopened.Id); Pump(100); }
                        Check(second!=IntPtr.Zero,"reader can reopen with the saved profile");
                        ShowWindow(second,4);
                        SetWindowPos(second,IntPtr.Zero,20,20,1800,1250,0x14); Pump(400);
                        var otherHost=Find(reopened.Id,"DeepReaderFloatingPanel");
                        var other=FindWindowEx(otherHost,IntPtr.Zero,"SumatraDeepSeekPanel",null);
                        Check(otherHost!=IntPtr.Zero && GetWindow(otherHost,4)==second && IsWindowVisible(otherHost),"restart restores the floating mode in a window owned by the new reader");
                        Rect restoredBounds; GetWindowRect(otherHost,out restoredBounds);
                        Check(Math.Abs((restoredBounds.right-restoredBounds.left)*96.0/GetDpiForWindow(otherHost)-savedFloatWidth)<=1 &&
                            Math.Abs((restoredBounds.bottom-restoredBounds.top)*96.0/GetDpiForWindow(otherHost)-savedFloatHeight)<=1,
                            "floating dimensions survive restarting the reader");
                        Check(IsWindowVisible(other) && !IsWindowVisible(GetDlgItem(other,9139)),"restart shows the sidebar without repeating onboarding");
                        Check(Read(other,9112)=="DeepReader" && Read(other,9118)=="Lookup","English preference survives restart");
                        int selectedHeight=Height(other,9101), answerHeight=Height(other,9102);
                        Check(Math.Abs(selectedHeight*100.0/(selectedHeight+answerHeight)-65)<1,"selected/explanation ratio survives restart");
                        Click(other,9150); GetWindowRect(other,out restoredBounds);
                        Check(GetParent(other)==second && Math.Abs((restoredBounds.right-restoredBounds.left)*96.0/GetDpiForWindow(second)-500)<=1,
                            "docking after restart restores the independently saved sidebar width");
                        Shot(second,Path.GetFullPath("artifacts/deepreader-empty-start.png"));
                        Click(other,9119);
                        Check(Read(other,9127).Contains("银行"),"query history survives restart");
                        Click(other,9152);
                        Check(Read(other,9163).Contains("Finished: 1") && Read(other,9165).Contains("OFFLINE_BOOK_SUMMARY"),
                            "book ratings, completion and saved summaries survive restarting the reader");
                        Click(other,9166); Pump(500);
                        Check(Read(other,9160).Contains(Path.GetFileName(pdf)),"Open book loads the selected book from the reading list");
                        Command(second,"[Open(\""+archivedPdf+"\")]");
                        Check(Read(other,9158)=="Finished" && Convert.ToInt32(BookData(settings)["rating"])==4,
                            "opening the archive restores the same book state without a duplicate entry");
                        Command(second,"[Open(\""+pdf+"\")]");
                        Command(second,"[Search(\""+pdf+"\",\"bank approved a loan\")]");
                        Command(second,"[CmdDeepSeekExplain]"); Click(other,9111);
                        Check(Read(other,9105)=="Unhighlight","saved highlight is recognized after restarting the reader");
                        Click(other,9105); Click(other,9144); Pump(700);
                        Check(Read(other,9105)=="Highlight" && Read(other,9103).Contains("saved to the PDF"),"unhighlight can be saved back to the PDF");
                        File.Copy(pdf,Path.GetFullPath("artifacts/highlight-removed.pdf"),true);
                        var oldHistory=new Dictionary<string,object> {
                            {"Schema",1},{"id","33333333-3333-3333-3333-333333333333"},{"time",DateTime.Now.AddDays(-10).ToString("yyyy-MM-ddTHH:mm:sszzz")},
                            {"file",Path.Combine(settings,"legacy-history-book.pdf")},{"title","Legacy synthetic reading record"},
                            {"selected","earlier word"},{"context","earlier synthetic reading context"},{"answer","saved offline explanation"},
                            {"kind","explain"},{"provider","Fixture"},{"model","offline-fixture"},{"language","en"},{"page",1}
                        };
                        File.WriteAllText(Path.Combine(settings,"AIHistory",(string)oldHistory["id"]+".json"),new JavaScriptSerializer().Serialize(oldHistory),new UTF8Encoding(false));
                        Click(other,9152);
                        Check(Read(other,9163).Contains("Books: 2") && Read(other,9163).Contains("Reading: 1") && Read(other,9163).Contains("Finished: 1"),
                            "existing history seeds older PDFs into Books without inventing a finished state or rating");
                        Click(other,9150);
                        PostMessage(second,0x10,IntPtr.Zero,IntPtr.Zero);
                        Check(reopened.WaitForExit(4000) && reopened.ExitCode==0 && !IsWindow(otherHost),"closing the reader with a floating panel exits cleanly without an orphan window");
                    } finally {
                        if(second!=IntPtr.Zero) PostMessage(second,0x10,IntPtr.Zero,IntPtr.Zero);
                        if(!reopened.WaitForExit(4000)) reopened.Kill();
                    }
                }
                return 0;
            } catch(Exception e) {Console.WriteLine("FAIL: "+e);return 1;}
            finally {
                if(frame!=IntPtr.Zero) PostMessage(frame,0x10,IntPtr.Zero,IntPtr.Zero);
                if(!process.WaitForExit(4000)) process.Kill();
                if(File.Exists(keyFile)) File.Delete(keyFile);
                if(File.Exists(aiConfig)) File.Delete(aiConfig);
            }
        }
    }
}
