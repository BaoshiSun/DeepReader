// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import CArchive

enum BookArchive {
    static let maxFile = 128 * 1024 * 1024
    static let maxEntry = 32 * 1024 * 1024
    static let maxTotal = 256 * 1024 * 1024
    static func read(_ data: Data) throws -> [String: Data] {
        guard data.count <= maxFile, let archive = archive_read_new() else { throw EBookError.tooLarge }
        defer { archive_read_free(archive) }
        archive_read_support_format_zip(archive)
        return try data.withUnsafeBytes { buffer in
            guard archive_read_open_memory(archive, buffer.baseAddress, buffer.count) == ARCHIVE_OK else { throw EBookError.invalid }
            var files: [String: Data] = [:], total = 0, count = 0
            var entry: OpaquePointer?
            var block = [UInt8](repeating: 0, count: 64 * 1024)
            while true {
                try Task.checkCancellation()
                let result = archive_read_next_header(archive, &entry)
                if result == ARCHIVE_EOF { break }
                guard result == ARCHIVE_OK, let entry = entry, let name = archive_entry_pathname_utf8(entry) else { throw EBookError.invalid }
                count += 1
                guard count <= 10000, archive_entry_is_encrypted(entry) == 0 else { throw EBookError.invalid }
                let raw = String(cString: name)
                let path = try BookPath.entry(raw)
                let type = archive_entry_filetype(entry)
                if type == 0o040000 { continue }
                guard type == 0o100000, archive_entry_symlink(entry) == nil, archive_entry_hardlink(entry) == nil,
                      files[path] == nil, archive_entry_size(entry) <= maxEntry else { throw EBookError.invalid }
                var bytes = Data()
                while true {
                    let size = archive_read_data(archive, &block, block.count)
                    guard size >= 0 else { throw EBookError.invalid }
                    if size == 0 { break }
                    total += size
                    guard bytes.count + size <= maxEntry, total <= maxTotal else { throw EBookError.tooLarge }
                    bytes.append(contentsOf: block.prefix(size))
                }
                files[path] = bytes
            }
            return files
        }
    }
}

public enum BookPath {
    static func entry(_ value: String) throws -> String {
        guard !value.isEmpty, !value.hasPrefix("/"), !value.contains("\\"), !value.contains(":"), !value.contains("\0"),
              !value.split(separator: "/").contains("..") else { throw EBookError.invalid }
        return value.split(separator: "/").filter { $0 != "." }.joined(separator: "/")
    }
    public static func resolve(_ href: String, relativeTo file: String) throws -> String {
        guard let decoded = href.components(separatedBy: "#")[0].removingPercentEncoding,
              !decoded.hasPrefix("/"), !decoded.contains(":"), !decoded.contains("\\"), !decoded.contains("\0") else { throw EBookError.invalid }
        if decoded.isEmpty { return file }
        var parts = Array(file.split(separator: "/").dropLast()).map(String.init)
        for part in decoded.split(separator: "/") {
            if part == "." { continue }
            if part == ".." { guard !parts.isEmpty else { throw EBookError.invalid }; parts.removeLast() }
            else { parts.append(String(part)) }
        }
        guard !parts.isEmpty else { throw EBookError.invalid }
        return parts.joined(separator: "/")
    }
}
