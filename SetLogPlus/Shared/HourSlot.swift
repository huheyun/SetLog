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
        hourKey.hasPrefix(dayKey(for: Date()))
    }

    // MARK: - Day helpers

    /// Calendar matching the key formatter (gregorian, current time zone).
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        calendar.locale = Locale(identifier: "ko_KR")
        return calendar
    }()

    private static let dayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()

    private static let dayDisplayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 (E)"
        return formatter
    }()

    private static let shortDayDisplayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일"
        return formatter
    }()

    /// `yyyyMMdd` key for the day containing `date`; the prefix of every hour key that day.
    static func dayKey(for date: Date) -> String {
        dayKeyFormatter.string(from: date)
    }

    /// `yyyyMMdd` prefix of an hour key.
    static func dayKey(fromHourKey hourKey: String) -> String {
        String(hourKey.prefix(8))
    }

    /// Start of the day described by a `yyyyMMdd` key.
    static func date(fromDayKey dayKey: String) -> Date? {
        dayKeyFormatter.date(from: dayKey).map { calendar.startOfDay(for: $0) }
    }

    static func startOfDay(_ date: Date = Date()) -> Date {
        calendar.startOfDay(for: date)
    }

    static func isToday(_ date: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: Date())
    }

    /// "11월 18일 (화)"
    static func displayDayText(date: Date) -> String {
        dayDisplayFormatter.string(from: date)
    }

    /// "11월 18일"
    static func shortDisplayDayText(date: Date) -> String {
        shortDayDisplayFormatter.string(from: date)
    }
}
