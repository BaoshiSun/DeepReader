// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

public struct EBookMark: Codable, Equatable, Sendable {
    public let chapter: String
    public let start: Int
    public let length: Int
    public let quote: String
    public init(chapter: String, start: Int, length: Int, quote: String) {
        self.chapter = chapter; self.start = start; self.length = length; self.quote = quote
    }
    public var valid: Bool { chapter.utf8.count <= 2000 && start >= 0 && start <= 32000000 && length > 0 && length <= 2200 && quote.utf16.count == length }
}
struct EBookHighlights: Codable {
    let fingerprint: String
    var marks: [EBookMark]
}
