// SPDX-License-Identifier: AGPL-3.0-or-later
#include "utils/BaseUtil.h"
#include "utils/JsonParser.h"
#include "DeepSeekCore.h"
#include "BookLibrary.h"
#include <shlobj.h>
#include <algorithm>
#include <cwctype>
#include <mutex>

namespace deepseek {
// The copy worker and reader windows can update the same local book.
static std::recursive_mutex bookMutex;
static std::wstring Fold(std::wstring value) {
    std::transform(value.begin(), value.end(), value.begin(), towlower);
    return value;
}
static bool ValidId(const std::wstring& id) {
    if (id.size() != 36) return false;
    for (size_t i=0; i<id.size(); ++i) {
        if (i==8 || i==13 || i==18 || i==23) { if (id[i]!='-') return false; }
        else if (!((id[i]>='0' && id[i]<='9') || (id[i]>='a' && id[i]<='f'))) return false;
    }
    return true;
}
static std::wstring NewId() {
    GUID g{}; if (FAILED(CoCreateGuid(&g))) return L"";
    wchar_t value[40]; StringFromGUID2(g,value,40); return Fold(std::wstring(value+1,36));
}
static bool ValidPath(const std::wstring& path) {
    return !path.empty() && path.size()<32768 && path.find_first_of(L"\r\n") == std::wstring::npos &&
        ((path.size()>2 && iswalpha(path[0]) && path[1]==':' && (path[2]=='\\' || path[2]=='/')) ||
        path.substr(0,2)==L"\\\\");
}
bool SameBookPath(const std::wstring& a, const std::wstring& b) {
    if (a.empty() || b.empty()) return false;
    auto normalize=[](const std::wstring& value) {
        std::wstring path(32768,0);
        DWORD n=GetFullPathNameW(value.c_str(),(DWORD)path.size(),path.data(),nullptr);
        path=n && n<path.size() ? path.substr(0,n) : value;
        std::replace(path.begin(),path.end(),L'/',L'\\'); return Fold(path);
    };
    return normalize(a)==normalize(b);
}
bool BookHasPath(const Book& b, const std::wstring& file) {
    if (SameBookPath(b.file,file) || SameBookPath(b.archivePath,file)) return true;
    for (const auto& copy:b.copies) if (SameBookPath(copy,file)) return true;
    return false;
}
static bool ValidBook(const Book& b) {
    if (!ValidId(b.id) || !ValidPath(b.file) || b.title.empty() || b.title.size()>1024 || b.rating<0 || b.rating>5 ||
        !ValidDate(b.added.substr(0,10)) || !ValidDate(b.updated.substr(0,10)) ||
        (b.finished ? !ValidDate(b.finishedAt.substr(0,10)) : !b.finishedAt.empty()) ||
        (!b.archivePath.empty() && !ValidPath(b.archivePath)) || b.copies.size()>1000) return false;
    for (const auto& copy:b.copies) if (!ValidPath(copy)) return false;
    return true;
}
bool SaveBook(const std::wstring& dir, Book& b) {
    std::lock_guard<std::recursive_mutex> lock(bookMutex);
    if (b.id.empty()) b.id=NewId();
    if (b.added.empty()) b.added=LocalStamp();
    b.updated=LocalStamp();
    if (!ValidBook(b)) return false;
    if (!CreateDirectoryW(dir.c_str(),nullptr) && GetLastError()!=ERROR_ALREADY_EXISTS) return false;
    auto q=[](const std::wstring& s) { return JsonString(Utf8(s)); };
    std::string json="{\"Schema\":1,\"id\":"+q(b.id)+",\"file\":"+q(b.file)+",\"title\":"+q(b.title)+
        ",\"added\":"+q(b.added)+",\"updated\":"+q(b.updated)+",\"rating\":"+std::to_string(b.rating)+
        ",\"finished\":"+(b.finished?"true":"false")+",\"finishedAt\":"+q(b.finishedAt)+
        ",\"archivePath\":"+q(b.archivePath)+",\"copies\":[";
    for (size_t i=0;i<b.copies.size();++i) { if (i) json+=','; json+=q(b.copies[i]); }
    return json.size()<1024*1024-2 && WriteFileAtomic(dir+L"\\"+b.id+L".json",json+"]}");
}
struct BookVisitor : json::ValueVisitor {
    Book b; bool schema=false,valid=true;
    bool Visit(const char* path,const char* value,json::Type type) override {
        if (!strcmp(path,"/Schema")) schema=type==json::Type::Number && !strcmp(value,"1");
        if (!strcmp(path,"/rating")) {
            valid=valid && type==json::Type::Number && strlen(value)==1 && value[0]>='0' && value[0]<='5';
            b.rating=atoi(value);
        }
        if (!strcmp(path,"/finished")) { valid=valid && type==json::Type::Bool; b.finished=!strcmp(value,"true"); }
        if (type!=json::Type::String) return true;
        if (!strcmp(path,"/id")) b.id=Wide(value);
        if (!strcmp(path,"/file")) b.file=Wide(value);
        if (!strcmp(path,"/title")) b.title=Wide(value);
        if (!strcmp(path,"/added")) b.added=Wide(value);
        if (!strcmp(path,"/updated")) b.updated=Wide(value);
        if (!strcmp(path,"/finishedAt")) b.finishedAt=Wide(value);
        if (!strcmp(path,"/archivePath")) b.archivePath=Wide(value);
        if (!strncmp(path,"/copies[",8)) b.copies.push_back(Wide(value));
        return true;
    }
};
static bool ReadBook(const std::wstring& dir,const std::wstring& id,Book& book) {
    if (!ValidId(id)) return false;
    std::string data; BookVisitor v;
    if (!ReadFileText(dir+L"\\"+id+L".json",data,1024*1024) || !json::Parse(data.c_str(),&v) ||
        !v.schema || !v.valid || !ValidBook(v.b) || v.b.id!=id) return false;
    book=std::move(v.b); return true;
}
bool LoadBooks(const std::wstring& dir,std::vector<Book>& books,int& unreadable) {
    std::lock_guard<std::recursive_mutex> lock(bookMutex);
    books.clear(); unreadable=0;
    WIN32_FIND_DATAW f{}; HANDLE search=FindFirstFileW((dir+L"\\*.json").c_str(),&f);
    if (search==INVALID_HANDLE_VALUE) return GetLastError()==ERROR_FILE_NOT_FOUND || GetLastError()==ERROR_PATH_NOT_FOUND;
    do {
        if (f.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) continue;
        std::wstring name=f.cFileName; Book b;
        if (name.size()!=41 || !ReadBook(dir,name.substr(0,36),b)) { ++unreadable; continue; }
        books.push_back(std::move(b));
    } while (FindNextFileW(search,&f));
    DWORD error=GetLastError(); FindClose(search);
    std::sort(books.begin(),books.end(),[](const Book& a,const Book& b) { return a.updated==b.updated ? a.title<b.title : a.updated>b.updated; });
    return error==ERROR_NO_MORE_FILES;
}
bool FindBook(const std::wstring& dir,const std::wstring& file,Book& book,bool create) {
    std::lock_guard<std::recursive_mutex> lock(bookMutex);
    std::vector<Book> books; int bad=0;
    if (!LoadBooks(dir,books,bad)) return false;
    for (const auto& b:books) if (BookHasPath(b,file)) { book=b; return true; }
    if (!create || !ValidPath(file)) return false;
    Book b; b.file=file; b.title=FileName(file);
    if (!SaveBook(dir,b)) return false;
    book=b; return true;
}
void SetBookFinished(Book& b,bool finished) {
    if (finished && !b.finished) b.finishedAt=LocalStamp();
    if (!finished) b.finishedAt.clear();
    b.finished=finished;
}
bool UpdateBook(const std::wstring& dir,Book& book,int rating,int state) {
    std::lock_guard<std::recursive_mutex> lock(bookMutex);
    Book next;
    if (!ReadBook(dir,book.id,next)) return false;
    if (rating>=1 && rating<=5) next.rating=rating;
    if (state>=0 && state<=1) SetBookFinished(next,state==1);
    if (!SaveBook(dir,next)) return false;
    book=next; return true;
}
bool BookMatches(const Book& b,const std::wstring& query,int filter) {
    return !(filter==1 && b.finished) && !(filter==2 && !b.finished) &&
        Fold(b.title+L" "+b.file+L" "+b.finishedAt).find(Fold(query))!=std::wstring::npos;
}
std::wstring BookOverview(const std::vector<Book>& books,bool en) {
    size_t finished=0,rated=0,stars=0;
    for (const auto& b:books) { if (b.finished) ++finished; if (b.rating) { ++rated; stars+=b.rating; } }
    wchar_t average[32]; swprintf_s(average,L"%.1f",rated?(double)stars/rated:0.0);
    return en ? L"Books: "+std::to_wstring(books.size())+L" · Reading: "+std::to_wstring(books.size()-finished)+
        L" · Finished: "+std::to_wstring(finished)+L"\r\nRated: "+std::to_wstring(rated)+L" · Average: "+(rated?average:L"—")+L" / 5" :
        L"书单 "+std::to_wstring(books.size())+L" 本 · 阅读中 "+std::to_wstring(books.size()-finished)+L" 本 · 读完 "+std::to_wstring(finished)+
        L" 本\r\n已评分 "+std::to_wstring(rated)+L" 本 · 平均 "+(rated?average:L"—")+L" / 5 星";
}
std::wstring BookText(const Book& b,const std::vector<Record>& records,bool en) {
    std::wstring text=b.title+L"\r\n"+(b.rating?std::wstring(b.rating,L'★')+std::wstring(5-b.rating,L'☆'):(en?L"Unrated":L"未评分"))+
        L" · "+(b.finished?(en?L"Finished":L"读完"):(en?L"Reading":L"阅读中"))+
        L"\r\n"+(en?L"Added: ":L"加入书单：")+b.added.substr(0,10);
    if (b.finished) text+=L"\r\n"+std::wstring(en?L"Completed: ":L"完成日期：")+b.finishedAt.substr(0,10);
    text+=L"\r\n"+std::wstring(en?L"Original: ":L"原文件：")+b.file;
    if (!b.archivePath.empty()) text+=L"\r\n"+std::wstring(en?L"Archived copy: ":L"归档副本：")+b.archivePath;
    const Record* summary=nullptr;
    for (const auto& r:records) if (r.kind=="file" && BookHasPath(b,r.file) && (!summary || r.time>summary->time)) summary=&r;
    text+=L"\r\n\r\n"+std::wstring(en?L"Saved AI summary\r\n":L"已保存的 AI 总结\r\n");
    return text+(summary?summary->answer:(en?L"No document summary yet. Open this book and generate one in Summary.":L"暂无全文总结。打开本书后，可在“总结”页生成并保存。"));
}
std::wstring BookListText(const std::vector<Book>& books,const std::vector<Record>& records,bool en) {
    std::wstring text=(en?L"DeepReader · Reading list\r\n":L"DeepReader · 阅读书单\r\n")+BookOverview(books,en);
    for (const auto& b:books) text+=L"\r\n\r\n────────────\r\n"+BookText(b,records,en);
    return text;
}
static bool Exists(const std::wstring& file) {
    DWORD a=GetFileAttributesW(file.c_str()); return a!=INVALID_FILE_ATTRIBUTES && !(a&FILE_ATTRIBUTE_DIRECTORY);
}
std::wstring BookOpenPath(const Book& b) {
    if (Exists(b.file)) return b.file;
    if (Exists(b.archivePath)) return b.archivePath;
    for (auto i=b.copies.rbegin();i!=b.copies.rend();++i) if (Exists(*i)) return *i;
    return L"";
}
static bool EqualFiles(const std::wstring& a,const std::wstring& b,std::atomic<bool>& stopped) {
    HANDLE x=CreateFileW(a.c_str(),GENERIC_READ,FILE_SHARE_READ,nullptr,OPEN_EXISTING,FILE_FLAG_SEQUENTIAL_SCAN,nullptr);
    HANDLE y=CreateFileW(b.c_str(),GENERIC_READ,FILE_SHARE_READ,nullptr,OPEN_EXISTING,FILE_FLAG_SEQUENTIAL_SCAN,nullptr);
    LARGE_INTEGER sx{},sy{};
    bool equal=x!=INVALID_HANDLE_VALUE && y!=INVALID_HANDLE_VALUE && GetFileSizeEx(x,&sx) && GetFileSizeEx(y,&sy) && sx.QuadPart==sy.QuadPart;
    char ax[65536],by[65536]; DWORD nx=0,ny=0;
    while (equal && !stopped) {
        equal=ReadFile(x,ax,sizeof(ax),&nx,nullptr) && ReadFile(y,by,sizeof(by),&ny,nullptr) && nx==ny && !memcmp(ax,by,nx);
        if (!nx) break;
    }
    if (x!=INVALID_HANDLE_VALUE) CloseHandle(x);
    if (y!=INVALID_HANDLE_VALUE) CloseHandle(y);
    return equal && !stopped;
}
static DWORD CALLBACK CopyProgress(LARGE_INTEGER,LARGE_INTEGER,LARGE_INTEGER,LARGE_INTEGER,DWORD,DWORD,HANDLE,HANDLE,LPVOID data) {
    return ((std::atomic<bool>*)data)->load()?PROGRESS_CANCEL:PROGRESS_CONTINUE;
}
ArchiveResult ArchiveBook(const std::wstring& dir,const Book& book,const std::wstring& source,
    const std::wstring& root,std::atomic<bool>& stopped) {
    ArchiveResult result;
    if (stopped || !ValidBook(book) || book.rating<1 || !ValidPath(root) || !BookHasPath(book,source) || !Exists(source) ||
        Fold(source).size()<4 || Fold(source).substr(source.size()-4)!=L".pdf") { result.error=ERROR_INVALID_PARAMETER; return result; }
    std::wstring folder=root;
    while (!folder.empty() && (folder.back()=='\\' || folder.back()=='/')) folder.pop_back();
    folder+=L"\\"+std::to_wstring(book.rating)+L"星";
    int error=SHCreateDirectoryExW(nullptr,folder.c_str(),nullptr);
    if (error!=ERROR_SUCCESS && error!=ERROR_ALREADY_EXISTS && error!=ERROR_FILE_EXISTS) { result.error=error; return result; }
    auto name=FileName(book.file),stem=name.substr(0,name.size()-4);
    std::wstring target=folder+L"\\"+name;
    auto publish=[&](const std::wstring& path) {
        std::lock_guard<std::recursive_mutex> lock(bookMutex);
        Book latest;
        if (!ReadBook(dir,book.id,latest)) return false;
        latest.archivePath=path;
        bool known=false; for (const auto& copy:latest.copies) if (SameBookPath(copy,path)) known=true;
        if (!known) latest.copies.push_back(path);
        return SaveBook(dir,latest);
    };
    // Repeated clicks reuse an identical copy. Modified PDFs get a new name.
    if (!book.archivePath.empty() && SameBookPath(folder,book.archivePath.substr(0,book.archivePath.find_last_of(L"\\/"))) &&
        EqualFiles(source,book.archivePath,stopped)) target=book.archivePath;
    else if (!SameBookPath(source,target) && Exists(target) && !EqualFiles(source,target,stopped)) target.clear();
    if (!target.empty() && (SameBookPath(source,target) || EqualFiles(source,target,stopped))) {
        if (stopped) { result.error=ERROR_REQUEST_ABORTED; return result; }
        result.ok=publish(target); result.path=target; result.error=result.ok?0:ERROR_WRITE_FAULT; return result;
    }
    if (stopped) { result.error=ERROR_REQUEST_ABORTED; return result; }
    auto token=NewId(); if (token.empty()) { result.error=ERROR_NOT_ENOUGH_MEMORY; return result; }
    std::wstring temporary=folder+L"\\.deepreader-"+token+L".tmp";
    if (!CopyFileExW(source.c_str(),temporary.c_str(),CopyProgress,&stopped,nullptr,COPY_FILE_FAIL_IF_EXISTS)) {
        result.error=GetLastError(); DeleteFileW(temporary.c_str()); return result;
    }
    bool moved=false;
    for (int n=1;n<=10000 && !stopped;++n) {
        target=folder+L"\\"+stem+(n==1?L"":L" ("+std::to_wstring(n)+L")")+L".pdf";
        if (MoveFileExW(temporary.c_str(),target.c_str(),MOVEFILE_WRITE_THROUGH)) { moved=true; break; }
        result.error=GetLastError();
        if (result.error!=ERROR_ALREADY_EXISTS && result.error!=ERROR_FILE_EXISTS) break;
    }
    if (!moved) { DeleteFileW(temporary.c_str()); if (stopped) result.error=ERROR_REQUEST_ABORTED; return result; }
    if (!publish(target)) { DeleteFileW(target.c_str()); result.error=ERROR_WRITE_FAULT; return result; }
    result.ok=true; result.path=target; result.error=0; return result;
}
}
