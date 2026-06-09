import Foundation

struct LogNotification {
    let authorName: String
    let groupName: String
    let hourKey: String

    var message: String {
        "\(authorName)님이 \(groupName)에 \(HourSlot.displayText(hourKey: hourKey)) 로그를 올렸어요"
    }
}
