import FirebaseFirestore
import Foundation

enum CommentError: LocalizedError {
    case emptyText
    case tooLong

    var errorDescription: String? {
        switch self {
        case .emptyText:
            return "댓글 내용을 입력해주세요."
        case .tooLong:
            return "댓글은 \(PostComment.maxLength)자까지 쓸 수 있어요."
        }
    }
}

final class CommentRepository {
    private let db = Firestore.firestore()

    /// Live comments for a post, oldest first. Callbacks arrive on the main queue.
    func listenComments(
        postID: String,
        onChange: @escaping (Result<[PostComment], Error>) -> Void
    ) -> ListenerRegistration {
        commentsCollection(postID: postID)
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onChange(.failure(error))
                    return
                }

                let now = Date()
                let comments = (snapshot?.documents ?? [])
                    .compactMap { Self.makeComment(from: $0, postID: postID, now: now) }
                    // Pending writes sort to the end even though Firestore orders null timestamps first.
                    .sorted { $0.createdAt < $1.createdAt }
                onChange(.success(comments))
            }
    }

    func addComment(postID: String, text: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let user = AuthService.shared.currentAppUser else {
            completion(.failure(AuthError.notLoggedIn))
            return
        }

        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            completion(.failure(CommentError.emptyText))
            return
        }
        guard trimmedText.count <= PostComment.maxLength else {
            completion(.failure(CommentError.tooLong))
            return
        }

        let data: [String: Any] = [
            "authorID": user.uid,
            "authorName": user.displayName,
            "text": trimmedText,
            "createdAt": FieldValue.serverTimestamp()
        ]

        commentsCollection(postID: postID).addDocument(data: data) { error in
            completion(Result(error: error))
        }
    }

    func deleteComment(postID: String, commentID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        commentsCollection(postID: postID).document(commentID).delete { error in
            completion(Result(error: error))
        }
    }

    private func commentsCollection(postID: String) -> CollectionReference {
        db.collection("posts").document(postID).collection("comments")
    }

    nonisolated private static func makeComment(from document: QueryDocumentSnapshot, postID: String, now: Date) -> PostComment? {
        let data = document.data(with: .estimate)

        guard let authorID = data["authorID"] as? String,
              let text = data["text"] as? String else {
            return nil
        }

        return PostComment(
            id: document.documentID,
            postID: postID,
            authorID: authorID,
            authorName: data["authorName"] as? String ?? "사용자",
            text: text,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? now
        )
    }
}
