import Foundation

struct PostComment {
    static let maxLength = 300

    let id: String
    let postID: String
    let authorID: String
    let authorName: String
    let text: String
    /// Pending server timestamps are reported as the local time of the snapshot.
    let createdAt: Date
}
