using System;
using System.Drawing;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace SumatraDeepSeek {
    public static class Style {
        public static readonly Color Ink = Color.FromArgb(31, 46, 60);
        public static readonly Color Muted = Color.FromArgb(99, 113, 128);
        public static readonly Color Blue = Color.FromArgb(45, 96, 210);
        public static void Form(Form form) {
            form.Font = new Font("Microsoft YaHei UI", 10);
            form.BackColor = Color.FromArgb(247, 249, 252);
            form.ForeColor = Ink;
            form.AutoScaleMode = AutoScaleMode.None;
            form.StartPosition = FormStartPosition.CenterScreen;
            form.ShowIcon = false;
        }
        public static Label Label(string text, float size, Color color) {
            return new Label { Text = text, AutoSize = true, Font = new Font("Microsoft YaHei UI", size), ForeColor = color, Margin = new Padding(0,0,0,10) };
        }
        public static Button Button(string text, bool primary) {
            var button = new Button { Text = text, AutoSize = true, Padding = new Padding(12,5,12,5), FlatStyle = FlatStyle.Flat,
                BackColor = primary ? Blue : Color.White, ForeColor = primary ? Color.White : Ink, Cursor = Cursors.Hand, Margin = new Padding(0,0,10,0) };
            button.FlatAppearance.BorderColor = primary ? Blue : Color.FromArgb(208,217,228);
            return button;
        }
        public static TextBox Text(bool multiline) {
            return new TextBox { Multiline = multiline, BorderStyle = BorderStyle.FixedSingle, BackColor = Color.White,
                ForeColor = Ink, Dock = DockStyle.Fill, ScrollBars = multiline ? ScrollBars.Vertical : ScrollBars.None };
        }
        public static float DpiScale = GetDpiScale();
        static float GetDpiScale() { using (Graphics g = Graphics.FromHwnd(IntPtr.Zero)) return g.DpiX / 96f; }
        public static void Scale(Form form) { form.Scale(new SizeF(DpiScale,DpiScale)); }
    }

    public sealed class SetupForm : Form {
        readonly Config config;
        readonly TextBox key = Style.Text(false);
        readonly TextBox model = Style.Text(false);
        readonly TextBox settings = Style.Text(false);
        public bool Saved;
        public SetupForm(Config value, bool settingsOnly) {
            config = value;
            Style.Form(this);
            Text = "Sumatra · DeepSeek 阅读助手设置";
            ClientSize = new Size(630, settingsOnly ? 315 : 565);
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = false;
            var panel = new TableLayoutPanel { Dock = DockStyle.Fill, Padding = new Padding(24), ColumnCount = 1, RowCount = 0 };
            panel.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100));
            Controls.Add(panel);
            Action<Control, int> add = delegate(Control control, int height) {
                panel.RowCount++; panel.RowStyles.Add(new RowStyle(SizeType.Absolute,height));
                control.Dock = DockStyle.Fill; panel.Controls.Add(control,0,panel.RowCount-1);
            };
            add(Style.Label("读懂此处含义", 19, Style.Ink),42);
            add(Style.Label("在 PDF 中选中文字，按 Ctrl + Alt + D。",10,Style.Muted),32);
            add(Style.Label("DeepSeek API Key",10,Style.Ink),25);
            key.UseSystemPasswordChar = true;
            key.Text = "";
            add(key,34);
            bool existing = false;
            try { existing = !String.IsNullOrWhiteSpace(config.Key()); } catch { }
            add(Style.Label(existing ? "已有密钥；留空保留。新密钥将用当前 Windows 账户加密保存。" : "输入后保存在本机。API 调用使用 DeepSeek API 余额。",9,Style.Muted),32);
            var modelRow = new TableLayoutPanel { ColumnCount = 2, Dock = DockStyle.Fill, Margin = new Padding(0) };
            modelRow.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute,75));
            modelRow.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100));
            modelRow.Controls.Add(Style.Label("模型",10,Style.Ink),0,0);
            model.Text = config.Model;
            modelRow.Controls.Add(model,1,0);
            add(modelRow,34);
            var saveRow = new FlowLayoutPanel { FlowDirection = FlowDirection.LeftToRight, Margin = new Padding(0,8,0,0) };
            var save = Style.Button("保存设置", true);
            save.Click += delegate {
                try {
                    if (!String.IsNullOrWhiteSpace(key.Text)) config.SetKey(key.Text);
                    if (String.IsNullOrWhiteSpace(config.Key())) throw new UserError("请填写 DeepSeek API Key。密钥只需在此窗口输入。");
                    if (String.IsNullOrWhiteSpace(model.Text) || model.Text.Trim().IndexOfAny(new char[] {'\r','\n',' '}) >= 0)
                        throw new UserError("请填写有效的模型名称，例如 deepseek-flash。");
                    config.Model = model.Text.Trim(); config.Save(); key.Clear(); Saved = true;
                    if (settingsOnly) { DialogResult = DialogResult.OK; Close(); }
                    else MessageBox.Show(this,"设置已保存。可以接入 SumatraPDF 后开始阅读。","已保存",MessageBoxButtons.OK,MessageBoxIcon.Information);
                } catch (Exception ex) { ShowError(ex); }
            };
            saveRow.Controls.Add(save);
            var getKey = Style.Button("获取 API Key", false);
            getKey.Click += delegate { System.Diagnostics.Process.Start("https://platform.deepseek.com/api_keys"); };
            saveRow.Controls.Add(getKey);
            add(saveRow,50);
            if (!settingsOnly) {
                add(new Label { Text = "接入 SumatraPDF", Font = new Font(Font,FontStyle.Bold), TextAlign = ContentAlignment.BottomLeft },37);
                add(Style.Label("先关闭 SumatraPDF。便携版可选择同目录的设置文件。",9,Style.Muted),30);
                var settingsRow = new TableLayoutPanel { ColumnCount = 2, Dock = DockStyle.Fill, Margin = new Padding(0) };
                settingsRow.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100));
                settingsRow.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute,68));
                settings.Text = Integration.DefaultSettings;
                settingsRow.Controls.Add(settings,0,0);
                var browse = Style.Button("选择",false);
                browse.Padding = new Padding(0); browse.Margin = new Padding(5,0,0,0);
                browse.Click += delegate {
                    using (var dialog = new OpenFileDialog { Filter = "Sumatra 设置|SumatraPDF-settings.txt|文本文件|*.txt", FileName = "SumatraPDF-settings.txt" }) {
                        if (dialog.ShowDialog(this) == DialogResult.OK) settings.Text = dialog.FileName;
                    }
                };
                settingsRow.Controls.Add(browse,1,0); add(settingsRow,34);
                var installRow = new FlowLayoutPanel { Margin = new Padding(0,8,0,0) };
                var install = Style.Button("接入 SumatraPDF",true);
                var uninstall = Style.Button("移除接入",false);
                install.Click += delegate { Apply(false); };
                uninstall.Click += delegate { Apply(true); };
                installRow.Controls.Add(install); installRow.Controls.Add(uninstall); add(installRow,50);
                add(Style.Label("每次仅发送选文及附近段落给 DeepSeek。程序不保存阅读记录。\r\n完整解压并保留整个文件夹；移动后需要重新接入。",9,Style.Muted),55);
            }
            Style.Scale(this);
        }
        void Apply(bool remove) {
            try { MessageBox.Show(this,Integration.Apply(settings.Text.Trim(),remove),"SumatraPDF",MessageBoxButtons.OK,MessageBoxIcon.Information); }
            catch (Exception ex) { ShowError(ex); }
        }
        void ShowError(Exception ex) { MessageBox.Show(this,ex is UserError ? ex.Message : "无法保存设置，请检查文件夹写入权限。","设置提示",MessageBoxButtons.OK,MessageBoxIcon.Warning); }
    }

    public sealed class ReaderForm : Form {
        readonly string file;
        readonly int page;
        readonly string selected;
        readonly Config config;
        readonly DeepSeekClient api;
        readonly CancellationTokenSource lifetime = new CancellationTokenSource();
        readonly TextBox source = Style.Text(true);
        readonly TextBox context = Style.Text(true);
        readonly TextBox answer = Style.Text(true);
        readonly ComboBox choices = new ComboBox { DropDownStyle = ComboBoxStyle.DropDownList, Dock = DockStyle.Fill };
        readonly Label status = Style.Label("正在定位上下文…",9,Style.Muted);
        readonly Button explain = Style.Button("解释",true);
        readonly Button copy = Style.Button("复制解释",false);
        readonly Button settingsButton = Style.Button("设置",false);
        readonly CheckBox inspect = new CheckBox { Text = "查看 / 补充上下文", AutoSize = true, ForeColor = Style.Muted, Margin = new Padding(0,7,0,0) };
        readonly TableLayoutPanel layout;
        bool busy;
        bool ready;
        public ReaderForm(string document, int currentPage, string selection, Config settings, DeepSeekClient client) {
            file = document; page = currentPage; selected = selection; config = settings; api = client;
            Style.Form(this);
            Text = "DeepSeek · 此处怎么理解";
            ClientSize = new Size(660,515);
            MinimumSize = new Size(600,530);
            KeyPreview = true;
            KeyDown += delegate(object sender,KeyEventArgs e) { if (e.KeyCode == Keys.Escape) { e.Handled = true; Close(); } };
            layout = new TableLayoutPanel { Dock = DockStyle.Fill, Padding = new Padding(24), ColumnCount = 1, RowCount = 9 };
            layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent,100));
            foreach (int height in new int[] {40,26,74,36,28,0,30,0,54})
                layout.RowStyles.Add(new RowStyle(height == 0 && layout.RowStyles.Count == 7 ? SizeType.Percent : SizeType.Absolute,
                    height == 0 && layout.RowStyles.Count == 7 ? 100 : height));
            Controls.Add(layout);
            layout.Controls.Add(Style.Label("此处怎么理解",19,Style.Ink),0,0);
            layout.Controls.Add(Style.Label(Path.GetFileName(file) + " · 第 " + page + " 页",9,Style.Muted),0,1);
            source.ReadOnly = true; source.Text = selection; source.Margin = new Padding(0,0,0,10);
            layout.Controls.Add(source,0,2);
            choices.Margin = new Padding(0,0,0,8); layout.Controls.Add(choices,0,3);
            choices.DrawMode = DrawMode.OwnerDrawFixed;
            choices.ItemHeight = (int)(22 * Style.DpiScale);
            choices.DrawItem += delegate(object sender,DrawItemEventArgs e) {
                e.DrawBackground();
                string label = e.Index >= 0 ? choices.Items[e.Index].ToString() : "请选择正确的上下文…";
                TextRenderer.DrawText(e.Graphics,label,choices.Font,e.Bounds,e.ForeColor,
                    TextFormatFlags.VerticalCenter | TextFormatFlags.EndEllipsis | TextFormatFlags.SingleLine);
                e.DrawFocusRectangle();
            };
            layout.Controls.Add(inspect,0,4);
            context.MaxLength = 3000; context.Margin = new Padding(0,0,0,10);
            layout.Controls.Add(context,0,5);
            layout.Controls.Add(status,0,6);
            status.Dock = DockStyle.Fill;
            status.AutoSize = false;
            answer.ReadOnly = true; answer.Font = new Font("Microsoft YaHei UI",12);
            answer.Margin = new Padding(0,0,0,12); layout.Controls.Add(answer,0,7);
            var buttons = new FlowLayoutPanel { Dock = DockStyle.Fill, Margin = new Padding(0) };
            buttons.Controls.Add(explain); buttons.Controls.Add(copy); buttons.Controls.Add(settingsButton);
            buttons.Controls.Add(Style.Label("Esc 返回阅读",9,Style.Muted)); layout.Controls.Add(buttons,0,8);
            explain.Enabled = false; copy.Enabled = false;
            choices.SelectedIndexChanged += delegate {
                if (busy) return;
                var candidate = choices.SelectedItem as ContextCandidate;
                if (candidate != null) {
                    context.Text = candidate.text;
                    answer.Clear(); copy.Enabled = false;
                    status.Text = "已定位第 " + candidate.page + " 页语境，点击解释。";
                    ready = true; explain.Enabled = true;
                }
            };
            inspect.CheckedChanged += delegate {
                layout.RowStyles[5].Height = inspect.Checked ? 115 * Style.DpiScale : 0;
                ClientSize = new Size(ClientSize.Width, (int)((inspect.Checked ? 630 : 515) * Style.DpiScale));
            };
            context.TextChanged += delegate {
                if (!busy) {
                    ready = !String.IsNullOrWhiteSpace(context.Text);
                    explain.Enabled = ready;
                    answer.Clear(); copy.Enabled = false;
                }
            };
            explain.Click += async delegate { await Explain(); };
            copy.Click += delegate { try { Clipboard.SetText(answer.Text); status.Text = "解释已复制。"; } catch { status.Text = "剪贴板正忙，请重试。"; } };
            settingsButton.Click += delegate { using (var form = new SetupForm(config,true)) form.ShowDialog(this); };
            FormClosed += delegate { lifetime.Cancel(); api.Dispose(); };
            Style.Scale(this);
        }
        public async Task Initialize() {
            busy = true;
            try {
                ContextResult result = await PdfContext.Read(file,page,selected,lifetime.Token);
                if (IsDisposed) return;
                busy = false;
                choices.Items.Clear();
                foreach (var candidate in result.candidates) choices.Items.Add(candidate);
                if (result.candidates.Count == 1) {
                    choices.SelectedIndex = 0;
                    await Explain();
                } else if (result.candidates.Count > 1) {
                    status.Text = result.truncated ? "出现较多段落：请选择语境，或改选完整句子。" : "选文出现于多个段落，请选择正确语境。";
                    choices.Focus(); choices.DroppedDown = true;
                } else {
                    inspect.Checked = true;
                    status.Text = result.warning;
                    context.Focus();
                }
            } catch (OperationCanceledException) { }
            catch (Exception ex) {
                if (!IsDisposed) { busy = false; inspect.Checked = true; status.Text = ex is UserError ? ex.Message : "无法读取上下文，请粘贴附近段落。"; }
            }
        }
        async Task Explain() {
            if (busy || !ready) return;
            try {
                if (String.IsNullOrWhiteSpace(config.Key())) {
                    using (var settings = new SetupForm(config,true)) {
                        if (settings.ShowDialog(this) != DialogResult.OK) { status.Text = "填写 API Key 后即可解释。"; return; }
                    }
                }
                busy = true; explain.Enabled = false; copy.Enabled = false; choices.Enabled = false;
                context.ReadOnly = true; settingsButton.Enabled = false;
                answer.Clear(); status.Text = "正在结合上下文解释…";
                string result = await api.Explain(config,selected,context.Text,lifetime.Token);
                if (IsDisposed) return;
                answer.Text = result;
                status.Text = "解释依据当前选定的语境。";
                copy.Enabled = true;
            } catch (OperationCanceledException) { }
            catch (Exception ex) {
                if (!IsDisposed) { status.Text = ex is UserError ? ex.Message : "解释失败，请重试。"; }
            } finally {
                busy = false;
                if (!IsDisposed) { explain.Enabled = ready; choices.Enabled = true; context.ReadOnly = false; settingsButton.Enabled = true; }
            }
        }
        public void Preview(string path) {
            context.Text = "The bank approved a loan to help the company expand its business.";
            answer.Text = "这里的 bank 指“银行”，因为它在审批贷款。整句意思是：银行批准了一笔贷款，帮助这家公司扩展业务。";
            choices.Items.Add(new ContextCandidate { page = 12, text = context.Text, label = "第 12 页 · The bank approved a loan…" });
            busy = true; choices.SelectedIndex = 0; busy = false;
            status.Text = "解释依据当前选定的语境。"; explain.Enabled = true; copy.Enabled = true;
            Show(); Application.DoEvents();
            using (var bitmap = new Bitmap(Width,Height)) { DrawToBitmap(bitmap,new Rectangle(0,0,Width,Height)); bitmap.Save(path,System.Drawing.Imaging.ImageFormat.Png); }
            Close();
        }
    }
}
