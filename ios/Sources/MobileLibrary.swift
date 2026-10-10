// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

struct MobileBook: Codable, Identifiable, Equatable {
    var id: UUID
    var filename: String
    var title: String
    var added: Date
    var rating = 0
    var finished = false
    var position = 0
    var highlights: [String] = []
}
struct MobileState: Codable {
    var books: [MobileBook] = []
    var records: [ReadingRecord] = []
    var settings = Settings()
    // Optional so libraries created before remembered consent still decode safely.
    var aiConsentVersion: Int?
}
final class MobileLibrary: @unchecked Sendable {
    private let lock = NSRecursiveLock()
    let root: URL
    private var storedState: MobileState
    var state: MobileState { lock.lock(); defer { lock.unlock() }; return storedState }
    init(root: URL? = nil) throws {
        self.root = try root ?? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("DeepReaderMobile")
        try FileManager.default.createDirectory(at: self.root.appendingPathComponent("Documents"), withIntermediateDirectories: true)
        let file = self.root.appendingPathComponent("library.json")
        if FileManager.default.fileExists(atPath: file.path) {
            guard (try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max) <= 32 * 1024 * 1024 else { throw MobileDocument.invalid }
            storedState = try JSONDecoder().decode(MobileState.self, from: Data(contentsOf: file))
            guard state.books.allSatisfy({ Self.validFilename($0.filename) && (0...5).contains($0.rating) && $0.position >= 0 }),
                  state.records.allSatisfy(\.valid) else { throw MobileDocument.invalid }
            storedState.settings = try storedState.settings.validated()
        } else { storedState = MobileState() }
        storedState.settings.provider = .deepSeek
    }
    static func validFilename(_ name: String) -> Bool {
        !name.isEmpty && name == (name as NSString).lastPathComponent && !name.contains("\\") && !name.contains(":") && !name.hasPrefix(".")
    }
    func url(_ book: MobileBook) -> URL { root.appendingPathComponent("Documents").appendingPathComponent(book.filename) }
    func update(_ mutate: (inout MobileState) -> Void) throws {
        lock.lock(); defer { lock.unlock() }
        var next = state; mutate(&next)
        next.settings = try next.settings.validated()
        let data = try JSONEncoder().encode(next)
        guard data.count <= 32 * 1024 * 1024 else { throw MobileDocument.oversized }
        try data.write(to: root.appendingPathComponent("library.json"), options: [.atomic, .completeFileProtectionUnlessOpen])
        storedState = next
    }
    func importFile(_ source: URL) throws -> MobileBook {
        lock.lock(); defer { lock.unlock() }
        guard MobileDocument.extensions.contains(source.pathExtension.lowercased()) else { throw MobileDocument.invalid }
        let granted = source.startAccessingSecurityScopedResource()
        defer { if granted { source.stopAccessingSecurityScopedResource() } }
        let id = UUID(), filename = id.uuidString + "." + source.pathExtension.lowercased()
        let book = MobileBook(id: id, filename: filename, title: source.deletingPathExtension().lastPathComponent, added: Date())
        let destination = url(book)
        var coordinationError: NSError?, copyError: Error?
        NSFileCoordinator().coordinate(readingItemAt: source, options: [], error: &coordinationError) { readable in
            do {
                let values = try readable.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
                guard values.isRegularFile == true, (values.fileSize ?? Int.max) <= 128 * 1024 * 1024 else { throw MobileDocument.oversized }
                try FileManager.default.copyItem(at: readable, to: destination)
            } catch { copyError = error }
        }
        if let error = coordinationError ?? (copyError as NSError?) { throw error }
        do {
            _ = try MobileDocument.load(destination)
            try update { $0.books.insert(book, at: 0) }
        } catch { try? FileManager.default.removeItem(at: destination); throw error }
        return book
    }
    func remove(_ book: MobileBook) throws {
        lock.lock(); defer { lock.unlock() }
        // Remove the app's imported copy only. The user-selected original is never modified.
        try update { $0.books.removeAll { $0.id == book.id } }
        if FileManager.default.fileExists(atPath: url(book).path) { try FileManager.default.removeItem(at: url(book)) }
    }
}
