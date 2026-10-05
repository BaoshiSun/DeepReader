// SPDX-License-Identifier: AGPL-3.0-or-later
#pragma once
#include <string>
#include <vector>
namespace deepseek {
struct Record {
    std::wstring id, time, file, title, selected, context, answer;
    std::string kind = "explain", provider, model, language = "zh";
    int page = 0;
};
std::wstring LocalStamp();
std::wstring FileName(const std::wstring& path);
bool ValidDate(const std::wstring& date);
bool PeriodRange(int scope, const std::wstring& anchor, std::wstring& first, std::wstring& last);
bool SaveRecord(const std::wstring& dir, Record& record);
bool LoadRecords(const std::wstring& dir, std::vector<Record>& records, int& unreadable);
bool DeleteRecord(const std::wstring& dir, const std::wstring& id);
std::wstring RecordText(const Record& record, bool english);
bool Matches(const Record& record, const std::wstring& query);
struct ReadingStats {
    size_t lookups=0, uniqueSelections=0, files=0, fileSummaries=0, days=0;
};
ReadingStats CountReading(const std::vector<Record>& records, const std::wstring& first=L"",
    const std::wstring& last=L"", const std::wstring& file=L"");
std::wstring StatsText(const ReadingStats& scope, size_t totalLookups, bool english);
std::wstring ReviewSource(const std::vector<Record>& records, const std::wstring& first,
    const std::wstring& last, size_t& count);
std::vector<std::wstring> Chunks(const std::wstring& text, size_t limit = 12000);
size_t SummaryRequests(size_t parts);
}
