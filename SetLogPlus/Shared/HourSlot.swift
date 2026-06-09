import Foundation

enum HourSlot {
    static func currentKey(date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMddHH"
        return formatter.string(from: date)
    }

    static func displayText(date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "HH:00"
        return formatter.string(from: date)
    }

    static func displayText(hourKey: String) -> String {
        guard let date = date(fromKey: hourKey) else {
            return "시간 없음"
        }

        return displayText(date: date)
    }

    static func hourDate(offsetFromNow offset: Int) -> Date {
        Calendar.current.date(byAdding: .hour, value: offset, to: Date()) ?? Date()
    }

    static func startOfCurrentHour() -> Date {
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour], from: Date())
        return Calendar.current.date(from: components) ?? Date()
    }

    static func date(fromKey hourKey: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMddHH"
        return formatter.date(from: hourKey)
    }

    static func isTodayKey(_ hourKey: String) -> Bool {
        guard let date = date(fromKey: hourKey) else {
            return false
        }

        return Calendar.current.isDateInToday(date)
    }
}
