import FirebaseAuth
import FirebaseFirestore
import Foundation

final class ReactionRepository {
    static let availableEmojis = ["😍", "😂", "👏", "🔥", "😮"]

    private let db = Firestore.firestore()

    func fetchReactions(postIDs: [String], completion: @escaping (Result<[String: [PostReaction]], Error>) -> Void) {
        let uniquePostIDs = Array(Set(postIDs))
        guard !uniquePostIDs.isEmpty else {
            completion(.success([:]))
            return
        }

        let group = DispatchGroup()
        var reactionsByPostID: [String: [PostReaction]] = [:]
        var capturedError: Error?

        uniquePostIDs.forEach { postID in
            group.enter()
            reactionCollection(postID: postID).getDocuments { snapshot, error in
                defer { group.leave() }

                if let error {
                    capturedError = error
                    return
                }

                reactionsByPostID[postID] = snapshot?.documents.compactMap {
                    Self.makeReaction(from: $0, postID: postID)
                } ?? []
            }
        }

        group.notify(queue: .main) {
            if let capturedError {
                completion(.failure(capturedError))
            } else {
                completion(.success(reactionsByPostID))
            }
        }
    }

    func setReaction(postID: String, emoji: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion(.failure(ReactionRepositoryError.notLoggedIn))
            return
        }

        let data: [String: Any] = [
            "postID": postID,
            "userID": user.uid,
            "userName": user.displayName ?? user.email ?? "사용자",
            "emoji": emoji,
            "createdAt": FieldValue.serverTimestamp()
        ]

        reactionCollection(postID: postID).document(user.uid).setData(data) { error in
            if let error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }

    func removeReaction(postID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let userID = Auth.auth().currentUser?.uid else {
            completion(.failure(ReactionRepositoryError.notLoggedIn))
            return
        }

        reactionCollection(postID: postID).document(userID).delete { error in
            if let error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }

    private func reactionCollection(postID: String) -> CollectionReference {
        db.collection("posts").document(postID).collection("reactions")
    }

    private static func makeReaction(from document: QueryDocumentSnapshot, postID: String) -> PostReaction? {
        let data = document.data()

        guard let userID = data["userID"] as? String,
              let userName = data["userName"] as? String,
              let emoji = data["emoji"] as? String else {
            return nil
        }

        return PostReaction(
            id: document.documentID,
            postID: data["postID"] as? String ?? postID,
            userID: userID,
            userName: userName,
            emoji: emoji,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue()
        )
    }
}

enum ReactionRepositoryError: LocalizedError {
    case notLoggedIn

    var errorDescription: String? {
        switch self {
        case .notLoggedIn:
            return "로그인이 필요합니다."
        }
    }
}
