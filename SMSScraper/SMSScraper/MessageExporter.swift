import Foundation

final class MessageExporter {

    private static let dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return fmt
    }()

    /// Export messages to a plain text file, grouped by conversation
    static func exportToTextFile(messages: [ParsedMessage]) throws -> URL {
        let grouped = Dictionary(grouping: messages) { $0.chatIdentifier }
        let sortedKeys = grouped.keys.sorted()

        var output = "SMS/iMessage Export\n"
        output += "Generated: \(dateFormatter.string(from: Date()))\n"
        output += "Total Messages: \(messages.count)\n"
        output += "Total Conversations: \(sortedKeys.count)\n"
        output += String(repeating: "=", count: 60) + "\n\n"

        for key in sortedKeys {
            guard let convoMessages = grouped[key] else { continue }
            let handle = convoMessages.first(where: { !$0.isFromMe })?.handle ?? key

            output += "Conversation: \(handle)\n"
            output += String(repeating: "-", count: 40) + "\n"

            for msg in convoMessages {
                let sender = msg.isFromMe ? "Me" : msg.handle
                let timestamp = dateFormatter.string(from: msg.date)
                output += "[\(timestamp)] \(sender): \(msg.text)\n"
            }
            output += "\n"
        }

        let fileName = "messages_export_\(Int(Date().timeIntervalSince1970)).txt"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try output.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    /// Export as CSV format
    static func exportToCSV(messages: [ParsedMessage]) throws -> URL {
        var output = "timestamp,sender,handle,conversation,message\n"

        for msg in messages {
            let timestamp = dateFormatter.string(from: msg.date)
            let sender = msg.isFromMe ? "Me" : msg.handle
            let escaped = msg.text
                .replacingOccurrences(of: "\"", with: "\"\"")
            output += "\"\(timestamp)\",\"\(sender)\",\"\(msg.handle)\",\"\(msg.chatIdentifier)\",\"\(escaped)\"\n"
        }

        let fileName = "messages_export_\(Int(Date().timeIntervalSince1970)).csv"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try output.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
}
