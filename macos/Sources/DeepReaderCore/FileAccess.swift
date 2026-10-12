// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import CryptoKit

/// Keep this object alive for the entire read/write operation, including detached workers.
public final class FileAccess: @unchecked Sendable {
    public let url: URL
    private let active: Bool
    public init(_ url: URL) {
        self.url = url
        active = url.startAccessingSecurityScopedResource()
    }
    deinit { if active { url.stopAccessingSecurityScopedResource() } }
}

public final class FileAccessStore: @unchecked Sendable {
    private let root: URL
    private let lock = NSLock()
    public init(root: URL) { self.root = root.appendingPathComponent("FileAccess", isDirectory: true) }
    private func location(_ url: URL) -> URL {
        let hash = SHA256.hash(data: Data(url.standardizedFileURL.path.utf8)).map { String(format: "%02x", $0) }.joined()
        return root.appendingPathComponent(hash + ".bookmark")
    }
    /// User-selected URLs are already authorized by the open panel. Restore saved grants only for library paths.
    public func acquire(_ original: URL, restoring: Bool = false) throws -> FileAccess {
        lock.lock(); defer { lock.unlock() }
        var url = original
        let file = location(original), fm = FileManager.default
        if restoring, fm.fileExists(atPath: file.path) {
            let values = try file.resourceValues(forKeys: [.fileSizeKey, .isSymbolicLinkKey])
            guard values.isSymbolicLink != true, (values.fileSize ?? Int.max) < 1024 * 1024 else {
                throw ReaderError("文件授权已失效，请重新选择文件。", "File access has expired. Select the file again.")
            }
            var stale = false
            url = try URL(resolvingBookmarkData: Data(contentsOf: file), options: [.withSecurityScope, .withoutUI],
                          relativeTo: nil, bookmarkDataIsStale: &stale)
        }
        let access = FileAccess(url)
        guard fm.isReadableFile(atPath: url.path) else {
            throw ReaderError("无法访问文件，请重新选择以授权。", "Cannot access the file. Select it again to grant access.")
        }
        // Recreate even stale bookmarks while the grant is active; retain the old-path alias after a move.
        let data = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        try fm.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try data.write(to: file, options: .atomic)
        try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        if url.standardizedFileURL.path != original.standardizedFileURL.path {
            let moved = location(url)
            try data.write(to: moved, options: .atomic)
            try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: moved.path)
        }
        return access
    }
}
