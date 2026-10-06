// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import CryptoKit

public struct Loaded<T> {
    public var items: [T]
    public var unreadable: Int
}

public final class LibraryStore: @unchecked Sendable {
    public let root: URL
    private let lock = NSRecursiveLock()
    private let fm = FileManager.default
    public init(root: URL? = nil) throws {
        self.root = try root ?? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true).appendingPathComponent("DeepReader", isDirectory: true)
        try fm.createDirectory(at: self.root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    }
    private func locked<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock(); defer { lock.unlock() }; return try body()
    }
    private func folder(_ name: String) -> URL { root.appendingPathComponent(name, isDirectory: true) }
    private func encode<T: Encodable>(_ item: T, at url: URL) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(item)
        guard data.count <= 1024 * 1024 else { throw ReaderError("记录过大，未保存。", "Record is too large to save.") }
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try data.write(to: url, options: .atomic)
        try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
    private func idURL(_ id: String, directory: String) throws -> URL {
        guard UUID(uuidString: id) != nil else { throw ReaderError("记录编号无效。", "Invalid record ID.") }
        return folder(directory).appendingPathComponent(id.lowercased() + ".json")
    }
    private func read<T: Decodable>(_ type: T.Type, url: URL) throws -> T {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isSymbolicLinkKey])
        guard values.isSymbolicLink != true, (values.fileSize ?? Int.max) <= 1024 * 1024 else {
            throw ReaderError("记录文件无效。", "Invalid record file.")
        }
        return try JSONDecoder().decode(type, from: Data(contentsOf: url))
    }
    public func settings() throws -> Settings {
        try locked {
            let url = root.appendingPathComponent("settings.json")
            guard fm.fileExists(atPath: url.path) else { return Settings() }
            return try read(Settings.self, url: url).validated()
        }
    }
    public func saveSettings(_ settings: Settings) throws {
        try locked { try encode(settings.validated(), at: root.appendingPathComponent("settings.json")) }
    }
    private func load<T: Decodable & Identifiable>(_ type: T.Type, directory: String, valid: (T) -> Bool) throws -> Loaded<T> where T.ID == String {
        guard fm.fileExists(atPath: folder(directory).path) else { return Loaded(items: [], unreadable: 0) }
        let urls = try fm.contentsOfDirectory(at: folder(directory), includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
        var items: [T] = [], bad = 0
        for url in urls where url.pathExtension == "json" {
            do {
                let item = try read(type, url: url)
                guard valid(item), item.id.lowercased() == url.deletingPathExtension().lastPathComponent else { bad += 1; continue }
                items.append(item)
            } catch { bad += 1 }
        }
        return Loaded(items: items, unreadable: bad)
    }
    public func records() throws -> Loaded<ReadingRecord> {
        try locked {
            var values = try load(ReadingRecord.self, directory: "AIHistory", valid: { $0.valid })
            values.items.sort { $0.time == $1.time ? $0.id > $1.id : $0.time > $1.time }; return values
        }
    }
    public func saveRecord(_ record: ReadingRecord) throws {
        try locked {
            guard record.valid else { throw ReaderError("阅读记录无效，未保存。", "Invalid reading record; not saved.") }
            try encode(record, at: idURL(record.id, directory: "AIHistory"))
        }
    }
    public func deleteRecord(_ id: String) throws { try locked { try fm.removeItem(at: idURL(id, directory: "AIHistory")) } }
    public func books() throws -> Loaded<Book> {
        try locked {
            var values = try load(Book.self, directory: "BookLibrary", valid: { $0.valid })
            values.items.sort { $0.updated == $1.updated ? $0.title < $1.title : $0.updated > $1.updated }; return values
        }
    }
    private func saveBook(_ book: Book) throws {
        guard book.valid else { throw ReaderError("书单记录无效。", "Invalid book record.") }
        try encode(book, at: idURL(book.id, directory: "BookLibrary"))
    }
    public func ensureBook(_ url: URL) throws -> Book {
        try locked {
            guard BookFormat.supports(url) else { throw ReaderError("请打开支持的文档或电子书。", "Open a supported document or ebook.") }
            if let book = try books().items.first(where: { $0.hasPath(url.path) }) { return book }
            let book = Book(file: url); try saveBook(book); return book
        }
    }
    public func updateBook(id: String, rating: Int? = nil, finished: Bool? = nil) throws -> Book {
        try locked {
            var book = try read(Book.self, url: idURL(id, directory: "BookLibrary"))
            if let rating = rating { guard (1...5).contains(rating) else { throw ReaderError("请选择 1–5 星。", "Choose 1–5 stars.") }; book.rating = rating }
            if let finished = finished { book.setFinished(finished) }
            book.updated = Dates.stamp(); try saveBook(book); return book
        }
    }
    public func importHistoryBooks() throws {
        try locked {
            let records = try records().items
            for record in records where ["explain", "file"].contains(record.kind) && record.file.hasPrefix("/") && BookFormat.supports(URL(fileURLWithPath: record.file)) {
                _ = try ensureBook(URL(fileURLWithPath: record.file))
            }
        }
    }
    public func openPath(_ book: Book) -> URL? {
        for path in [book.file, book.archivePath] + Array(book.copies.reversed()) where !path.isEmpty {
            var directory: ObjCBool = false
            if fm.fileExists(atPath: path, isDirectory: &directory), !directory.boolValue { return URL(fileURLWithPath: path) }
        }
        return nil
    }
    private func digest(_ url: URL) throws -> Data {
        let input = try FileHandle(forReadingFrom: url); defer { try? input.close() }
        var hash = SHA256()
        while true {
            try Task.checkCancellation()
            guard let data = try input.read(upToCount: 1024 * 1024), !data.isEmpty else { break }
            hash.update(data: data)
        }
        return Data(hash.finalize())
    }
    public func archive(book: Book, source: URL, root destination: URL) throws -> URL {
        try Task.checkCancellation()
        guard book.valid, book.rating > 0, book.hasPath(source.path), BookFormat.supports(source), destination.isFileURL,
              fm.fileExists(atPath: source.path) else { throw ReaderError("请先评分，并检查原文件。", "Rate the book and check the original file first.") }
        let directory = destination.appendingPathComponent("\(book.rating)星", isDirectory: true)
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let originalName = URL(fileURLWithPath: book.file).lastPathComponent
        let sourceHash = try digest(source)
        let prior = book.archivePath.isEmpty ? nil : URL(fileURLWithPath: book.archivePath)
        var candidates = [directory.appendingPathComponent(originalName)]
        if let prior = prior, prior.deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL { candidates.insert(prior, at: 0) }
        for candidate in candidates where fm.fileExists(atPath: candidate.path) {
            if try digest(candidate) == sourceHash { try rememberArchive(id: book.id, url: candidate); return candidate }
        }
        let temporary = directory.appendingPathComponent(".deepreader-\(UUID().uuidString).tmp")
        guard fm.createFile(atPath: temporary.path, contents: nil) else { throw ReaderError("归档目录不可写。", "Archive folder is not writable.") }
        defer { try? fm.removeItem(at: temporary) }
        let input = try FileHandle(forReadingFrom: source), output = try FileHandle(forWritingTo: temporary)
        do {
            defer { try? input.close(); try? output.close() }
            var hash = SHA256()
            while true {
                try Task.checkCancellation()
                guard let data = try input.read(upToCount: 1024 * 1024), !data.isEmpty else { break }
                hash.update(data: data); try output.write(contentsOf: data)
            }
            try output.synchronize()
            guard Data(hash.finalize()) == sourceHash else { throw ReaderError("复制期间原文件发生变化，请重新归档。", "The source changed during copying. Please archive again.") }
        }
        let stem = URL(fileURLWithPath: originalName).deletingPathExtension().lastPathComponent
        for number in 1...10000 {
            try Task.checkCancellation()
            let name = number == 1 ? originalName : "\(stem) (\(number)).\(source.pathExtension)"
            let target = directory.appendingPathComponent(name)
            do { try fm.moveItem(at: temporary, to: target) }
            catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileWriteFileExistsError { continue }
            do { try rememberArchive(id: book.id, url: target) }
            catch { try? fm.removeItem(at: target); throw error }
            return target
        }
        throw ReaderError("同名归档过多，请更换目录。", "Too many files with this name; choose another folder.")
    }
    private func rememberArchive(id: String, url: URL) throws {
        try locked {
            try Task.checkCancellation()
            var book = try read(Book.self, url: idURL(id, directory: "BookLibrary"))
            book.archivePath = url.path
            if !book.copies.contains(url.path) { book.copies.append(url.path) }
            book.updated = Dates.stamp(); try saveBook(book)
        }
    }
    public func highlights(bookID: String, fingerprint: String) throws -> [EBookMark] {
        try locked {
            let url = try idURL(bookID, directory: "BookHighlights")
            guard fm.fileExists(atPath: url.path) else { return [] }
            let saved = try read(EBookHighlights.self, url: url)
            guard saved.marks.count <= 10000, saved.marks.allSatisfy({ $0.valid }) else { throw EBookError.invalid }
            return saved.fingerprint == fingerprint ? saved.marks : []
        }
    }
    public func saveHighlights(_ marks: [EBookMark], bookID: String, fingerprint: String) throws {
        try locked {
            guard fingerprint.count == 64, marks.count <= 10000, marks.allSatisfy({ $0.valid }) else { throw EBookError.invalid }
            try encode(EBookHighlights(fingerprint: fingerprint, marks: marks), at: idURL(bookID, directory: "BookHighlights"))
        }
    }
}
