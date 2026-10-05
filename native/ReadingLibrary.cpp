// SPDX-License-Identifier: AGPL-3.0-or-later
#include "utils/BaseUtil.h"
#include "utils/JsonParser.h"
#include "DeepSeekCore.h"
#include "ReadingLibrary.h"
#include <algorithm>
#include <cwctype>
#include <set>

namespace deepseek {
static std::wstring Date(const SYSTEMTIME& t) {
    wchar_t b[32]; swprintf_s(b, L"%04u-%02u-%02u", t.wYear, t.wMonth, t.wDay); return b;
}
std::wstring LocalStamp() {
    SYSTEMTIME t; GetLocalTime(&t);
    wchar_t b[32]; swprintf_s(b, L"T%02u:%02u:%02u", t.wHour, t.wMinute, t.wSecond);
    TIME_ZONE_INFORMATION zone{};
    DWORD mode = GetTimeZoneInformation(&zone);
    LONG offset = -(zone.Bias + (mode == TIME_ZONE_ID_DAYLIGHT ? zone.DaylightBias : zone.StandardBias));
    wchar_t z[16]; swprintf_s(z, L"%c%02ld:%02ld", offset < 0 ? L'-' : L'+', labs(offset)/60, labs(offset)%60);
    return Date(t) + b + z;
}
std::wstring FileName(const std::wstring& path) {
    size_t n = path.find_last_of(L"/\\");
    return n == std::wstring::npos ? path : path.substr(n+1);
}
static int MonthDays(int y, int m) {
    const int d[] = {0,31,28,31,30,31,30,31,31,30,31,30,31};
    return d[m] + (m == 2 && y%4 == 0 && (y%100 != 0 || y%400 == 0) ? 1 : 0);
}
bool ValidDate(const std::wstring& s) {
    if (s.size() != 10 || s[4] != '-' || s[7] != '-') return false;
    for (size_t i=0; i<s.size(); ++i) if (i != 4 && i != 7 && (s[i] < '0' || s[i] > '9')) return false;
    int y = _wtoi(s.substr(0,4).c_str()), m = _wtoi(s.substr(5,2).c_str()), d = _wtoi(s.substr(8,2).c_str());
    return y >= 1601 && y <= 9998 && m >= 1 && m <= 12 && d >= 1 && d <= MonthDays(y,m);
}
bool PeriodRange(int scope, const std::wstring& anchor, std::wstring& first, std::wstring& last) {
    if (scope < 1 || scope > 3 || !ValidDate(anchor)) return false;
    SYSTEMTIME t{};
    t.wYear = (WORD)_wtoi(anchor.substr(0,4).c_str());
    t.wMonth = (WORD)_wtoi(anchor.substr(5,2).c_str());
    t.wDay = (WORD)_wtoi(anchor.substr(8,2).c_str());
    if (scope == 3) { t.wDay=1; first=Date(t); t.wDay=(WORD)MonthDays(t.wYear,t.wMonth); last=Date(t); return true; }
    FILETIME f{}; if (!SystemTimeToFileTime(&t, &f)) return false;
    if (!FileTimeToSystemTime(&f, &t)) return false;
    ULARGE_INTEGER n{}; n.LowPart=f.dwLowDateTime; n.HighPart=f.dwHighDateTime;
    const ULONGLONG day=864000000000ULL;
    if (scope == 2) n.QuadPart -= ((t.wDayOfWeek+6)%7)*day; // Monday, including year boundaries.
    f.dwLowDateTime=n.LowPart; f.dwHighDateTime=n.HighPart; FileTimeToSystemTime(&f,&t); first=Date(t);
    if (scope == 2) n.QuadPart += 6*day;
    f.dwLowDateTime=n.LowPart; f.dwHighDateTime=n.HighPart; FileTimeToSystemTime(&f,&t); last=Date(t);
    return true;
}
static bool ValidId(const std::wstring& id) {
    if (id.size() != 36) return false;
    for (wchar_t c : id) if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || c == '-')) return false;
    return true;
}
static bool ValidRecord(const Record& r) {
    return ValidId(r.id) && r.time.size() >= 19 && ValidDate(r.time.substr(0,10)) &&
        (r.kind == "explain" || r.kind == "file" || r.kind == "day" || r.kind == "week" || r.kind == "month") &&
        r.file.size() <= 32768 && r.title.size() <= 1024 && r.selected.size() <= 4000 && r.context.size() <= 5000 &&
        !r.answer.empty() && r.answer.size() <= 20000 && r.provider.size() < 64 && r.model.size() < 200 &&
        (r.language == "zh" || r.language == "en") && r.page >= 0;
}
bool SaveRecord(const std::wstring& dir, Record& r) {
    if (!CreateDirectoryW(dir.c_str(), nullptr) && GetLastError() != ERROR_ALREADY_EXISTS) return false;
    if (r.id.empty()) {
        GUID g{}; if (FAILED(CoCreateGuid(&g))) return false;
        wchar_t b[40]; StringFromGUID2(g,b,40);
        r.id=std::wstring(b+1,36);
        std::transform(r.id.begin(),r.id.end(),r.id.begin(),towlower);
    }
    if (r.time.empty()) r.time=LocalStamp();
    if (!ValidRecord(r)) return false;
    auto q = [](const std::wstring& s) { return JsonString(Utf8(s)); };
    std::string data="{\"Schema\":1,\"id\":"+q(r.id)+",\"time\":"+q(r.time)+",\"file\":"+q(r.file)+
        ",\"title\":"+q(r.title)+",\"selected\":"+q(r.selected)+",\"context\":"+q(r.context)+",\"answer\":"+q(r.answer)+
        ",\"kind\":"+JsonString(r.kind)+",\"provider\":"+JsonString(r.provider)+",\"model\":"+JsonString(r.model)+
        ",\"language\":"+JsonString(r.language)+",\"page\":"+std::to_string(r.page)+"}";
    return WriteFileAtomic(dir+L"\\"+r.id+L".json",data);
}
struct RecordVisitor : json::ValueVisitor {
    Record r;
    bool schema = false;
    bool Visit(const char* path, const char* value, json::Type type) override {
        if (!strcmp(path,"/Schema")) schema = type == json::Type::Number && !strcmp(value,"1");
        if (!strcmp(path,"/page") && type == json::Type::Number) r.page=atoi(value);
        if (type != json::Type::String) return true;
        if (!strcmp(path,"/id")) r.id=Wide(value);
        if (!strcmp(path,"/time")) r.time=Wide(value);
        if (!strcmp(path,"/file")) r.file=Wide(value);
        if (!strcmp(path,"/title")) r.title=Wide(value);
        if (!strcmp(path,"/selected")) r.selected=Wide(value);
        if (!strcmp(path,"/context")) r.context=Wide(value);
        if (!strcmp(path,"/answer")) r.answer=Wide(value);
        if (!strcmp(path,"/kind")) r.kind=value;
        if (!strcmp(path,"/provider")) r.provider=value;
        if (!strcmp(path,"/model")) r.model=value;
        if (!strcmp(path,"/language")) r.language=value;
        return true;
    }
};
bool LoadRecords(const std::wstring& dir, std::vector<Record>& records, int& unreadable) {
    records.clear(); unreadable=0;
    WIN32_FIND_DATAW f{};
    HANDLE search=FindFirstFileW((dir+L"\\*.json").c_str(),&f);
    if (search==INVALID_HANDLE_VALUE) return GetLastError()==ERROR_FILE_NOT_FOUND || GetLastError()==ERROR_PATH_NOT_FOUND;
    do {
        if (f.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) continue;
        std::string data; RecordVisitor v;
        if (!ReadFileText(dir+L"\\"+f.cFileName,data) || !json::Parse(data.c_str(),&v) || !v.schema ||
            !ValidRecord(v.r) || v.r.id+L".json" != f.cFileName) { ++unreadable; continue; }
        records.push_back(std::move(v.r));
    } while (FindNextFileW(search,&f));
    DWORD error=GetLastError(); FindClose(search);
    std::sort(records.begin(),records.end(),[](const Record& a,const Record& b) { return a.time==b.time ? a.id>b.id : a.time>b.time; });
    return error==ERROR_NO_MORE_FILES;
}
bool DeleteRecord(const std::wstring& dir,const std::wstring& id) {
    return ValidId(id) && DeleteFileW((dir+L"\\"+id+L".json").c_str()) != 0;
}
std::wstring RecordText(const Record& r, bool en) {
    return r.time+L" · "+Wide(r.provider)+L" / "+Wide(r.model)+L"\r\n"+r.title+L"\r\n"+
        (r.file.empty() ? L"" : FileName(r.file)+(r.page>0 ? L" · "+std::wstring(en?L"Page ":L"第 ")+std::to_wstring(r.page) : L"")+L"\r\n")+
        L"\r\n"+r.selected+L"\r\n\r\n"+r.answer+(r.context.empty()?L"":L"\r\n\r\n"+std::wstring(en?L"Source context:\r\n":L"原始语境：\r\n")+r.context);
}
bool Matches(const Record& r, const std::wstring& query) {
    std::wstring hay=r.title+L" "+FileName(r.file)+L" "+r.selected+L" "+r.answer+L" "+r.time;
    std::wstring needle=query;
    std::transform(hay.begin(),hay.end(),hay.begin(),towlower);
    std::transform(needle.begin(),needle.end(),needle.begin(),towlower);
    return hay.find(needle) != std::wstring::npos;
}
static std::wstring Fold(const std::wstring& value, bool path=false) {
    std::wstring result; bool space=false;
    for (auto c:value) {
        if (!path && iswspace(c)) { space=!result.empty(); continue; }
        if (space) result+=L' ';
        space=false; result+=path && c==L'/' ? L'\\' : (wchar_t)towlower(c);
    }
    return result;
}
ReadingStats CountReading(const std::vector<Record>& records,const std::wstring& first,
    const std::wstring& last,const std::wstring& file) {
    ReadingStats stats;
    std::set<std::wstring> words,files,days;
    for (const auto& r:records) {
        auto date=r.time.substr(0,10);
        if (!ValidDate(date) || (!first.empty() && date<first) || (!last.empty() && date>last) ||
            (!file.empty() && Fold(file,true)!=Fold(r.file,true)) || (r.kind!="explain" && r.kind!="file")) continue;
        if (r.kind=="explain") { ++stats.lookups; words.insert(Fold(r.selected)); }
        else ++stats.fileSummaries;
        if (!r.file.empty()) files.insert(Fold(r.file,true));
        days.insert(date);
    }
    stats.uniqueSelections=words.size(); stats.files=files.size(); stats.days=days.size();
    return stats;
}
std::wstring StatsText(const ReadingStats& s,size_t total,bool en) {
    if (en) return L"All-time successful lookups: "+std::to_wstring(total)+
        L"\r\nIn this scope: "+std::to_wstring(s.lookups)+L" lookups · "+std::to_wstring(s.uniqueSelections)+L" distinct selections"+
        L"\r\nRepeat lookups: "+std::to_wstring(s.lookups-s.uniqueSelections)+L" · Documents: "+std::to_wstring(s.files)+
        L"\r\nFile summaries: "+std::to_wstring(s.fileSummaries)+L" · Active days: "+std::to_wstring(s.days)+
        L"\r\nBased on saved records; failed requests are excluded.";
    return L"累计成功查询："+std::to_wstring(total)+L" 次"+
        L"\r\n本范围：查询 "+std::to_wstring(s.lookups)+L" 次 · 不同词句 "+std::to_wstring(s.uniqueSelections)+L" 个"+
        L"\r\n重复查询："+std::to_wstring(s.lookups-s.uniqueSelections)+L" 次 · 涉及文件："+std::to_wstring(s.files)+L" 份"+
        L"\r\n文件总结："+std::to_wstring(s.fileSummaries)+L" 次 · 活跃日期："+std::to_wstring(s.days)+L" 天"+
        L"\r\n按已保存记录统计，不含失败请求。";
}
std::wstring ReviewSource(const std::vector<Record>& records, const std::wstring& first, const std::wstring& last, size_t& count) {
    count=0; std::wstring source;
    for (const auto& r:records) {
        auto date=r.time.substr(0,10);
        if (date<first || date>last || (r.kind!="explain" && r.kind!="file")) continue;
        ++count;
        source+=L"\n[Record "+std::to_wstring(count)+L" | type: "+(r.kind=="file"?L"document summary":L"lookup")+L" | "+date+L" | "+FileName(r.file)+L" | page "+std::to_wstring(r.page)+L"]\n"+
            r.selected+L"\nContext: "+r.context+L"\nSaved answer: "+r.answer+L"\n";
        // Explicit failure rather than silently dropping old records.
        if (source.size()>2000000) return L"";
    }
    return source;
}
std::vector<std::wstring> Chunks(const std::wstring& text, size_t limit) {
    std::vector<std::wstring> out;
    if (limit<4) return out;
    size_t start=0;
    while (start<text.size()) {
        size_t end=std::min(start+limit,text.size());
        if (end<text.size()) {
            size_t split=text.find_last_of(L"\n .。；;",end-1);
            if (split != std::wstring::npos && split>start+limit*3/4) end=split+1;
            if (text[end-1]>=0xd800 && text[end-1]<=0xdbff) --end;
        }
        out.push_back(text.substr(start,end-start)); start=end;
    }
    return out;
}
size_t SummaryRequests(size_t parts) {
    if (parts<=1) return parts;
    size_t requests=parts;
    while (parts>3) { parts=(parts+2)/3; requests+=parts; }
    return requests+1;
}
}
