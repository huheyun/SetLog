import Foundation

/// Hour-bucket helpers. Keys look like `yyyyMMddHH` and sort chronologically as strings.
enum HourSlot {
    private static let keyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMddHH"
        return formatter
    }()

    private static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "HH:00"
        return formatter
    }()

    static func currentKey(date: Date = Date()) -> String {
        keyFormatter.string(from: date)
    }

    static func displayText(date: Date = Date()) -> String {
        displayFormatter.string(from: date)
    }

    static func displayText(hourKey: String) -> String {
        guard let date = date(fromKey: hourKey) else {
            return "시간 없음"
        }

        return displayText(date: date)
    }

    static func date(fromKey hourKey: String) -> Date? {
        keyFormatter.date(from: hourKey)
    }

    static func isTodayKey(_ hourKey: String) -> Bool {
        hourKey.hasPrefix(String(currentKey().prefix(8)))
    }
}
