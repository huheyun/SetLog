import Foundation
import UserNotifications

/// Local, server-free hourly reminders ("매시간 촬영 알림").
/// Schedules one repeating calendar notification per hour in `[startHour, endHour]` at minute 0.
enum ReminderService {
    enum EnableResult {
        case enabled
        case denied
        case failed(Error)
    }

    static let defaultStartHour = 9
    static let defaultEndHour = 22

    nonisolated private static let identifierPrefix = "setlogplus.hourly-reminder."

    private enum Keys {
        static let isEnabled = "reminder.isEnabled"
        static let startHour = "reminder.startHour"
        static let endHour = "reminder.endHour"
    }

    private static let title = "지금 3초 남기기"
    private static let bodies = [
        "이번 시간의 순간을 그룹에 공유해보세요",
        "지금 이 순간, 3초면 충분해요",
        "친구들이 기다리고 있어요. 지금 한 컷!",
        "오늘의 한 시간을 3초로 기록해볼까요?"
    ]

    private static var defaults: UserDefaults { .standard }

    // MARK: - Settings

    static var isEnabled: Bool {
        defaults.bool(forKey: Keys.isEnabled)
    }

    static var startHour: Int {
        defaults.object(forKey: Keys.startHour) as? Int ?? defaultStartHour
    }

    static var endHour: Int {
        defaults.object(forKey: Keys.endHour) as? Int ?? defaultEndHour
    }

    /// e.g. "9시 ~ 22시 매 정각"
    static var rangeDescription: String {
        "\(startHour)시 ~ \(endHour)시 매 정각"
    }

    /// Updates the hour range. Returns `false` (and changes nothing) unless `0 <= start < end <= 23`.
    @discardableResult
    static func setHourRange(start: Int, end: Int) -> Bool {
        guard (0...23).contains(start), (0...23).contains(end), start < end else { return false }
        defaults.set(start, forKey: Keys.startHour)
        defaults.set(end, forKey: Keys.endHour)
        reschedule()
        return true
    }

    nonisolated static func isReminderIdentifier(_ identifier: String) -> Bool {
        identifier.hasPrefix(identifierPrefix)
    }

    // MARK: - Enable / Disable

    /// Requests notification permission if needed, then enables and schedules the reminders.
    /// `completion` is called on the main actor.
    static func requestAuthorizationAndEnable(completion: @escaping (EnableResult) -> Void) {
        Task {
            let center = UNUserNotificationCenter.current()
            let status = await center.notificationSettings().authorizationStatus

            switch status {
            case .denied:
                completion(.denied)
                return
            case .notDetermined:
                do {
                    let granted = try await center.requestAuthorization(options: [.alert, .sound])
                    guard granted else {
                        completion(.denied)
                        return
                    }
                } catch {
                    completion(.failed(error))
                    return
                }
            default:
                break
            }

            defaults.set(true, forKey: Keys.isEnabled)
            reschedule()
            completion(.enabled)
        }
    }

    static func disable() {
        defaults.set(false, forKey: Keys.isEnabled)
        removePendingReminders()
    }

    /// Removes this app's reminder requests and, if enabled, schedules them again from the current settings.
    static func reschedule() {
        removePendingReminders()
        guard isEnabled else { return }

        let center = UNUserNotificationCenter.current()
        let start = startHour
        let end = endHour
        guard start < end else { return }

        for hour in start...end {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = bodies[hour % bodies.count]
            content.sound = .default

            var components = DateComponents()
            components.hour = hour
            components.minute = 0

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: identifier(for: hour), content: content, trigger: trigger)
            center.add(request)
        }
    }

    // MARK: - Private

    private static func identifier(for hour: Int) -> String {
        "\(identifierPrefix)\(hour)"
    }

    private static func removePendingReminders() {
        // Identifiers are stable per hour, so removing all 24 covers any previous range.
        let identifiers = (0...23).map { identifier(for: $0) }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }
}
