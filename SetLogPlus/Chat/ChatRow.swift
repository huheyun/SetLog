import Foundation

/// One row in the chat list: a date separator or a message with its grouping flags.
enum ChatRow: Equatable {
    case date(Date)
    case message(ChatMessageRow)

    /// Stable identifier for the diffable data source.
    var id: String {
        switch self {
        case .date(let date):
            return "date-\(ChatFormatters.dayKey.string(from: date))"
        case .message(let row):
            return "message-\(row.message.id)"
        }
    }
}

struct ChatMessageRow: Equatable {
    let message: ChatMessage
    let isMine: Bool
    /// First message of a consecutive run by the same sender (extra top spacing; sender name + avatar for others).
    let isRunStart: Bool
    /// Last message of its minute within the run (time label is shown only there).
    let showsTime: Bool
}

enum ChatRowBuilder {
    /// Messages farther apart than this start a new run even when the sender is the same.
    private static let runBreakInterval: TimeInterval = 5 * 60

    static func rows(for messages: [ChatMessage], currentUserID: String?) -> [ChatRow] {
        let calendar = Calendar.current
        var rows: [ChatRow] = []
        rows.reserveCapacity(messages.count + 4)

        for (index, message) in messages.enumerated() {
            let previous = index > 0 ? messages[index - 1] : nil
            let next = index + 1 < messages.count ? messages[index + 1] : nil

            let startsNewDay = previous.map { !calendar.isDate($0.createdAt, inSameDayAs: message.createdAt) } ?? true
            if startsNewDay {
                rows.append(.date(message.createdAt))
            }

            let isRunStart = startsNewDay
                || previous?.senderID != message.senderID
                || message.createdAt.timeIntervalSince(previous?.createdAt ?? message.createdAt) > runBreakInterval

            let showsTime: Bool
            if let next {
                showsTime = next.senderID != message.senderID
                    || !calendar.isDate(next.createdAt, equalTo: message.createdAt, toGranularity: .minute)
            } else {
                showsTime = true
            }

            rows.append(.message(ChatMessageRow(
                message: message,
                isMine: message.senderID == currentUserID,
                isRunStart: isRunStart,
                showsTime: showsTime
            )))
        }

        return rows
    }
}

enum ChatFormatters {
    private static let koreanLocale = Locale(identifier: "ko_KR")

    /// "11월 18일 화요일"
    static let day: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = koreanLocale
        formatter.dateFormat = "M월 d일 EEEE"
        return formatter
    }()

    /// "2025년 11월 18일 화요일" (used for dates outside the current year)
    static let dayWithYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = koreanLocale
        formatter.dateFormat = "yyyy년 M월 d일 EEEE"
        return formatter
    }()

    /// "오후 3:42"
    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = koreanLocale
        formatter.dateFormat = "a h:mm"
        return formatter
    }()

    static let dayKey: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func dayTitle(for date: Date) -> String {
        if Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year) {
            return day.string(from: date)
        }
        return dayWithYear.string(from: date)
    }
}
