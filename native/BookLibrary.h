// SPDX-License-Identifier: AGPL-3.0-or-later
#pragma once
#include <atomic>
#include <string>
#include <vector>
#include "ReadingLibrary.h"
namespace deepseek {
struct Book {
    std::wstring id, file, title, added, updated, finishedAt, archivePath;
    std::vector<std::wstring> copies;
    int rating = 0; // 0 means not rated yet; the user chooses 1–5 stars.
    bool finished = false;
};
bool SameBookPath(const std::wstring& a, const std::wstring& b);
bool BookHasPath(const Book& book, const std::wstring& file);
bool SaveBook(const std::wstring& dir, Book& book);
bool LoadBooks(const std::wstring& dir, std::vector<Book>& books, int& unreadable);
bool FindBook(const std::wstring& dir, const std::wstring& file, Book& book, bool create);
bool UpdateBook(const std::wstring& dir, Book& book, int rating, int state);
void SetBookFinished(Book& book, bool finished);
bool BookMatches(const Book& book, const std::wstring& query, int filter);
std::wstring BookOverview(const std::vector<Book>& books, bool english);
std::wstring BookText(const Book& book, const std::vector<Record>& records, bool english);
std::wstring BookListText(const std::vector<Book>& books, const std::vector<Record>& records, bool english);
std::wstring BookOpenPath(const Book& book);
struct ArchiveResult { bool ok = false; std::wstring path; unsigned long error = 0; };
// Copy saved PDF bytes, never replace another file or change the source. The caller
// checks for unsaved annotations before starting this cancellable worker operation.
ArchiveResult ArchiveBook(const std::wstring& dir, const Book& book, const std::wstring& source,
    const std::wstring& root, std::atomic<bool>& stopped);
}
