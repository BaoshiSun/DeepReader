// SPDX-License-Identifier: AGPL-3.0-or-later
#include "utils/BaseUtil.h"
#include "utils/JsonParser.h"
#include "DeepSeekCore.h"
#include "ReadingLibrary.h"
#include <string>
static int failures=0;
void _uploadDebugReport(const char*,bool,bool) { fprintf(stderr,"FAIL: unexpected native assertion\n"); exit(1); }
static void Check(bool ok,const char* label) { printf("%s: %s\n",ok?"PASS":"FAIL",label); if (!ok) ++failures; }
struct Contract : json::ValueVisitor {
    std::string model,system,input;
    bool freePrompt=false,freeCompletion=false,freeRequest=false,thinking=false;
    bool Visit(const char* path,const char* value,json::Type type) override {
        if (!strcmp(path,"/model")) model=value;
        if (!strcmp(path,"/messages[0]/content")) system=value;
        if (!strcmp(path,"/messages[1]/content")) input=value;
        if (!strcmp(path,"/provider/max_price/prompt")) freePrompt=!strcmp(value,"0");
        if (!strcmp(path,"/provider/max_price/completion")) freeCompletion=!strcmp(value,"0");
        if (!strcmp(path,"/provider/max_price/request")) freeRequest=!strcmp(value,"0");
        if (!strcmp(path,"/thinking/type")) thinking=!strcmp(value,"disabled");
        return true;
    }
};
struct Input : json::ValueVisitor {
    std::string selected, context, conversation, question;
    bool Visit(const char* path,const char* value,json::Type type) override {
        if (!strcmp(path,"/selected") && type==json::Type::String) selected=value;
        if (!strcmp(path,"/context") && type==json::Type::String) context=value;
        if (!strcmp(path,"/conversation") && type==json::Type::String) conversation=value;
        if (!strcmp(path,"/question") && type==json::Type::String) question=value;
        return true;
    }
};
int wmain(int argc,WCHAR** argv) {
    using namespace deepseek;
    Check(Wide(Utf8(L"银行 🏦 中文\n\"test\""))==L"银行 🏦 中文\n\"test\"","Unicode round trip");
    auto marked=Context(L"The river bank was steep, but the ",L"bank",L" approved a loan.");
    Check(marked.find(L"the ⟦bank⟧ approved")!=std::wstring::npos && marked.find(L"river bank")!=std::wstring::npos,"exact selected occurrence, including repeated words");
    auto bounded=Context(std::wstring(5000,L'a'),std::wstring(2200,L'b'),std::wstring(5000,L'c'));
    Check(bounded.size()<=3000 && bounded.find(std::wstring(2200,L'b'))!=std::wstring::npos,"bounded context preserves selection");
    Check(Context(L"",std::wstring(2201,L'x'),L"").empty() && Context(L"text",L"",L"text").empty(),"empty and oversize selections rejected");
    Config c; Contract direct;
    auto defaultBody=RequestBody(c,Task::Explain,marked,L"bank");
    Check(c.provider==DeepSeek && std::wstring(Service(c.provider).host)==L"api.deepseek.com" &&
        std::wstring(Service(c.provider).path)==L"/chat/completions" && c.keys[DeepSeek].empty() &&
        c.keys[OpenRouter].empty() && c.keys[Gemini].empty(),"new configuration defaults to official DeepSeek without preconfigured credentials");
    Check(json::Parse(defaultBody.c_str(),&direct) && direct.model=="deepseek-flash" && direct.thinking && !direct.freePrompt,
        "default request uses DeepSeek Flash and provider-specific parameters");
    c.provider=OpenRouter; Contract free;
    auto body=RequestBody(c,Task::Explain,marked,L"bank\"\n\t");
    Check(json::Parse(body.c_str(),&free) && free.model=="openrouter/free" && free.freePrompt && free.freeCompletion && free.freeRequest,"optional free router enforces zero token and request prices");
    Input input;
    Check(json::Parse(free.input.c_str(),&input) && input.selected=="bank\"\n\t" && free.system.find("untrusted")!=std::string::npos,"quoted selection is data, not system instructions");
    c.english=true; Contract en;
    auto english=RequestBody(c,Task::Explain,marked,L"bank");
    Check(json::Parse(english.c_str(),&en) && en.system.find("Respond in natural English")!=std::string::npos,"English changes the answer instruction");
    c.provider=DeepSeek; Contract ds;
    auto deep=RequestBody(c,Task::Explain,marked,L"bank");
    Check(json::Parse(deep.c_str(),&ds) && ds.model=="deepseek-flash" && ds.thinking && !ds.freePrompt,"legacy DeepSeek request remains provider-specific");
    c.provider=Gemini;
    Check(std::wstring(Service(c.provider).host)==L"generativelanguage.googleapis.com" && RequestBody(c,Task::Review,L"record").find("\"thinking\"")==std::string::npos,"Gemini routes to its own HTTPS host without DeepSeek parameters");
    c.provider=OpenRouter; c.models[0]="openai/gpt-6.1-sol";
    Check(!FreeModel(c) && RequestBody(c,Task::Explain,marked).find("max_price")==std::string::npos,"paid model is an explicit configuration choice");
    c.models[0]="vendor/model:free";
    Check(FreeModel(c),"custom free variants retain zero-price protection");
    std::wstring question=L"为什么是\"银行\"？\n请举个例子。";
    Contract follow; Input followInput;
    auto followBody=RequestBody(c,Task::Followup,marked,L"bank",L"此处指银行。",question);
    Check(json::Parse(followBody.c_str(),&follow) && json::Parse(follow.input.c_str(),&followInput) &&
        followInput.selected=="bank" && followInput.context==Utf8(marked) && followInput.conversation==Utf8(L"此处指银行。") &&
        followInput.question==Utf8(question),"follow-up sends exact selection, context, existing conversation and escaped question");
    Check(follow.freePrompt && follow.freeCompletion && follow.freeRequest && follow.system.find("Respond in natural English")!=std::string::npos &&
        follow.system.find("untrusted document data")!=std::string::npos,"follow-up preserves free-price limits, current language and source-data boundary");
    c.provider=DeepSeek; c.english=false; Contract followChinese;
    Check(json::Parse(RequestBody(c,Task::Followup,marked,L"bank",L"Original answer",L"举例").c_str(),&followChinese) &&
        followChinese.thinking && followChinese.system.find("简体中文")!=std::string::npos,"DeepSeek follow-up keeps provider-specific parameters and Chinese response instruction");
    auto conversation=FollowupTranscript(L"此处指银行。",question,L"因为它批准了贷款。",false,L"DeepSeek / fixture-model");
    auto secondTurn=FollowupTranscript(conversation,L"再简短些",L"银行批准贷款。",false,L"DeepSeek / fixture-model");
    Check(secondTurn.find(question)!=std::wstring::npos && secondTurn.find(L"此处指银行。")!=std::wstring::npos &&
        secondTurn.find(L"再简短些")!=std::wstring::npos && secondTurn.find(L"银行批准贷款。")!=std::wstring::npos,
        "multiple follow-ups preserve the original answer and every successful question/answer pair");
    Check(!CanFollowup(L"answer",L" \r\n\t　") && !CanFollowup(L"",question) &&
        !CanFollowup(L"answer",std::wstring(FollowupQuestionLimit+1,L'x')) &&
        !CanFollowup(std::wstring(FollowupConversationLimit+1,L'x'),question),"empty, oversized and missing-context follow-ups are rejected");
    Check(RequestBody(c,Task::Followup,marked,L"bank",L"",question).empty() &&
        FollowupTranscript(L"answer",question,L"",false,L"model").empty() &&
        FollowupTranscript(L"answer",question,std::wstring(20000,L'x'),false,L"model").empty(),
        "invalid requests and oversized replies cannot silently truncate or replace a conversation");
    Check(!ValidModel("bad model\r\n") && ValidModel("anthropic/claude-sonnet-5.5"),"invalid model identifiers rejected");
    Check(Response("{\"choices\":[{\"message\":{\"content\":\"此处指银行。\"}}],\"model\":\"actual-free-model\"}",200,false).ok,"chat completion response accepted");
    Check(Response("{\"choices\":[{\"message\":{\"content\":\"text\"},\"finish_reason\":\"length\"}]}",200,false).ok==false,"truncated answers are never saved as complete");
    Check(!Response("{bad json",200,true).ok && !Response("{\"error\":{\"message\":\"secret\"}}",200,true).ok,"malformed and embedded API errors fail closed");
    Check(Response("{\"error\":\"SECRET\"}",401,true).text.find(L"SECRET")==std::wstring::npos,"errors do not echo credentials or service payloads");
    Check(Response("{}",429,true).text.find(L"quota")!=std::wstring::npos,"rate and free-quota error is actionable");
    Check(!ValidKey("test\r\nInjected: header") && !ValidKey(" ") && ValidKey("synthetic-test-key"),"HTTP header injection rejected");
    auto encrypted=Protect("synthetic-test-key");
    Check(!encrypted.empty() && Unprotect(encrypted)=="synthetic-test-key" && Unprotect("bad ciphertext").empty(),"current-user credential encryption and invalid ciphertext");
    std::wstring first,last;
    Check(PeriodRange(1,L"2026-10-05",first,last) && first==L"2026-10-05" && last==first,"daily boundaries");
    Check(PeriodRange(2,L"2026-01-01",first,last) && first==L"2025-12-29" && last==L"2026-01-04","Monday-based week spans new year");
    Check(PeriodRange(3,L"2024-02-29",first,last) && first==L"2024-02-01" && last==L"2024-02-29","monthly boundary handles leap year");
    Check(!ValidDate(L"2026-02-29") && !ValidDate(L"2026-13-01") && !PeriodRange(2,L"not-date",first,last),"invalid dates rejected without normalization");
    std::wstring source(11999,L'x'); source+=L"😀"; source+=std::wstring(28000,L'y');
    auto parts=Chunks(source); std::wstring joined;
    bool limits=true;
    for (const auto& part:parts) {
        joined+=part; limits=limits && !part.empty() && part.size()<=12000 &&
            !(part.back()>=0xd800 && part.back()<=0xdbff) && !(part.front()>=0xdc00 && part.front()<=0xdfff);
    }
    Check(limits && joined==source,"long document chunking preserves every character and surrogate pair");
    Check(SummaryRequests(1)==1 && SummaryRequests(4)==7 && SummaryRequests(10)==17,"bounded hierarchical summary request estimate");
    Record a; a.id=L"11111111-1111-1111-1111-111111111111"; a.time=L"2026-10-05T12:00:00+03:00";
    a.file=L"C:\\PRIVATE\\paper.pdf"; a.title=L"paper.pdf"; a.selected=L"bank"; a.context=marked; a.answer=L"银行";
    a.provider="OpenRouter"; a.model="free"; a.page=1;
    Record b=a; b.time=L"2026-10-04T23:59:00+03:00";
    Record recursive=a; recursive.kind="week";
    Record doc=a; doc.kind="file"; doc.answer=L"Saved document summary";
    size_t count=0; auto review=ReviewSource({a,b,recursive,doc},L"2026-10-05",L"2026-10-05",count);
    Check(count==2 && review.find(L"Saved document summary")!=std::wstring::npos,"review includes current lookups and file summaries only, avoiding recursive reviews");
    Check(review.find(L"C:\\PRIVATE")==std::wstring::npos && review.find(L"paper.pdf")!=std::wstring::npos,"summary requests omit local directory paths");
    Check(Matches(a,L"BANK") && Matches(a,L"银行") && !Matches(a,L"absent"),"history search matches source and answers");
    Record repeated=a; repeated.selected=L"  BANK \t"; repeated.file=L"c:/private/PAPER.pdf";
    Record other=b; other.file=L"C:\\PRIVATE\\second.pdf"; other.selected=L"loan";
    Record invalid=a; invalid.time=L"not-a-date";
    auto all=CountReading({a,b,repeated,other,doc,recursive,invalid});
    Check(all.lookups==4 && all.uniqueSelections==2 && all.files==2 && all.fileSummaries==1 && all.days==2,
        "statistics count saved lookups, distinct normalized text, documents and active dates; period summaries excluded");
    auto day=CountReading({a,b,repeated,other,doc,recursive,invalid},L"2026-10-05",L"2026-10-05");
    Check(day.lookups==2 && day.uniqueSelections==1 && day.files==1 && day.fileSummaries==1 && day.days==1,
        "daily statistics use inclusive local calendar boundaries");
    auto file=CountReading({a,b,repeated,other,doc,recursive,invalid},L"",L"",L"C:/PRIVATE/paper.pdf");
    Check(file.lookups==3 && file.uniqueSelections==1 && file.files==1 && file.fileSummaries==1,
        "file statistics normalize Windows path case and separators");
    Check(CountReading({a,b},L"2000-01-01",L"2000-01-31").lookups==0 && CountReading({}).days==0,
        "empty statistics remain zero rather than inventing reading activity");
    Check(StatsText(all,4,false).find(L"累计成功查询：4 次")!=std::wstring::npos &&
        StatsText(all,4,true).find(L"Repeat lookups: 2")!=std::wstring::npos,
        "bilingual statistics display verified cumulative and repeat counts");
    if (argc>1) {
        std::wstring path=argv[1];
        Config original; original.provider=OpenRouter; original.keys[DeepSeek]=encrypted; original.keys[OpenRouter]=Protect("other-synthetic-key"); original.english=true;
        original.onboardingSeen=true; original.lookupSplit=65;
        Check(SaveConfig(path,original),"multi-provider settings written atomically");
        Config restored;
        Check(ReadConfig(path,restored) && restored.english && restored.provider==OpenRouter &&
            Unprotect(restored.keys[DeepSeek])=="synthetic-test-key" && Unprotect(restored.keys[OpenRouter])=="other-synthetic-key","explicit OpenRouter choice, provider credentials and language survive reload without mixing");
        Check(restored.onboardingSeen && restored.lookupSplit==65,"guide completion and selected/explanation ratio survive restart");
        Check(!Config().onboardingSeen && Config().lookupSplit==50,"new profiles start with one-time guide and equal reading panes");
        WriteFileAtomic(path,"{\"Schema\":3,\"Provider\":\"DeepSeek\",\"LookupSplit\":999}");
        Check(ReadConfig(path,restored) && restored.onboardingSeen && restored.lookupSplit==50,
            "existing profiles skip onboarding and invalid split values use a safe default");
        original.onboardingSeen=false; SaveConfig(path,original);
        Check(ReadConfig(path,restored) && !restored.onboardingSeen,"explicit unfinished onboarding state round trips");
        WriteFileAtomic(path,"{\"ProtectedKey\":"+JsonString(encrypted)+",\"Model\":\"deepseek-flash\"}");
        Check(ReadConfig(path,restored) && restored.provider==DeepSeek && restored.keys[OpenRouter].empty() &&
            Unprotect(restored.keys[DeepSeek])=="synthetic-test-key","legacy configuration keeps the official DeepSeek provider and key slot");
        auto dir=path+L".history";
        Check(SaveRecord(dir,a),"query including contextual answer saved atomically");
        std::vector<Record> loaded; int bad=0;
        Check(LoadRecords(dir,loaded,bad) && !bad && loaded.size()==1 && loaded[0].context==marked && loaded[0].answer==L"银行","persisted query reloads without data loss");
        auto originalId=a.id, originalTime=a.time; a.answer=secondTurn;
        Check(SaveRecord(dir,a) && a.id==originalId && a.time==originalTime && LoadRecords(dir,loaded,bad) &&
            loaded.size()==1 && loaded[0].answer==secondTurn && Matches(loaded[0],question) && CountReading(loaded).lookups==1,
            "follow-ups update the original searchable history record without duplicating lookup statistics");
        Check(RecordText(loaded[0],false).find(question)!=std::wstring::npos &&
            ReviewSource(loaded,L"2026-10-05",L"2026-10-05",count).find(L"银行批准贷款。")!=std::wstring::npos,
            "history export and reading reviews include saved follow-up answers");
        Check(!DeleteRecord(dir,L"..\\outside"),"history deletion cannot escape its directory");
        WriteFileAtomic(dir+L"\\broken.json","bad json");
        Check(LoadRecords(dir,loaded,bad) && bad==1 && loaded.size()==1,"corrupt history is reported without losing good records");
        DeleteFileW((dir+L"\\broken.json").c_str());
        Check(DeleteRecord(dir,a.id),"delete targets only the selected valid record ID");
        RemoveDirectoryW(dir.c_str());
        DeleteFileW(path.c_str()); // Synthetic encrypted credentials must not survive a test run.
    }
    if (argc>2) {
        Config imported;
        Check(ReadConfig(argv[2],imported),"existing credential config parses without exposing key");
        Check(ValidKey(Unprotect(imported.keys[DeepSeek])),"existing DeepSeek key remains usable in this security context");
    }
    return failures?1:0;
}
