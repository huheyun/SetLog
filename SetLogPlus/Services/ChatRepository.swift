import FirebaseFirestore
import Foundation

enum ChatError: LocalizedError {
    case emptyMessage
    case messageTooLong

    var errorDescription: String? {
        switch self {
        case .emptyMessage:
            return "메시지를 입력해 주세요."
        case .messageTooLong:
            return "메시지는 \(ChatRepository.maxMessageLength)자까지 보낼 수 있습니다."
        }
    }
}

/// Group chat stored at `groups/{groupId}/messages`.
final class ChatRepository {
    /// Must match the limit in firestore.rules.
    nonisolated static let maxMessageLength = 1000

    private let db = Firestore.firestore()

    /// Listens to the last `limit` messages, oldest first. Callbacks arrive on the main queue.
    /// Messages written locally but not yet acknowledged are included (with an estimated `createdAt`).
    func listenMessages(
        groupID: String,
        limit: Int = 200,
        onChange: @escaping (Result<[ChatMessage], Error>) -> Void
    ) -> ListenerRegistration {
        messagesCollection(groupID: groupID)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .addSnapshotListener(includeMetadataChanges: true) { snapshot, error in
                if let error {
                    onChange(.failure(error))
                    return
                }

                let messages = (snapshot?.documents ?? [])
                    .compactMap { Self.makeMessage(from: $0) }
                    .reversed()
                onChange(.success(Array(messages)))
            }
    }

    func sendMessage(groupID: String, text: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let user = AuthService.shared.currentAppUser else {
            completion(.failure(AuthError.notLoggedIn))
            return
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion(.failure(ChatError.emptyMessage))
            return
        }
        guard trimmed.count <= Self.maxMessageLength else {
            completion(.failure(ChatError.messageTooLong))
            return
        }

        let data: [String: Any] = [
            "senderID": user.uid,
            "senderName": user.displayName,
            "text": trimmed,
            "createdAt": FieldValue.serverTimestamp()
        ]

        messagesCollection(groupID: groupID).addDocument(data: data) { error in
            completion(Result(error: error))
        }
    }

    private func messagesCollection(groupID: String) -> CollectionReference {
        db.collection("groups").document(groupID).collection("messages")
    }

    nonisolated private static func makeMessage(from document: QueryDocumentSnapshot) -> ChatMessage? {
        // `.estimate` fills a pending serverTimestamp with the local write time.
        let data = document.data(with: .estimate)

        // Skip legacy video "messages" written by an older app version (type: "video", empty text).
        if let type = data["type"] as? String, type != "text" {
            return nil
        }

        guard let senderID = data["senderID"] as? String,
              let text = data["text"] as? String,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return ChatMessage(
            id: document.documentID,
            senderID: senderID,
            senderName: data["senderName"] as? String ?? "사용자",
            text: text,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            isPending: document.metadata.hasPendingWrites
        )
    }
}
