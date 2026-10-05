using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows.Forms;

namespace SumatraDeepSeek {
    public static class Program {
        [DllImport("user32.dll")] static extern bool SetProcessDPIAware();
        [STAThread]
        public static int Main(string[] args) {
            try {
                SetProcessDPIAware();
                Application.EnableVisualStyles();
                Application.SetCompatibleTextRenderingDefault(false);
                System.Net.ServicePointManager.SecurityProtocol = System.Net.SecurityProtocolType.Tls12;
                if (args.Length > 0 && args[0] == "--self-test") return SelfTests.Run(args.Length > 1 ? args[1] : null);
                if (args.Length > 0 && args[0] == "--preview") {
                    using (var form = new ReaderForm("reading-example.pdf",12,"bank",new Config(),new DeepSeekClient()))
                        form.Preview(Path.GetFullPath(args[1]));
                    return 0;
                }
                if (args.Length > 0 && (args[0] == "--install" || args[0] == "--uninstall")) {
                    string settings = args.Length > 1 ? args[1] : Integration.DefaultSettings;
                    string result = Integration.Apply(settings,args[0] == "--uninstall");
                    WriteStatus(args,result); return 0;
                }
                Config config = Config.Load();
                if (args.Length == 0 || args[0] == "--settings") {
                    Application.Run(new SetupForm(config,false)); return 0;
                }
                if (args.Length != 4 || args[0] != "--file" || args[2] != "--page")
                    throw new UserError("启动参数无效。请从 SumatraPDF 按 Ctrl + Alt + D 启动解释，或双击程序打开设置。");
                int page;
                if (!Int32.TryParse(args[3],out page) || page < 1) throw new UserError("当前 PDF 页码无效。");
                string selected = Selection.Capture();
                using (var form = new ReaderForm(args[1],page,selected,config,new DeepSeekClient())) {
                    form.Shown += async delegate { await form.Initialize(); };
                    Application.Run(form);
                }
                return 0;
            } catch (Exception ex) {
                string message = ex is UserError ? ex.Message : "插件运行失败，请检查完整文件夹和写入权限后重试。";
                if (args.Length > 0 && (args[0] == "--self-test" || Array.IndexOf(args,"--status-file") >= 0)) WriteStatus(args,message);
                else MessageBox.Show(message,"DeepSeek 阅读助手",MessageBoxButtons.OK,MessageBoxIcon.Warning);
                return 1;
            }
        }
        static void WriteStatus(string[] args, string text) {
            int i = Array.IndexOf(args,"--status-file");
            if (i >= 0 && i + 1 < args.Length) File.WriteAllText(args[i+1],text,new UTF8Encoding(false));
            else Console.WriteLine(text);
        }
    }
}
