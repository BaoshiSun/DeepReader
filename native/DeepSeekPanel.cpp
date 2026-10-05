// SPDX-License-Identifier: AGPL-3.0-or-later
#include "utils/BaseUtil.h"
#include "utils/WinUtil.h"
#include "utils/Dpi.h"
#include "wingui/UIModels.h"
#include "Settings.h"
#include "DocController.h"
#include "EngineBase.h"
#include "EngineAll.h"
#include "Annotation.h"
#include "DisplayModel.h"
#include "TextSelection.h"
#include "MainWindow.h"
#include "WindowTab.h"
#include "EditAnnotations.h"
#include "Selection.h"
#include "SumatraPDF.h"
#include "AppTools.h"
#include "DeepSeekPanel.h"
#include "DeepSeekCore.h"
#include "ReadingLibrary.h"
#include "ReaderHighlights.h"
#include <winhttp.h>
#include <commdlg.h>
#include <atomic>
#include <memory>
#include <string>
#include <vector>
#include <algorithm>

bool SaveAnnotationsToExistingFile(WindowTab* tab);

namespace {
using namespace deepseek;
constexpr const WCHAR* kPanelClass = L"SumatraDeepSeekPanel";
constexpr const WCHAR* kPanelProperty = L"Sumatra.DeepSeek.Panel";
constexpr UINT kRefreshDocument = WM_APP+17;
enum { Close = 9100, Selected, Answer, Status, ContextView, ContextToggle, Retry, Settings,
       KeyInput, ModelInput, Save, Back, Title, SelectedLabel, KeyLabel, ModelLabel, Privacy,
       Language, LookupTab, HistoryTab, SummaryTab, ProviderInput, ProviderLabel, ModelHint, KeyLink,
       HistorySearch, HistoryList, HistoryDetail, HistoryExport, HistoryDelete, HistoryInfo,
       SummaryScope, SummaryDate, SummaryLabel, SummaryInfo, SummaryPrepare, SummaryRun, SummaryAnswer,
       SummaryExport, Intro, Configure, DismissIntro, LookupSplitter, ShowGuide, SaveHighlights, SummaryStats, AnswerLabel,
       FollowupInput, FollowupSend, FollowupLabel };
enum class View { Lookup, History, Summary, Preferences };
struct Job {
    std::atomic<bool> stopped{false}, done{false};
    std::atomic<int> completed{0};
    int total = 1;
    Config config;
    std::string key;
    Task task = Task::Explain;
    std::wstring selected, stats, question;
    std::vector<std::wstring> parts;
    Result result;
    Record record;
};
struct Panel {
    MainWindow* win = nullptr;
    HWND hwnd = nullptr;
    HFONT font = nullptr, titleFont = nullptr;
    bool open = true, ownedByWindow = false, extracting = false, layingOut = false;
    bool showIntro = false, dragging = false, highlighted = false, savingAnnotations = false;
    int scrollY = 0, splitTop = 0, splitAvailable = 1;
    View view = View::Lookup, returnView = View::Lookup;
    std::wstring selected, context, file, configPath, historyDir, extraction, summaryInfo;
    int page = 0, extractPage = 0, extractTotal = 0, blankPages = 0;
    Config config, editing, preparedConfig;
    std::shared_ptr<Job> job;
    std::vector<Record> history;
    std::vector<size_t> shownHistory;
    std::vector<std::wstring> prepared;
    Record summaryRecord, lookupRecord;
    std::wstring summaryResult, summaryStats, preparedStats;
    std::vector<HighlightPart> highlightParts;
    std::string highlightId;
};
Panel* Get(MainWindow* win) { return (Panel*)GetPropW(win->hwndFrame, kPanelProperty); }
HWND Item(Panel* p, int id) { return GetDlgItem(p->hwnd, id); }
const wchar_t* L(Panel* p, const wchar_t* zh, const wchar_t* en) { return p->config.english ? en : zh; }
void Text(Panel* p, int id, const std::wstring& text) {
    // Native multiline Edit controls need CRLF, while API responses normally use LF.
    std::wstring display;
    display.reserve(text.size()+16);
    for (size_t i=0;i<text.size();++i) {
        if (text[i]=='\n' && (i==0 || text[i-1]!='\r')) display+='\r';
        display+=text[i];
    }
    SetWindowTextW(Item(p,id),display.c_str());
}
std::wstring Text(HWND edit) {
    int len=GetWindowTextLengthW(edit);
    std::wstring text(len+1,0); GetWindowTextW(edit,text.data(),len+1); text.resize(len); return text;
}
int Choice(Panel* p, int id) { return (int)SendMessageW(Item(p,id),CB_GETCURSEL,0,0); }
std::wstring CurrentFile(Panel* p) {
    auto tab=p->win->CurrentTab();
    return tab && tab->filePath ? Wide(tab->filePath) : L"";
}
void Layout(Panel* p);
void Labels(Panel* p);
void HistoryView(Panel* p);
void SettingsView(Panel* p, bool show);
bool LookupTask(Task task) { return task==Task::Explain || task==Task::Followup; }
void FollowupUI(Panel* p) {
    bool following=p->job && p->job->task==Task::Followup;
    bool hasAnswer=!p->lookupRecord.answer.empty();
    bool full=p->lookupRecord.answer.size()>FollowupConversationLimit;
    Text(p,FollowupLabel,L(p,!hasAnswer?L"追问 · 先生成解释":full?L"追问 · 请重新解释，开始新对话":L"追问 · Ctrl + Enter 发送",
        !hasAnswer?L"Follow-up · Get an explanation first":full?L"Follow-up · Start a fresh explanation":L"Follow-up · Ctrl + Enter to send"));
    Text(p,FollowupSend,following?L(p,L"停止",L"Stop"):L(p,L"发送",L"Send"));
    EnableWindow(Item(p,FollowupInput),!p->selected.empty());
    SendMessageW(Item(p,FollowupInput),EM_SETREADONLY,following,0);
    EnableWindow(Item(p,FollowupSend),following || (!p->job && CanFollowup(p->lookupRecord.answer,Text(Item(p,FollowupInput)))));
}
void HighlightUI(Panel* p) {
    auto dm=p->win->AsFixed();
    auto engine=dm?dm->GetEngine():nullptr;
    bool can=engine && !p->highlightParts.empty() && CurrentFile(p)==p->file &&
        HasPermission(Perm::DiskAccess) && !AnnotationsAreDisabled() && EngineSupportsAnnotations(engine);
    p->highlighted=can && ReaderHasHighlight(engine,p->highlightParts,p->highlightId);
    Text(p,ContextToggle,p->highlighted?L(p,L"取消高亮",L"Unhighlight"):L(p,L"高亮",L"Highlight"));
    EnableWindow(Item(p,ContextToggle),can);
    EnableWindow(Item(p,SaveHighlights),engine && HasPermission(Perm::DiskAccess) && EngineHasUnsavedAnnotations(engine));
}
void ToggleHighlight(Panel* p) {
    HighlightUI(p);
    if (!IsWindowEnabled(Item(p,ContextToggle))) return;
    auto engine=p->win->AsFixed()->GetEngine();
    bool next=!p->highlighted;
    bool ok=ReaderSetHighlight(engine,p->highlightParts,p->highlightId,Utf8(p->selected),next);
    auto tab=p->win->CurrentTab();
    SetSelectedAnnotation(tab,nullptr);
    UpdateAnnotationsList(tab->editAnnotsWindow);
    MainWindowRerender(p->win);
    HighlightUI(p);
    Text(p,Status,ok ? L(p,next?L"已添加高亮。点击“保存批注”写入 PDF。":L"已取消高亮。点击“保存批注”写入 PDF。",
        next?L"Highlight added. Save annotations to write the PDF.":L"Highlight removed. Save annotations to write the PDF.") :
        L(p,L"未能修改高亮；请检查文件是否支持批注。",L"Could not change the highlight. Check annotation support."));
}
void SaveHighlightsToPdf(Panel* p) {
    auto tab=p->win->CurrentTab();
    if (!tab || !HasPermission(Perm::DiskAccess)) return;
    HWND frame=p->win->hwndFrame;
    p->savingAnnotations=true;
    bool ok=SaveAnnotationsToExistingFile(tab);
    if (GetPropW(frame,kPanelProperty)!=p) return;
    p->savingAnnotations=false;
    if (CurrentFile(p)!=p->file) { DeepSeekReset(p->win); return; }
    HighlightUI(p);
    Text(p,Status,L(p,ok?L"批注已保存到 PDF。":L"保存失败，批注仍在内存中；请检查文件权限。",
        ok?L"Annotations saved to the PDF.":L"Save failed; annotations remain in memory. Check file permissions."));
}
void SaveSplit(Panel* p) {
    if (!HasPermission(Perm::SavePreferences)) return;
    Config latest=p->config; ReadConfig(p->configPath,latest);
    latest.lookupSplit=p->config.lookupSplit;
    if (!SaveConfig(p->configPath,latest)) Text(p,Status,L(p,L"比例已调整，但无法保存设置。",L"Layout changed, but settings could not be saved."));
    p->editing.lookupSplit=p->config.lookupSplit;
}
LRESULT CALLBACK SplitterProc(HWND hwnd,UINT msg,WPARAM wp,LPARAM lp) {
    auto p=(Panel*)GetWindowLongPtrW(hwnd,GWLP_USERDATA);
    if (msg==WM_NCCREATE) { p=(Panel*)((CREATESTRUCTW*)lp)->lpCreateParams; SetWindowLongPtrW(hwnd,GWLP_USERDATA,(LONG_PTR)p); }
    if (!p) return DefWindowProcW(hwnd,msg,wp,lp);
    switch(msg) {
        case WM_GETDLGCODE: return DLGC_WANTARROWS;
        case WM_SETCURSOR: SetCursor(LoadCursorW(nullptr,IDC_SIZENS)); return TRUE;
        case WM_LBUTTONDOWN: SetFocus(hwnd); p->dragging=true; SetCapture(hwnd); return 0;
        case WM_MOUSEMOVE:
            if (p->dragging) {
                POINT pt{(short)LOWORD(lp),(short)HIWORD(lp)}; MapWindowPoints(hwnd,p->hwnd,&pt,1);
                int midpoint=MulDiv(11,DpiGet(p->hwnd),96);
                int ratio=(pt.y+p->scrollY-p->splitTop-midpoint)*100/std::max(1,p->splitAvailable);
                p->config.lookupSplit=std::max(20,std::min(80,ratio)); Layout(p);
            }
            return 0;
        case WM_LBUTTONUP:
            if (p->dragging) { p->dragging=false; ReleaseCapture(); SaveSplit(p); }
            return 0;
        case WM_CAPTURECHANGED:
            if (p->dragging) { p->dragging=false; SaveSplit(p); } return 0;
        case WM_KEYDOWN:
            if (wp==VK_UP || wp==VK_DOWN || wp==VK_HOME) {
                p->config.lookupSplit=wp==VK_HOME?50:std::max(20,std::min(80,p->config.lookupSplit+(wp==VK_UP?-5:5)));
                Layout(p); SaveSplit(p); return 0;
            }
            break;
        case WM_SETFOCUS: case WM_KILLFOCUS: InvalidateRect(hwnd,nullptr,TRUE); return 0;
        case WM_PAINT: {
            PAINTSTRUCT ps; auto dc=BeginPaint(hwnd,&ps); RECT r; GetClientRect(hwnd,&r);
            SetDCBrushColor(dc,GetFocus()==hwnd?RGB(197,233,212):RGB(232,238,235)); FillRect(dc,&r,(HBRUSH)GetStockObject(DC_BRUSH));
            SetTextColor(dc,RGB(65,108,80)); SetBkMode(dc,TRANSPARENT); SelectObject(dc,p->font);
            DrawTextW(dc,L(p,L"⋯ 拖动调整 ⋯",L"⋯ Drag to resize ⋯"),-1,&r,DT_CENTER|DT_VCENTER|DT_SINGLELINE);
            EndPaint(hwnd,&ps); return 0;
        }
    }
    return DefWindowProcW(hwnd,msg,wp,lp);
}
void Cancel(Panel* p) {
    if (p->job) p->job->stopped=true;
    p->job.reset(); KillTimer(p->hwnd,1); KillTimer(p->hwnd,2);
    p->extracting=false; p->extraction.clear();
    Text(p,Retry,L(p,L"重新解释",L"Explain again"));
    Text(p,SummaryRun,L(p,L"生成总结",L"Generate"));
    Text(p,SummaryPrepare,L(p,L"准备材料",L"Prepare"));
    FollowupUI(p);
}
struct Internet {
    HINTERNET handle;
    explicit Internet(HINTERNET h) : handle(h) {}
    ~Internet() { if (handle) WinHttpCloseHandle(handle); }
};
Result Call(const std::shared_ptr<Job>& job, Task task, const std::wstring& source) {
    Result failure{false,job->config.english ? L"Network request failed or timed out. Please retry." : L"网络请求失败或超时，请检查网络后重试。",""};
    std::wstring metadata;
    if (task==Task::Review || task==Task::Document)
        metadata=L"[Requested scope: "+Wide(job->record.kind)+L"; "+job->record.title+L"; "+job->record.context+L"]\n";
    std::string body=RequestBody(job->config,task,metadata+source,LookupTask(task)?job->selected:L"",job->record.answer,job->question);
    if (body.empty()) return failure;
    Internet session(WinHttpOpen(L"DeepReader/1.0.0",WINHTTP_ACCESS_TYPE_AUTOMATIC_PROXY,
        WINHTTP_NO_PROXY_NAME,WINHTTP_NO_PROXY_BYPASS,0));
    if (!session.handle || job->stopped) return failure;
    WinHttpSetTimeouts(session.handle,8000,10000,30000,60000);
    auto endpoint=Service(job->config.provider);
    Internet connection(WinHttpConnect(session.handle,endpoint.host,INTERNET_DEFAULT_HTTPS_PORT,0));
    if (!connection.handle) return failure;
    Internet req(WinHttpOpenRequest(connection.handle,L"POST",endpoint.path,nullptr,WINHTTP_NO_REFERER,WINHTTP_DEFAULT_ACCEPT_TYPES,WINHTTP_FLAG_SECURE));
    if (!req.handle) return failure;
    DWORD disable=WINHTTP_DISABLE_REDIRECTS;
    if (!WinHttpSetOption(req.handle,WINHTTP_OPTION_DISABLE_FEATURE,&disable,sizeof(disable))) return failure;
    std::wstring headers=L"Content-Type: application/json\r\nAuthorization: Bearer "+Wide(job->key);
    if (job->stopped) { SecureZeroMemory(headers.data(),headers.size()*sizeof(WCHAR)); return failure; }
    BOOL sent=WinHttpSendRequest(req.handle,headers.c_str(),(DWORD)headers.size(),body.data(),(DWORD)body.size(),(DWORD)body.size(),0);
    SecureZeroMemory(headers.data(),headers.size()*sizeof(WCHAR));
    if (!sent || job->stopped || !WinHttpReceiveResponse(req.handle,nullptr)) return failure;
    DWORD status=0,size=sizeof(status);
    if (!WinHttpQueryHeaders(req.handle,WINHTTP_QUERY_STATUS_CODE|WINHTTP_QUERY_FLAG_NUMBER,WINHTTP_HEADER_NAME_BY_INDEX,&status,&size,WINHTTP_NO_HEADER_INDEX)) return failure;
    std::string data; ULONGLONG start=GetTickCount64();
    while (!job->stopped) {
        char buffer[4096]; DWORD n=0;
        if (!WinHttpReadData(req.handle,buffer,sizeof(buffer),&n)) return failure;
        if (!n) return Response(data,status,job->config.english);
        data.append(buffer,n);
        if (data.size()>262144 || GetTickCount64()-start>120000) return failure;
    }
    return failure;
}
DWORD WINAPI RequestThread(void* value) {
    auto holder=std::unique_ptr<std::shared_ptr<Job>>((std::shared_ptr<Job>*)value);
    auto job=*holder;
    {
        auto run=[&](Task task,const std::wstring& source) {
            job->result=Call(job,task,source);
            ++job->completed;
            return job->result.ok && !job->stopped;
        };
        auto work=[&]() {
            if (job->parts.empty()) return;
            if (job->parts.size()==1) { run(job->task,job->parts[0]); return; }
            std::vector<std::wstring> notes;
            for (size_t i=0;i<job->parts.size();++i) {
                if (job->stopped || !run(Task::Part,job->parts[i])) return;
                if (job->result.text.size()>3500) {
                    job->result={false,job->config.english?L"Intermediate notes were too long. Try another model.":L"分段笔记过长，无法可靠合并，请换一个模型重试。",""}; return;
                }
                notes.push_back(L"[Part "+std::to_wstring(i+1)+L"]\n"+job->result.text);
            }
            while (notes.size()>3) {
                std::vector<std::wstring> reduced;
                for (size_t i=0;i<notes.size();i+=3) {
                    std::wstring group;
                    for (size_t j=i;j<std::min(i+3,notes.size());++j) group+=notes[j]+L"\n\n";
                    if (job->stopped || !run(Task::Merge,group)) return;
                    if (job->result.text.size()>3500) {
                        job->result={false,job->config.english?L"Combined notes were too long. Try another model.":L"合并笔记过长，请换一个模型重试。",""}; return;
                    }
                    reduced.push_back(job->result.text);
                }
                notes=std::move(reduced);
            }
            std::wstring combined=L"[Notes covering all supplied source parts]\n";
            for (const auto& note:notes) combined+=note+L"\n\n";
            if (!job->stopped) run(job->task,combined);
        };
        work();
    }
    SecureZeroMemory(job->key.data(),job->key.size()); job->key.clear();
    job->done=true;
    return 0;
}
void ModelNotice(Panel* p) {
    int provider=p->editing.provider;
    std::string model=Utf8(Text(Item(p,ModelInput)));
    Config check=p->editing; check.models[provider]=model;
    if (FreeModel(check)) Text(p,ModelHint,L(p,L"免费路由 · 需 OpenRouter Key，有调用限额。\r\n额度用尽时停止，不会自动改用付费模型。",L"Free route · OpenRouter key required; usage limits apply.\r\nNo automatic switch to paid models."));
    else if (provider==DeepSeek) Text(p,ModelHint,L(p,L"DeepSeek 官方 API · 需要 DeepSeek Key，按量计费。\r\n直连官方服务，无需 OpenRouter 账号。",L"DeepSeek official · API key required; billed by usage.\r\nDirect connection; no OpenRouter account needed."));
    else if (provider==Gemini) Text(p,ModelHint,L(p,L"是否免费取决于模型和 Google 项目计费设置。\r\n请使用免费层项目，留意其额度与数据政策。",L"Price depends on the model and Google project billing.\r\nUse a free-tier project and check its data policy."));
    else Text(p,ModelHint,L(p,L"付费 / 自定义模型 · 按所选服务价格计费。\r\n模型名称可编辑；请选择账户已开通的模型。",L"Paid / custom model · Provider pricing applies.\r\nModel IDs are editable; select one your key can access."));
}
void FillProvider(Panel* p) {
    int provider=p->editing.provider;
    SendMessageW(Item(p,ProviderInput),CB_SETCURSEL,provider,0);
    SendMessageW(Item(p,ModelInput),CB_RESETCONTENT,0,0);
    for (const auto& model:ModelChoices(provider)) SendMessageW(Item(p,ModelInput),CB_ADDSTRING,0,(LPARAM)model.c_str());
    Text(p,ModelInput,Wide(p->editing.models[provider]));
    Text(p,KeyInput,L"");
    Text(p,KeyLabel,Wide(ProviderName(provider))+L" API Key");
    SendMessageW(Item(p,KeyInput),EM_SETCUEBANNER,TRUE,(LPARAM)(p->editing.keys[provider].empty()
        ? L(p,L"输入此服务的 API Key",L"Enter this provider's API key")
        : L(p,L"已保存，留空保持原密钥",L"Saved; leave blank to keep the key")));
    ModelNotice(p);
}
bool StageSettings(Panel* p) {
    std::string key=Utf8(Text(Item(p,KeyInput))), model=Utf8(Text(Item(p,ModelInput)));
    if (!ValidModel(model)) { Text(p,Privacy,L(p,L"请填写有效的模型 ID。",L"Enter a valid model ID.")); return false; }
    if (!key.empty()) {
        bool valid=ValidKey(key);
        std::string encrypted=valid ? Protect(key) : "";
        SecureZeroMemory(key.data(),key.size());
        if (!valid || encrypted.empty()) { Text(p,Privacy,L(p,L"密钥格式无效或加密失败。",L"Invalid key format or encryption failed.")); return false; }
        p->editing.keys[p->editing.provider]=encrypted;
    }
    p->editing.models[p->editing.provider]=model;
    return true;
}
void SettingsView(Panel* p,bool show) {
    p->scrollY=0;
    if (show) {
        if (p->view!=View::Preferences) p->returnView=p->view;
        ReadConfig(p->configPath,p->config);
        p->editing=p->config;
        p->view=View::Preferences;
        FillProvider(p);
    } else p->view=p->returnView;
    Labels(p); Layout(p);
    SetFocus(show?Item(p,KeyInput):p->win->hwndCanvas);
}
void StartJob(Panel* p,std::shared_ptr<Job> job) {
    Cancel(p);
    if (!HasPermission(Perm::InternetAccess)) {
        Text(p,LookupTask(job->task)?Status:SummaryInfo,L(p,L"阅读器受限模式禁止访问网络。",L"Network access is disabled in restricted mode.")); return;
    }
    if (LookupTask(job->task)) ReadConfig(p->configPath,p->config);
    // A prepared summary uses the exact provider/model shown in its preview.
    job->config=LookupTask(job->task)?p->config:p->preparedConfig;
    job->key=Unprotect(job->config.keys[job->config.provider]);
    if (!ValidKey(job->key)) {
        SecureZeroMemory(job->key.data(),job->key.size());
        SettingsView(p,true);
        Text(p,Privacy,L(p,L"请打开当前服务的密钥页面，创建自己的 API Key，粘贴到上方并保存。",L"Open the provider's key page, create your API key, then paste it above and save."));
        return;
    }
    if (job->task!=Task::Followup) {
        job->record.provider=ProviderName(job->config.provider);
        job->record.model=job->config.models[job->config.provider];
        job->record.language=job->config.english?"en":"zh";
    }
    job->total=(int)(LookupTask(job->task) ? 1 : SummaryRequests(job->parts.size()));
    p->job=job;
    if (!LookupTask(job->task)) { p->summaryResult.clear(); EnableWindow(Item(p,SummaryExport),FALSE); }
    if (job->task==Task::Explain) p->lookupRecord=Record();
    if (job->task!=Task::Followup) Text(p,LookupTask(job->task)?Answer:SummaryAnswer,L"");
    Text(p,Retry,L(p,L"停止等待",L"Stop waiting"));
    Text(p,SummaryRun,L(p,L"停止等待",L"Stop waiting"));
    FollowupUI(p);
    auto holder=new std::shared_ptr<Job>(job);
    HANDLE thread=CreateThread(nullptr,0,RequestThread,holder,0,nullptr);
    if (!thread) {
        delete holder; Cancel(p);
        Text(p,LookupTask(job->task)?Status:SummaryInfo,L(p,L"无法启动请求，请重试。",L"Could not start the request.")); return;
    }
    CloseHandle(thread); SetTimer(p->hwnd,1,100,nullptr);
}
void StartLookup(Panel* p) {
    if (p->selected.empty() || p->context.empty()) {
        Text(p,Status,L(p,L"在正文中选中文字，再按 Ctrl + Alt + D。",L"Select text in the document, then press Ctrl + Alt + D.")); return;
    }
    auto job=std::make_shared<Job>();
    job->task=Task::Explain; job->parts={p->context}; job->selected=p->selected;
    job->record.selected=p->selected; job->record.context=p->context;
    job->record.file=p->file; job->record.page=p->page; job->record.title=FileName(p->file);
    StartJob(p,job);
}
void StartFollowup(Panel* p) {
    if (p->job) {
        if (p->job->task==Task::Followup) {
            Cancel(p);
            Text(p,Status,L(p,L"已停止等待，问题已保留；已发出的请求可能仍计费。",L"Stopped waiting; your question is kept. An in-flight request may still be charged."));
        }
        return;
    }
    auto question=Text(Item(p,FollowupInput));
    if (p->selected.empty() || p->lookupRecord.answer.empty()) {
        Text(p,Status,L(p,L"请先选词并生成解释，再继续追问。",L"Select text and get an explanation before asking a follow-up.")); return;
    }
    if (!CanFollowup(p->lookupRecord.answer,question)) {
        Text(p,Status,L(p,L"请输入问题（最多 1200 字）；对话过长时请重新解释后再追问。",L"Enter a question (up to 1200 characters); start a fresh explanation if the conversation is full.")); return;
    }
    auto job=std::make_shared<Job>(); job->task=Task::Followup;
    job->record=p->lookupRecord; job->selected=p->selected; job->parts={p->context}; job->question=question;
    StartJob(p,job);
}
void HistorySelection(Panel* p) {
    int index=(int)SendMessageW(Item(p,HistoryList),LB_GETCURSEL,0,0);
    bool valid=index>=0 && (size_t)index<p->shownHistory.size();
    Text(p,HistoryDetail,valid ? RecordText(p->history[p->shownHistory[index]],p->config.english) : L"");
    EnableWindow(Item(p,HistoryExport),valid); EnableWindow(Item(p,HistoryDelete),valid);
}
void FilterHistory(Panel* p) {
    auto query=Text(Item(p,HistorySearch));
    SendMessageW(Item(p,HistoryList),LB_RESETCONTENT,0,0); p->shownHistory.clear();
    for (size_t i=0;i<p->history.size();++i) {
        const auto& r=p->history[i];
        if (!Matches(r,query)) continue;
        std::wstring label=r.time.substr(0,10)+L"  "+(r.kind=="explain"?r.selected:r.title);
        for (auto& c:label) if (c=='\r' || c=='\n' || c=='\t') c=' ';
        if (label.size()>130) label=label.substr(0,127)+L"…";
        SendMessageW(Item(p,HistoryList),LB_ADDSTRING,0,(LPARAM)label.c_str()); p->shownHistory.push_back(i);
    }
    if (!p->shownHistory.empty()) SendMessageW(Item(p,HistoryList),LB_SETCURSEL,0,0);
    HistorySelection(p);
}
void HistoryView(Panel* p) {
    p->view=View::History; p->scrollY=0;
    int bad=0; bool ok=LoadRecords(p->historyDir,p->history,bad);
    FilterHistory(p); Labels(p);
    Text(p,HistoryInfo,std::to_wstring(p->history.size())+L(p,L" 条已保存记录",L" saved records")+
        ((!ok || bad) ? L(p,L" · 部分记录无法读取",L" · Some records could not be read") : L""));
    Layout(p);
}
void Export(Panel* p,const std::wstring& value) {
    if (value.empty() || !HasPermission(Perm::DiskAccess)) return;
    wchar_t path[MAX_PATH]=L"AI-reading-notes.txt";
    OPENFILENAMEW dialog{}; dialog.lStructSize=sizeof(dialog); dialog.hwndOwner=p->hwnd;
    dialog.lpstrFilter=L"UTF-8 text (*.txt)\0*.txt\0\0"; dialog.lpstrFile=path; dialog.nMaxFile=MAX_PATH;
    dialog.lpstrDefExt=L"txt"; dialog.Flags=OFN_OVERWRITEPROMPT|OFN_PATHMUSTEXIST|OFN_NOCHANGEDIR;
    if (GetSaveFileNameW(&dialog) && !WriteFileAtomic(path,"\xef\xbb\xbf"+Utf8(value)))
        MessageBoxW(p->hwnd,L(p,L"文件保存失败，请检查目标文件夹。",L"Could not save the file. Check the destination folder."),L"DeepReader",MB_OK|MB_ICONWARNING);
}
void RefreshStats(Panel* p) {
    std::vector<Record> records; int bad=0;
    if (!LoadRecords(p->historyDir,records,bad)) {
        p->summaryStats=L(p,L"无法读取历史，未计算统计。",L"Could not read history; statistics are unavailable.");
    } else {
        int scope=Choice(p,SummaryScope); auto total=CountReading(records);
        ReadingStats scoped;
        std::wstring first,last;
        bool valid=scope<=0 || PeriodRange(scope,Text(Item(p,SummaryDate)),first,last);
        if (!valid) p->summaryStats=L(p,L"请选择有效日期以查看本范围统计。",L"Choose a valid date to see scope statistics.");
        else {
            auto file=CurrentFile(p);
            if (scope>0 || !file.empty()) scoped=CountReading(records,first,last,scope>0?L"":file);
            p->summaryStats=StatsText(scoped,total.lookups,p->config.english);
            if (scope<=0 && file.empty()) p->summaryStats+=L(p,L"\r\n打开文件后显示该文件统计。",L"\r\nOpen a document for file statistics.");
            if (bad) p->summaryStats+=L(p,L"\r\n部分记录损坏；以上仅统计可读取记录。",L"\r\nSome records are unreadable; these totals are partial.");
        }
    }
    Text(p,SummaryStats,p->summaryStats);
}
void InvalidateSummary(Panel* p) {
    if (p->job && !LookupTask(p->job->task)) Cancel(p);
    if (p->extracting) Cancel(p);
    p->prepared.clear(); p->summaryResult.clear(); p->summaryRecord=Record();
    p->summaryInfo=L(p,L"单文件：读取当前文件的全部可复制文字。\r\n日 / 周 / 月：汇总相应日期的已保存查询和单文件总结。\r\n先准备材料，再生成；完成后自动保存。",L"File: all extractable text in the current document.\r\nDay / week / month: saved lookups and file summaries.\r\nPrepare first, then generate; results are saved automatically.");
    Text(p,SummaryInfo,p->summaryInfo); Text(p,SummaryAnswer,L"");
    EnableWindow(Item(p,SummaryRun),FALSE); EnableWindow(Item(p,SummaryExport),FALSE);
    RefreshStats(p);
}
void Prepared(Panel* p,const std::wstring& source,const std::wstring& coverage) {
    p->preparedConfig=p->config;
    RefreshStats(p); p->preparedStats=p->summaryStats;
    p->prepared=Chunks(source);
    p->summaryRecord.context=coverage;
    p->summaryInfo=coverage+L"\r\n"+std::to_wstring(p->prepared.size())+L(p,L" 段 · 最多 ",L" parts · Up to ")+
        std::to_wstring(SummaryRequests(p->prepared.size()))+L(p,L" 次 API 请求。\r\n发送至：",L" API requests.\r\nSend to: ")+
        Wide(ProviderName(p->config.provider))+L" / "+Wide(p->config.models[p->config.provider]);
    Text(p,SummaryInfo,p->summaryInfo);
    EnableWindow(Item(p,SummaryRun),!p->prepared.empty());
    Text(p,SummaryPrepare,L(p,L"重新准备",L"Prepare again"));
}
void PrepareSummary(Panel* p) {
    if (p->extracting) { Cancel(p); InvalidateSummary(p); return; }
    Cancel(p); InvalidateSummary(p);
    ReadConfig(p->configPath,p->config);
    int scope=Choice(p,SummaryScope);
    if (scope==0) {
        auto dm=p->win->AsFixed();
        if (!dm || !HasPermission(Perm::CopySelection)) {
            Text(p,SummaryInfo,L(p,L"请先打开有可复制文字的文件。",L"Open a document with extractable text first.")); return;
        }
        p->extractTotal=dm->PageCount(); p->extractPage=1; p->blankPages=0; p->extracting=true;
        p->summaryRecord.kind="file"; p->summaryRecord.file=CurrentFile(p);
        p->summaryRecord.title=L(p,L"文件总结 · ",L"File summary · ")+FileName(p->summaryRecord.file);
        Text(p,SummaryPrepare,L(p,L"停止读取",L"Stop reading"));
        SetTimer(p->hwnd,2,15,nullptr);
    } else {
        std::wstring first,last;
        if (!PeriodRange(scope,Text(Item(p,SummaryDate)),first,last)) {
            Text(p,SummaryInfo,L(p,L"日期应为有效的 YYYY-MM-DD，例如 2026-10-05。",L"Enter a valid YYYY-MM-DD date, such as 2026-10-05.")); return;
        }
        std::vector<Record> records; int bad=0;
        if (!LoadRecords(p->historyDir,records,bad) || bad) {
            Text(p,SummaryInfo,L(p,L"部分历史无法读取，未生成不完整的总结。请检查 AIHistory 文件夹。",L"Some history could not be read. Check AIHistory before summarizing.")); return;
        }
        size_t count=0; auto source=ReviewSource(records,first,last,count);
        if (source.empty()) {
            Text(p,SummaryInfo,count ? L(p,L"记录超过 200 万字符，请缩小日期范围。",L"Records exceed two million characters. Choose a smaller period.") :
                L(p,L"该日期范围没有已保存的查询或单文件总结。",L"No saved lookups or file summaries in this period.")); return;
        }
        const char* kinds[]={"file","day","week","month"};
        p->summaryRecord.kind=kinds[scope];
        p->summaryRecord.title=first+L" — "+last+L(p,L" 阅读总结",L" reading review");
        Prepared(p,source,first+L" — "+last+L" · "+std::to_wstring(count)+L(p,L" 条记录",L" records"));
    }
}
void ExtractionStep(Panel* p) {
    auto dm=p->win->AsFixed();
    if (!dm || CurrentFile(p)!=p->summaryRecord.file) { Cancel(p); InvalidateSummary(p); return; }
    int len=0;
    const wchar_t* page=dm->textCache->GetTextForPage(p->extractPage,&len);
    if (!page || !len) ++p->blankPages;
    else {
        p->extraction+=L"\n[Page "+std::to_wstring(p->extractPage)+L"]\n";
        p->extraction.append(page,len);
    }
    if (p->extraction.size()>2000000) {
        Cancel(p); Text(p,SummaryInfo,L(p,L"全文超过 200 万字符，请拆分文件后总结。未发送任何文字。",L"The document exceeds two million characters. Split it first. Nothing was sent.")); return;
    }
    Text(p,SummaryInfo,L(p,L"正在读取全文：",L"Reading document: ")+std::to_wstring(p->extractPage)+L" / "+std::to_wstring(p->extractTotal));
    ++p->extractPage;
    if (p->extractPage<=p->extractTotal) return;
    KillTimer(p->hwnd,2); p->extracting=false;
    if (p->extraction.empty()) {
        Text(p,SummaryInfo,L(p,L"未找到可复制文字。扫描文件需要先做 OCR。",L"No text found. Scanned documents need OCR first."));
        Text(p,SummaryPrepare,L(p,L"准备材料",L"Prepare")); return;
    }
    auto coverage=std::to_wstring(p->extractTotal)+L(p,L" 页已检查",L" pages checked");
    if (p->blankPages) coverage+=L" · "+std::to_wstring(p->blankPages)+L(p,L" 页无文字（图像未分析）",L" pages without text (images not analyzed)");
    Prepared(p,L"[Coverage: "+coverage+L"]\n"+p->extraction,coverage);
    p->extraction.clear();
}
void RunSummary(Panel* p) {
    if (p->job) {
        Cancel(p);
        Text(p,SummaryInfo,L(p,L"已停止等待；已发出的请求可能仍计费，后续分段不会发送。",L"Stopped waiting. An in-flight request may still be charged; no further parts will be sent.")); return;
    }
    if (p->prepared.empty()) { PrepareSummary(p); return; }
    auto job=std::make_shared<Job>(); job->record=p->summaryRecord;
    job->stats=p->preparedStats;
    job->task=job->record.kind=="file"?Task::Document:Task::Review;
    job->parts=p->prepared; StartJob(p,job);
}
void Tick(Panel* p) {
    auto job=p->job; if (!job) return;
    bool lookup=LookupTask(job->task), following=job->task==Task::Followup;
    int status=lookup?Status:SummaryInfo;
    if (!job->done) {
        Text(p,status,L(p,L"处理中：",L"Processing: ")+std::to_wstring(job->completed.load())+L" / "+std::to_wstring(job->total)+
            L"\r\n"+Wide(ProviderName(job->config.provider))+L" / "+Wide(job->config.models[job->config.provider]));
        return;
    }
    auto result=job->result;
    if (result.ok && following) {
        auto model=Wide(ProviderName(job->config.provider))+L" / "+Wide(result.model.empty()?job->config.models[job->config.provider]:result.model);
        result.text=FollowupTranscript(job->record.answer,job->question,result.text,job->config.english,model);
        if (result.text.empty()) {
            result.ok=false;
            result.text=L(p,L"回答过长，未改动原对话；请换用其他模型重试。",L"The reply was too long; your conversation is unchanged. Try another model.");
        }
    }
    if (result.ok && !lookup)
        result.text=job->stats+L"\r\n\r\n"+result.text;
    if (!following || result.ok) Text(p,lookup?Answer:SummaryAnswer,result.text);
    if (result.ok) {
        auto record=job->record; record.answer=result.text;
        if (!following && !result.model.empty()) record.model=result.model;
        bool saved=HasPermission(Perm::DiskAccess) && HasPermission(Perm::SavePreferences) && SaveRecord(p->historyDir,record);
        if (saved) RefreshStats(p);
        Text(p,status,L(p,saved?L"已自动保存到历史 · ":L"回答已生成，但本地保存失败 · ",
            saved?L"Saved to history · ":L"Answer ready; local save failed · ")+Wide(result.model.empty()?job->config.models[job->config.provider]:result.model));
        if (lookup) p->lookupRecord=record;
        if (following) {
            Text(p,FollowupInput,L"");
            SendMessageW(Item(p,Answer),EM_SETSEL,(WPARAM)-1,(LPARAM)-1); SendMessageW(Item(p,Answer),EM_SCROLLCARET,0,0);
        }
        if (!lookup) {
            p->summaryResult=result.text; p->summaryRecord=record;
            EnableWindow(Item(p,SummaryExport),TRUE);
        }
    } else Text(p,status,following?result.text:L(p,L"请求未完成；未保存为成功记录。",L"Request failed; no success record was saved."));
    Cancel(p);
    if (following && p->view==View::Lookup) SetFocus(Item(p,FollowupInput));
    if (p->view==View::History) HistoryView(p);
}
void Layout(Panel* p) {
    if (p->layingOut) return;
    p->layingOut=true;
    RECT r{}; GetClientRect(p->hwnd,&r);
    int dpi=DpiGet(p->hwnd); auto d=[dpi](int x){return MulDiv(x,dpi,96);};
    int minimum=d(p->view==View::Preferences?572:(p->view==View::Summary?570:520));
    int viewport=r.bottom,h=std::max(viewport,minimum);
    ShowScrollBar(p->hwnd,SB_VERT,h>viewport);
    GetClientRect(p->hwnd,&r);
    p->scrollY=std::max(0,std::min(p->scrollY,h-viewport));
    SCROLLINFO scroll{sizeof(scroll),SIF_RANGE|SIF_PAGE|SIF_POS,0,h-1,(UINT)viewport,p->scrollY,0};
    SetScrollInfo(p->hwnd,SB_VERT,&scroll,TRUE);
    int w=r.right,m=d(16),inner=w-2*m;
    auto place=[&](int id,int x,int y,int width,int height) {
        auto child=Item(p,id); ShowWindow(child,SW_SHOW); MoveWindow(child,x,y-p->scrollY,std::max(1,width),std::max(1,height),TRUE);
    };
    for (int id=Close;id<=FollowupLabel;++id)
        if (id!=LookupSplitter || !p->dragging) ShowWindow(Item(p,id),SW_HIDE);
    place(Title,m,d(13),inner-d(136),d(29));
    place(Language,w-m-d(130),d(10),d(62),d(30));
    place(Close,w-m-d(62),d(10),d(62),d(30));
    int tabs[]={LookupTab,HistoryTab,SummaryTab,Settings};
    for (int i=0;i<4;++i) {
        place(tabs[i],m+i*inner/4,d(56),inner/4-d(3),d(32));
        SendMessageW(Item(p,tabs[i]),BM_SETCHECK,(int)p->view==i?BST_CHECKED:BST_UNCHECKED,0);
    }
    if (p->view==View::Preferences) {
        place(ProviderLabel,m,d(103),inner,d(22));
        place(ProviderInput,m,d(127),inner,d(220));
        place(KeyLabel,m,d(171),inner,d(22)); place(KeyInput,m,d(195),inner,d(30));
        place(ModelLabel,m,d(239),inner,d(22)); place(ModelInput,m,d(263),inner,d(250));
        place(ModelHint,m,d(306),inner,d(56)); place(Privacy,m,d(373),inner,d(56));
        place(KeyLink,m,d(435),inner,d(29));
        place(Save,m,d(478),inner-d(96),d(32)); place(Back,w-m-d(86),d(478),d(86),d(32));
        place(ShowGuide,m,d(527),inner,d(29));
    } else if (p->view==View::History) {
        place(HistorySearch,m,d(104),inner,d(31)); place(HistoryInfo,m,d(145),inner,d(25));
        int listHeight=std::min(d(160),std::max(d(85),h/4));
        place(HistoryList,m,d(176),inner,listHeight);
        place(HistoryDetail,m,d(187)+listHeight,inner,std::max(d(60),h-d(245)-listHeight));
        place(HistoryExport,m,h-d(44),inner-d(105),d(31));
        place(HistoryDelete,w-m-d(95),h-d(44),d(95),d(31));
    } else if (p->view==View::Summary) {
        place(SummaryLabel,m,d(104),inner,d(24));
        place(SummaryScope,m,d(132),inner*3/5-d(8),d(180));
        place(SummaryDate,m+inner*3/5,d(132),inner*2/5,d(30));
        EnableWindow(Item(p,SummaryDate),Choice(p,SummaryScope)!=0);
        place(SummaryStats,m,d(177),inner,d(118));
        place(SummaryInfo,m,d(305),inner,d(78));
        place(SummaryPrepare,m,d(393),inner/2-d(4),d(32));
        place(SummaryRun,m+inner/2+d(4),d(393),inner/2-d(4),d(32));
        place(SummaryAnswer,m,d(439),inner,std::max(d(50),h-d(497)));
        place(SummaryExport,m,h-d(44),inner,d(31));
    } else if (p->showIntro) {
        place(Status,m,d(104),inner,d(48));
        place(Intro,m,d(164),inner,std::max(d(100),h-d(230)));
        place(Configure,m,h-d(45),inner/2-d(4),d(32));
        place(DismissIntro,m+inner/2+d(4),h-d(45),inner/2-d(4),d(32));
    } else {
        place(Status,m,d(101),inner,d(42));
        place(SelectedLabel,m,d(151),inner,d(24));
        p->splitTop=d(179); p->splitAvailable=h-d(383);
        int selectedHeight=std::max(d(60),std::min(p->splitAvailable-d(60),p->splitAvailable*p->config.lookupSplit/100));
        place(Selected,m,p->splitTop,inner,selectedHeight);
        place(LookupSplitter,m,p->splitTop+selectedHeight,inner,d(22));
        place(AnswerLabel,m,d(201)+selectedHeight,inner,d(22));
        place(Answer,m,d(223)+selectedHeight,inner,p->splitAvailable-selectedHeight);
        place(FollowupLabel,m,h-d(150),inner,d(20));
        place(FollowupInput,m,h-d(126),inner-d(82),d(60));
        place(FollowupSend,w-m-d(74),h-d(126),d(74),d(60));
        place(ContextToggle,m,h-d(45),inner/3-d(4),d(32));
        place(SaveHighlights,m+inner/3,h-d(45),inner/3-d(4),d(32));
        place(Retry,m+2*inner/3,h-d(45),inner/3,d(32));
    }
    p->layingOut=false;
}
void Labels(Panel* p) {
    Text(p,Title,L"DeepReader");
    Text(p,Language,L(p,L"English",L"中文")); Text(p,Close,L(p,L"收起",L"Hide"));
    Text(p,LookupTab,L(p,L"解释",L"Lookup")); Text(p,HistoryTab,L(p,L"历史",L"History"));
    Text(p,SummaryTab,L(p,L"总结",L"Summary")); Text(p,Settings,L(p,L"设置",L"Settings"));
    Text(p,Configure,L(p,L"配置 API",L"Configure API"));
    Text(p,DismissIntro,L(p,L"开始阅读",L"Start reading"));
    Text(p,ShowGuide,L(p,L"查看使用引导",L"Show getting-started guide"));
    Text(p,SaveHighlights,L(p,L"保存批注",L"Save PDF"));
    Text(p,AnswerLabel,L(p,L"解释",L"Explanation"));
    FollowupUI(p);
    Text(p,Intro,L(p,
        L"欢迎使用 DeepReader\r\n\r\n1. 配置 API：申请并保存自己的密钥。\r\n\r\n2. 打开 PDF，选词后按 Ctrl + Alt + D。\r\n\r\n3. 用“历史”回顾，用“总结”整理阅读内容。\r\n\r\n默认使用 DeepSeek，按量计费。\r\n点击 English 可切换界面和回答语言。\r\n\r\n只有主动解释、追问或总结时，才会发送相关文字给所选服务。",
        L"Welcome to DeepReader\r\n\r\n1. Click Configure API. Create and save your own key.\r\n\r\n2. Open a PDF, select text, then press Ctrl + Alt + D.\r\n\r\n3. Revisit History, or use Summary for document, daily, weekly and monthly reviews.\r\n\r\nDefault: DeepSeek, billed by usage. Use the language button for the UI and future answers.\r\n\r\nText is sent to the selected provider only when you explain, ask a follow-up or generate a summary."));
    Text(p,SelectedLabel,L(p,L"选中内容 · Ctrl + Alt + D",L"Selected text · Ctrl + Alt + D"));
    HighlightUI(p);
    Text(p,Retry,p->job?L(p,L"停止等待",L"Stop waiting"):L(p,L"重新解释",L"Explain again"));
    Text(p,ProviderLabel,L(p,L"服务（每个服务使用各自的密钥）",L"Provider (each uses its own key)"));
    Text(p,ModelLabel,L(p,L"模型（可选择或输入模型 ID）",L"Model (select or enter an ID)"));
    Text(p,Privacy,L(p,L"密钥在本机加密保存。查询与总结保存至本地历史。\r\n解释、追问或生成总结时才会向所选服务发送材料。",L"Keys are encrypted locally; answers are saved in history.\r\nText is sent when you explain, ask a follow-up or summarize."));
    Text(p,Save,L(p,L"保存设置",L"Save settings")); Text(p,Back,L(p,L"返回",L"Back"));
    Text(p,KeyLink,L(p,L"打开服务的密钥 / 模型页面",L"Open provider keys / models"));
    SendMessageW(Item(p,HistorySearch),EM_SETCUEBANNER,TRUE,(LPARAM)L(p,L"搜索选文、解释、文件名或日期",L"Search text, answer, document or date"));
    Text(p,HistoryExport,L(p,L"导出选中记录",L"Export selected"));
    Text(p,HistoryDelete,L(p,L"删除记录",L"Delete"));
    Text(p,SummaryLabel,L(p,L"总结范围 / 日期（YYYY-MM-DD）",L"Scope / date (YYYY-MM-DD)"));
    int scope=Choice(p,SummaryScope); if (scope<0) scope=0;
    SendMessageW(Item(p,SummaryScope),CB_RESETCONTENT,0,0);
    const wchar_t* zh[]={L"当前文件全文",L"日总结",L"周总结（周一至周日）",L"月总结"};
    const wchar_t* en[]={L"Current document",L"Daily review",L"Weekly (Mon–Sun)",L"Monthly review"};
    for (int i=0;i<4;++i) SendMessageW(Item(p,SummaryScope),CB_ADDSTRING,0,(LPARAM)(p->config.english?en[i]:zh[i]));
    SendMessageW(Item(p,SummaryScope),CB_SETCURSEL,scope,0);
    Text(p,SummaryPrepare,p->extracting?L(p,L"停止读取",L"Stop reading"):L(p,L"准备材料",L"Prepare"));
    Text(p,SummaryRun,p->job?L(p,L"停止等待",L"Stop waiting"):L(p,L"生成总结",L"Generate"));
    Text(p,SummaryExport,L(p,L"导出总结",L"Export summary"));
}
bool Capture(MainWindow* win,std::wstring& selected,std::wstring& context,int& page) {
    if (!HasPermission(Perm::CopySelection)) return false;
    auto tab=win->CurrentTab(); auto dm=win->AsFixed();
    if (!tab || !tab->selectionOnPage || !dm || !dm->textSelection || dm->textSelection->result.len<=0) return false;
    int first,from,last,to;
    dm->textSelection->GetGlyphRange(&first,&from,&last,&to);
    if (first<1 || last>dm->PageCount() || last<first || last-first>2) return false;
    std::wstring before,after;
    for (int n=first;n<=last;++n) {
        int len=0; const WCHAR* text=dm->textCache->GetTextForPage(n,&len);
        int a=n==first?from:0,b=n==last?to:len;
        if (!text || a<0 || a>b || b>len) return false;
        if (n==first) before.assign(text+std::max(0,a-1500),std::min(a,1500));
        if (n!=first) selected+=L"\n";
        selected.append(text+a,b-a);
        if (n==last) after.assign(text+b,std::min(1500,len-b));
        if (selected.size()>2200) return false;
    }
    if (before.size()<1200 && first>1) {
        int len=0; const WCHAR* text=dm->textCache->GetTextForPage(first-1,&len);
        if (text) before=std::wstring(text+std::max(0,len-1200),std::min(1200,len))+L"\n"+before;
    }
    if (after.size()<1200 && last<dm->PageCount()) {
        int len=0; const WCHAR* text=dm->textCache->GetTextForPage(last+1,&len);
        if (text) after+=L"\n"+std::wstring(text,std::min(1200,len));
    }
    context=Context(before,selected,after); page=first; return !context.empty();
}
LRESULT CALLBACK PanelProc(HWND hwnd,UINT msg,WPARAM wp,LPARAM lp) {
    Panel* p=(Panel*)GetWindowLongPtrW(hwnd,GWLP_USERDATA);
    if (msg==WM_NCCREATE) { p=(Panel*)((CREATESTRUCTW*)lp)->lpCreateParams; p->hwnd=hwnd; SetWindowLongPtrW(hwnd,GWLP_USERDATA,(LONG_PTR)p); }
    if (!p) return DefWindowProcW(hwnd,msg,wp,lp);
    switch (msg) {
        case kRefreshDocument: RefreshStats(p); HighlightUI(p); return 0;
        case WM_SIZE: Layout(p); return 0;
        case WM_VSCROLL: {
            SCROLLINFO s{sizeof(s),SIF_ALL}; GetScrollInfo(hwnd,SB_VERT,&s);
            int step=MulDiv(36,DpiGet(hwnd),96);
            switch (LOWORD(wp)) {
                case SB_LINEUP: p->scrollY-=step; break;
                case SB_LINEDOWN: p->scrollY+=step; break;
                case SB_PAGEUP: p->scrollY-=(int)s.nPage; break;
                case SB_PAGEDOWN: p->scrollY+=(int)s.nPage; break;
                case SB_THUMBTRACK: p->scrollY=s.nTrackPos; break;
                case SB_TOP: p->scrollY=0; break;
                case SB_BOTTOM: p->scrollY=s.nMax; break;
            }
            Layout(p); return 0;
        }
        case WM_MOUSEWHEEL: {
            SCROLLINFO s{sizeof(s),SIF_RANGE|SIF_PAGE}; GetScrollInfo(hwnd,SB_VERT,&s);
            if (s.nMax+1>(int)s.nPage) {
                p->scrollY-=(short)HIWORD(wp)*MulDiv(48,DpiGet(hwnd),96)/WHEEL_DELTA;
                Layout(p); return 0;
            }
            break;
        }
        case WM_CTLCOLORSTATIC:
        case WM_CTLCOLOREDIT:
            SetTextColor((HDC)wp,RGB(35,43,54)); SetBkColor((HDC)wp,RGB(255,255,255));
            SetDCBrushColor((HDC)wp,RGB(255,255,255)); return (LRESULT)GetStockObject(DC_BRUSH);
        case WM_TIMER:
            if (wp==1) Tick(p);
            else if (wp==2 && p->extracting) ExtractionStep(p);
            return 0;
        case WM_COMMAND: {
            int id=LOWORD(wp),event=HIWORD(wp);
            if (id==ProviderInput && event==CBN_SELCHANGE) {
                int next=Choice(p,ProviderInput);
                if (next>=0 && next<ProviderCount && StageSettings(p)) { p->editing.provider=next; FillProvider(p); }
                else SendMessageW(Item(p,ProviderInput),CB_SETCURSEL,p->editing.provider,0);
                return 0;
            }
            if (id==ModelInput && (event==CBN_EDITCHANGE || event==CBN_SELCHANGE)) {
                if (event==CBN_SELCHANGE) {
                    int index=Choice(p,ModelInput);
                    auto models=ModelChoices(p->editing.provider);
                    if (index>=0 && (size_t)index<models.size()) Text(p,ModelInput,models[index]);
                }
                ModelNotice(p); return 0;
            }
            if (id==HistorySearch && event==EN_CHANGE) { FilterHistory(p); return 0; }
            if (id==FollowupInput && event==EN_CHANGE) { FollowupUI(p); return 0; }
            if (id==HistoryList && event==LBN_SELCHANGE) { HistorySelection(p); return 0; }
            if ((id==SummaryScope && event==CBN_SELCHANGE) || (id==SummaryDate && event==EN_CHANGE)) {
                InvalidateSummary(p); Layout(p); return 0;
            }
            if (event!=BN_CLICKED) break;
            switch (id) {
                case Close: DeepSeekToggle(p->win); return 0;
                case LookupTab: p->view=View::Lookup; p->scrollY=0; HighlightUI(p); Layout(p); return 0;
                case HistoryTab: HistoryView(p); return 0;
                case SummaryTab: p->view=View::Summary; p->scrollY=0; RefreshStats(p); Layout(p); return 0;
                case Configure: p->showIntro=false; SettingsView(p,true); return 0;
                case DismissIntro: p->showIntro=false; Layout(p); return 0;
                case ShowGuide: p->showIntro=true; p->view=View::Lookup; p->scrollY=0; Layout(p); return 0;
                case Settings: SettingsView(p,true); return 0;
                case Back: SettingsView(p,false); return 0;
                case Language: {
                    if (!HasPermission(Perm::SavePreferences)) return 0;
                    Config next=p->config; ReadConfig(p->configPath,next); next.english=!p->config.english;
                    if (!SaveConfig(p->configPath,next)) { Text(p,Status,L(p,L"语言设置保存失败。",L"Could not save language settings.")); return 0; }
                    for (MainWindow* win:gWindows) {
                        auto panel=Get(win); if (!panel) continue;
                        Cancel(panel); panel->config=next; panel->editing.english=next.english;
                        Labels(panel); InvalidateSummary(panel);
                        if (panel->view==View::History) HistoryView(panel);
                        if (panel->view==View::Preferences) {
                            // Changing language must not discard a key or model being edited.
                            ModelNotice(panel);
                            SendMessageW(Item(panel,KeyInput),EM_SETCUEBANNER,TRUE,(LPARAM)(panel->editing.keys[panel->editing.provider].empty()
                                ? L(panel,L"输入此服务的 API Key",L"Enter this provider's API key")
                                : L(panel,L"已保存，留空保持原密钥",L"Saved; leave blank to keep the key")));
                        }
                        Text(panel,Status,panel->selected.empty()
                            ? L(panel,L"在正文中选中文字，按 Ctrl + Alt + D。",L"Select document text, then press Ctrl + Alt + D.")
                            : L(panel,L"已切换中文。点击重新解释可用中文生成当前选文的解释。",L"English enabled. Click Explain again to regenerate the current explanation."));
                        Layout(panel);
                    }
                    SetCurrentLanguageAndRefreshUI(next.english?"en":"cn"); return 0;
                }
                case ContextToggle: ToggleHighlight(p); return 0;
                case SaveHighlights: SaveHighlightsToPdf(p); return 0;
                case FollowupSend: StartFollowup(p); return 0;
                case Retry:
                    if (p->job) { Cancel(p); Text(p,Status,L(p,L"已停止等待；已发出的请求可能仍计费。",L"Stopped waiting. An in-flight request may still be charged.")); }
                    else StartLookup(p);
                    return 0;
                case Save:
                    if (!HasPermission(Perm::SavePreferences) || !StageSettings(p)) return 0;
                    if (!SaveConfig(p->configPath,p->editing)) { Text(p,Privacy,L(p,L"设置保存失败，请检查文件夹是否可写。",L"Could not save settings. Check folder access.")); return 0; }
                    Cancel(p); p->config=p->editing; Text(p,KeyInput,L"");
                    InvalidateSummary(p); SettingsView(p,false);
                    Text(p,Status,L(p,L"已保存。点击重新解释，或到总结页准备材料。",L"Saved. Explain again or prepare a summary."));
                    return 0;
                case KeyLink: {
                    const wchar_t* urls[]={L"https://openrouter.ai/settings/keys",L"https://platform.deepseek.com/api_keys",L"https://aistudio.google.com/apikey"};
                    if (HasPermission(Perm::InternetAccess)) ShellExecuteW(hwnd,L"open",urls[p->editing.provider],nullptr,nullptr,SW_SHOWNORMAL);
                    return 0;
                }
                case HistoryExport: Export(p,Text(Item(p,HistoryDetail))); return 0;
                case HistoryDelete: {
                    int i=(int)SendMessageW(Item(p,HistoryList),LB_GETCURSEL,0,0);
                    if (i<0 || (size_t)i>=p->shownHistory.size() || !HasPermission(Perm::DiskAccess)) return 0;
                    auto deletedId=p->history[p->shownHistory[i]].id;
                    if (MessageBoxW(hwnd,L(p,L"删除这条本地记录？此操作不可撤销。",L"Delete this local record? This cannot be undone."),
                        L"DeepReader",MB_YESNO|MB_ICONQUESTION|MB_DEFBUTTON2)==IDYES) {
                        if (!DeleteRecord(p->historyDir,deletedId))
                            Text(p,HistoryInfo,L(p,L"删除失败。",L"Could not delete the record."));
                        else {
                            if (p->job && p->job->task==Task::Followup && p->job->record.id==deletedId) Cancel(p);
                            if (p->lookupRecord.id==deletedId) { p->lookupRecord.id.clear(); p->lookupRecord.time.clear(); }
                            HistoryView(p); InvalidateSummary(p);
                        }
                    }
                    return 0;
                }
                case SummaryPrepare: PrepareSummary(p); return 0;
                case SummaryRun: RunSummary(p); return 0;
                case SummaryExport: Export(p,RecordText(p->summaryRecord,p->config.english)); return 0;
            }
            break;
        }
        case WM_NCDESTROY:
            Cancel(p); RemovePropW(p->win->hwndFrame,kPanelProperty);
            DeleteObject(p->font); DeleteObject(p->titleFont); SetWindowLongPtrW(hwnd,GWLP_USERDATA,0);
            if (p->ownedByWindow) delete p;
            break;
    }
    return DefWindowProcW(hwnd,msg,wp,lp);
}
Panel* Ensure(MainWindow* win) {
    Panel* p=Get(win); if (p) return p;
    WNDCLASSW cls{}; cls.lpfnWndProc=PanelProc; cls.hInstance=GetModuleHandleW(nullptr);
    cls.hCursor=LoadCursorW(nullptr,IDC_ARROW); cls.hbrBackground=(HBRUSH)(COLOR_WINDOW+1); cls.lpszClassName=kPanelClass;
    RegisterClassW(&cls);
    WNDCLASSW divider=cls; divider.lpfnWndProc=SplitterProc;
    divider.hCursor=LoadCursorW(nullptr,IDC_SIZENS); divider.lpszClassName=L"DeepReaderLookupSplitter";
    RegisterClassW(&divider);
    p=new Panel(); p->win=win; p->configPath=Wide(GetPathInAppDataDirTemp("AIReader.json"));
    p->historyDir=Wide(GetPathInAppDataDirTemp("AIHistory"));
    auto legacyPath=Wide(GetPathInAppDataDirTemp("DeepSeek.json"));
    bool loaded=ReadConfig(p->configPath,p->config);
    if (!loaded) loaded=ReadConfig(legacyPath,p->config);
    bool hasProfile=GetFileAttributesW(p->configPath.c_str())!=INVALID_FILE_ATTRIBUTES ||
        GetFileAttributesW(legacyPath.c_str())!=INVALID_FILE_ATTRIBUTES;
    // A broken existing profile must not be overwritten just to record onboarding.
    p->showIntro=!p->config.onboardingSeen && (loaded || !hasProfile);
    p->config.onboardingSeen=true;
    HWND hwnd=CreateWindowExW(WS_EX_CONTROLPARENT,kPanelClass,L"DeepReader",WS_CHILD|WS_CLIPCHILDREN,0,0,100,100,win->hwndFrame,nullptr,cls.hInstance,p);
    if (!hwnd) { delete p; return nullptr; }
    p->ownedByWindow=true; SetPropW(win->hwndFrame,kPanelProperty,p);
    int dpi=DpiGet(win->hwndFrame);
    p->font=CreateFontW(-MulDiv(14,dpi,96),0,0,0,FW_NORMAL,FALSE,FALSE,FALSE,DEFAULT_CHARSET,0,0,CLEARTYPE_QUALITY,0,L"Microsoft YaHei UI");
    p->titleFont=CreateFontW(-MulDiv(18,dpi,96),0,0,0,FW_SEMIBOLD,FALSE,FALSE,FALSE,DEFAULT_CHARSET,0,0,CLEARTYPE_QUALITY,0,L"Microsoft YaHei UI");
    auto make=[&](int id,const WCHAR* type,DWORD style=0) {
        HWND control=CreateWindowExW(0,type,L"",WS_CHILD|style,0,0,1,1,hwnd,(HMENU)(INT_PTR)id,cls.hInstance,nullptr);
        SendMessageW(control,WM_SETFONT,(WPARAM)(id==Title?p->titleFont:p->font),TRUE); return control;
    };
    for (int id:{Title,SelectedLabel,Status,KeyLabel,ModelLabel,Privacy,ProviderLabel,ModelHint,HistoryInfo,SummaryLabel,SummaryInfo,AnswerLabel,FollowupLabel}) make(id,L"STATIC");
    for (int id:{Close,Language,ContextToggle,Retry,Save,Back,KeyLink,HistoryExport,HistoryDelete,SummaryPrepare,SummaryRun,SummaryExport,Configure,DismissIntro,ShowGuide,SaveHighlights,FollowupSend}) make(id,L"BUTTON",WS_TABSTOP);
    for (int id:{LookupTab,HistoryTab,SummaryTab,Settings}) make(id,L"BUTTON",WS_TABSTOP|BS_AUTOCHECKBOX|BS_PUSHLIKE);
    DWORD readOnly=ES_MULTILINE|ES_AUTOVSCROLL|ES_READONLY|WS_VSCROLL|WS_TABSTOP;
    for (int id:{Selected,Answer,ContextView,HistoryDetail,SummaryAnswer,Intro,SummaryStats}) { make(id,L"EDIT",readOnly); SendMessageW(Item(p,id),EM_SETLIMITTEXT,100000,0); }
    CreateWindowExW(0,divider.lpszClassName,L"",WS_CHILD|WS_TABSTOP,0,0,1,1,hwnd,(HMENU)(INT_PTR)LookupSplitter,cls.hInstance,p);
    make(KeyInput,L"EDIT",ES_PASSWORD|ES_AUTOHSCROLL|WS_BORDER|WS_TABSTOP);
    make(FollowupInput,L"EDIT",ES_MULTILINE|ES_AUTOVSCROLL|ES_WANTRETURN|WS_VSCROLL|WS_BORDER|WS_TABSTOP);
    SendMessageW(Item(p,FollowupInput),EM_SETLIMITTEXT,FollowupQuestionLimit,0);
    make(ModelInput,L"COMBOBOX",CBS_DROPDOWN|CBS_AUTOHSCROLL|WS_VSCROLL|WS_TABSTOP);
    make(ProviderInput,L"COMBOBOX",CBS_DROPDOWNLIST|WS_VSCROLL|WS_TABSTOP);
    for (int i=0;i<ProviderCount;++i) {
        auto name=Wide(ProviderName(i));
        SendMessageW(Item(p,ProviderInput),CB_ADDSTRING,0,(LPARAM)name.c_str());
    }
    make(HistorySearch,L"EDIT",ES_AUTOHSCROLL|WS_BORDER|WS_TABSTOP);
    make(HistoryList,L"LISTBOX",LBS_NOTIFY|LBS_NOINTEGRALHEIGHT|WS_VSCROLL|WS_BORDER|WS_TABSTOP);
    make(SummaryScope,L"COMBOBOX",CBS_DROPDOWNLIST|WS_VSCROLL|WS_TABSTOP);
    make(SummaryDate,L"EDIT",ES_AUTOHSCROLL|WS_BORDER|WS_TABSTOP);
    SendMessageW(Item(p,KeyInput),EM_SETLIMITTEXT,512,0);
    SendMessageW(Item(p,ModelInput),CB_LIMITTEXT,160,0);
    SendMessageW(Item(p,SummaryDate),EM_SETLIMITTEXT,10,0);
    SendMessageW(Item(p,HistorySearch),EM_SETLIMITTEXT,200,0);
    Text(p,SummaryDate,LocalStamp().substr(0,10));
    Labels(p); InvalidateSummary(p);
    Text(p,Status,L(p,L"在正文中选中文字，按 Ctrl + Alt + D。",L"Select document text, then press Ctrl + Alt + D."));
    if (p->showIntro && HasPermission(Perm::SavePreferences)) SaveConfig(p->configPath,p->config);
    Layout(p);
    return p;
}
}
void DeepSeekInitialize(MainWindow* win) { Ensure(win); }
void DeepSeekLayout(MainWindow* win,Rect& available) {
    Panel* p=Get(win); if (!p) return;
    bool visible=p->open && !win->presentation;
    ShowWindow(p->hwnd,visible?SW_SHOWNA:SW_HIDE); if (!visible) return;
    int width=std::min(MulDiv(420,DpiGet(win->hwndFrame),96),available.dx*3/5);
    MoveWindow(p->hwnd,available.x+available.dx-width,available.y,width,available.dy,TRUE);
    available.dx-=width;
}
void DeepSeekToggle(MainWindow* win) {
    Panel* p=Get(win);
    if (p) { p->open=!p->open; if (!p->open) Cancel(p); }
    else p=Ensure(win);
    if (!p) return;
    SendMessageW(win->hwndFrame,WM_SIZE,0,0); SetFocus(win->hwndCanvas);
}
void DeepSeekExplain(MainWindow* win) {
    std::wstring selected,context; int page=0;
    bool captured=Capture(win,selected,context,page);
    Panel* p=Ensure(win); if (!p) return;
    p->open=true; p->view=View::Lookup; p->scrollY=0; p->showIntro=false; Cancel(p);
    p->selected=captured?selected:L""; p->context=captured?context:L""; p->page=page; p->file=CurrentFile(p);
    p->lookupRecord=Record(); Text(p,FollowupInput,L""); FollowupUI(p);
    p->highlightParts.clear(); p->highlightId.clear();
    if (captured) {
        auto tab=win->CurrentTab();
        if (tab->selectionOnPage) for (const auto& part:*tab->selectionOnPage)
            p->highlightParts.push_back({part.pageNo,part.rect});
        std::sort(p->highlightParts.begin(),p->highlightParts.end(),[](const HighlightPart& a,const HighlightPart& b){return a.page<b.page;});
        int first,from,last,to; win->AsFixed()->textSelection->GetGlyphRange(&first,&from,&last,&to);
        // Stable annotation name: distinguish identical words at different positions,
        // and recognize the same selection after saving/reopening the PDF.
        uint64_t hash=14695981039346656037ull;
        for (unsigned char c:Utf8(selected)) { hash^=c; hash*=1099511628211ull; }
        p->highlightId="DeepReader:v1:"+std::to_string(first)+":"+std::to_string(from)+":"+
            std::to_string(last)+":"+std::to_string(to)+":"+std::to_string(hash);
    }
    Text(p,Selected,p->selected); Text(p,ContextView,p->context); Text(p,Answer,L"");
    HighlightUI(p);
    SendMessageW(win->hwndFrame,WM_SIZE,0,0);
    if (!captured) {
        Text(p,Status,L(p,L"请拖选正文中的词句（不超过 2200 字符），再按 Ctrl + Alt + D。",L"Select document text (up to 2200 characters), then press Ctrl + Alt + D.")); return;
    }
    StartLookup(p);
    if (p->view!=View::Preferences) SetFocus(win->hwndCanvas);
}
void DeepSeekReset(MainWindow* win) {
    Panel* p=Get(win); if (!p || p->savingAnnotations) return;
    Cancel(p); p->selected.clear(); p->context.clear(); p->file.clear();
    p->lookupRecord=Record(); Text(p,FollowupInput,L""); FollowupUI(p);
    p->highlightParts.clear(); p->highlightId.clear();
    Text(p,Selected,L""); Text(p,ContextView,L""); Text(p,Answer,L""); InvalidateSummary(p);
    HighlightUI(p);
    Text(p,Status,L(p,L"在当前文档中选中文字，按 Ctrl + Alt + D。",L"Select text in this document, then press Ctrl + Alt + D."));
    Layout(p);
    // Upstream calls Reset before it replaces/closes the current tab's engine.
    PostMessageW(p->hwnd,kRefreshDocument,0,0);
}
void DeepSeekDestroy(MainWindow* win) { Panel* p=Get(win); if (p) DestroyWindow(p->hwnd); }
bool DeepSeekPreTranslate(MSG& msg) {
    MainWindow* win=FindMainWindowByHwnd(msg.hwnd); if (!win) return false;
    Panel* p=Get(win); if (!p || !p->open || !IsChild(p->hwnd,msg.hwnd)) return false;
    if (msg.message==WM_KEYDOWN) {
        if (msg.wParam==VK_ESCAPE) { DeepSeekToggle(win); return true; }
        bool ctrl=(GetKeyState(VK_CONTROL)&0x8000)!=0,alt=(GetKeyState(VK_MENU)&0x8000)!=0;
        if (ctrl && !alt && msg.wParam==VK_RETURN && msg.hwnd==Item(p,FollowupInput)) { StartFollowup(p); return true; }
        if (ctrl && alt && msg.wParam=='D') { DeepSeekExplain(win); return true; }
        WCHAR name[16]{}; GetClassNameW(msg.hwnd,name,16);
        if (ctrl && !alt && _wcsicmp(name,L"EDIT")==0) {
            if (msg.wParam=='C') { SendMessageW(msg.hwnd,WM_COPY,0,0); return true; }
            if (msg.wParam=='A') { SendMessageW(msg.hwnd,EM_SETSEL,0,-1); return true; }
        }
    }
    return IsDialogMessageW(p->hwnd,&msg)!=0;
}
