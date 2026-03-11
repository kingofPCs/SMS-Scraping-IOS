import Foundation
import SQLite3

struct ParsedMessage: Identifiable {
    let id: Int
    let text: String
    let date: Date
    let isFromMe: Bool
    let handle: String
    let chatIdentifier: String
}

struct ConversationSummary: Identifiable {
    let id: String // chat identifier
    let handle: String
    let messageCount: Int
}

final class ChatDBParser {

    private var db: OpaquePointer?

    deinit {
        if let db = db {
            sqlite3_close(db)
        }
    }

    /// Parse a chat.db file and return all messages
    func parse(fileURL: URL) throws -> [ParsedMessage] {
        let accessing = fileURL.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        // Copy to a temp location so SQLite can read it without sandbox issues
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("db")
        try FileManager.default.copyItem(at: fileURL, to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        guard sqlite3_open_v2(tempURL.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            let error = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "Unknown error"
            throw ParserError.cannotOpenDatabase(error)
        }

        return try queryMessages()
    }

    private func queryMessages() throws -> [ParsedMessage] {
        let query = """
            SELECT
                m.ROWID,
                COALESCE(m.text, '') as text,
                m.date,
                m.is_from_me,
                COALESCE(h.id, 'Unknown') as handle,
                COALESCE(c.chat_identifier, 'Unknown') as chat_identifier
            FROM message m
            LEFT JOIN handle h ON m.handle_id = h.ROWID
            LEFT JOIN chat_message_join cmj ON m.ROWID = cmj.message_id
            LEFT JOIN chat c ON cmj.chat_id = c.ROWID
            ORDER BY m.date ASC
            """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            let error = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "Unknown error"
            throw ParserError.queryFailed(error)
        }
        defer { sqlite3_finalize(statement) }

        // Apple reference date: 2001-01-01 00:00:00 UTC
        let appleReferenceDate = Date(timeIntervalSinceReferenceDate: 0)

        var messages: [ParsedMessage] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            let rowID = Int(sqlite3_column_int64(statement, 0))
            let text = String(cString: sqlite3_column_text(statement, 1))
            let rawDate = sqlite3_column_int64(statement, 2)
            let isFromMe = sqlite3_column_int(statement, 3) == 1
            let handle = String(cString: sqlite3_column_text(statement, 4))
            let chatID = String(cString: sqlite3_column_text(statement, 5))

            // chat.db dates: nanoseconds since 2001-01-01 on iOS 11+,
            // seconds since 2001-01-01 on older versions
            let seconds: TimeInterval
            if rawDate > 1_000_000_000_000 {
                // Nanosecond format
                seconds = Double(rawDate) / 1_000_000_000.0
            } else {
                // Second format
                seconds = Double(rawDate)
            }
            let date = appleReferenceDate.addingTimeInterval(seconds)

            // Skip messages with no text content
            guard !text.isEmpty else { continue }

            messages.append(ParsedMessage(
                id: rowID,
                text: text,
                date: date,
                isFromMe: isFromMe,
                handle: handle,
                chatIdentifier: chatID
            ))
        }

        return messages
    }

    enum ParserError: LocalizedError {
        case cannotOpenDatabase(String)
        case queryFailed(String)

        var errorDescription: String? {
            switch self {
            case .cannotOpenDatabase(let msg):
                return "Cannot open database: \(msg)"
            case .queryFailed(let msg):
                return "Query failed: \(msg)"
            }
        }
    }
}
