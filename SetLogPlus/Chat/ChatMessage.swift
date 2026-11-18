import Foundation

/// A message in `groups/{groupId}/messages/{messageId}`.
struct ChatMessage: Equatable {
    let id: String
    let senderID: String
    let senderName: String
    let text: String
    /// Server time, or the local estimate while the write is still pending.
    let createdAt: Date
    /// `true` until the server has acknowledged the write.
    let isPending: Bool
}
