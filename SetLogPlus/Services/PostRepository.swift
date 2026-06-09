import FirebaseFirestore
import Foundation

final class PostRepository {
    private let db = Firestore.firestore()

    func createPost(_ post: Post, completion: @escaping (Result<Void, Error>) -> Void) {
        let data: [String: Any] = [
            "id": post.id,
            "groupID": post.groupID,
            "authorID": post.authorID,
            "authorName": post.authorName,
            "caption": post.caption,
            "videoURL": post.videoURL,
            "storagePath": post.storagePath,
            "durationSeconds": post.durationSeconds,
            "hourKey": post.hourKey,
            "includesAudio": post.includesAudio,
            "createdAt": FieldValue.serverTimestamp()
        ]

        db.collection("posts").document(post.id).setData(data) { error in
            if let error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }

    func fetchPosts(groupID: String, completion: @escaping (Result<[Post], Error>) -> Void) {
        db.collection("posts")
            .whereField("groupID", isEqualTo: groupID)
            .getDocuments { snapshot, error in
                if let error {
                    completion(.failure(error))
                    return
                }

                let posts = snapshot?.documents.compactMap { document -> Post? in
                    Self.makePost(from: document)
                } ?? []

                completion(.success(posts))
            }
    }

    func fetchPosts(groupID: String, hourKey: String, completion: @escaping (Result<[Post], Error>) -> Void) {
        db.collection("posts")
            .whereField("groupID", isEqualTo: groupID)
            .getDocuments { snapshot, error in
                if let error {
                    completion(.failure(error))
                    return
                }

                let posts = snapshot?.documents.compactMap { document -> Post? in
                    Self.makePost(from: document)
                }.filter { $0.hourKey == hourKey } ?? []

                completion(.success(posts))
            }
    }

    func fetchPost(groupID: String, authorID: String, hourKey: String, completion: @escaping (Result<Post?, Error>) -> Void) {
        db.collection("posts")
            .whereField("groupID", isEqualTo: groupID)
            .getDocuments { snapshot, error in
                if let error {
                    completion(.failure(error))
                    return
                }

                let post = snapshot?.documents
                    .compactMap { Self.makePost(from: $0) }
                    .first { $0.authorID == authorID && $0.hourKey == hourKey }
                completion(.success(post))
            }
    }

    private static func makePost(from document: QueryDocumentSnapshot) -> Post? {
        let data = document.data()

        guard let groupID = data["groupID"] as? String,
              let authorID = data["authorID"] as? String,
              let authorName = data["authorName"] as? String,
              let caption = data["caption"] as? String,
              let videoURL = data["videoURL"] as? String,
              let storagePath = data["storagePath"] as? String else {
            return nil
        }

        let durationSeconds: Int
        if let intDuration = data["durationSeconds"] as? Int {
            durationSeconds = intDuration
        } else if let numberDuration = data["durationSeconds"] as? NSNumber {
            durationSeconds = numberDuration.intValue
        } else {
            durationSeconds = 3
        }

        let hourKey = data["hourKey"] as? String ?? ""
        let includesAudio = data["includesAudio"] as? Bool ?? true

        return Post(
            id: document.documentID,
            groupID: groupID,
            authorID: authorID,
            authorName: authorName,
            caption: caption,
            videoURL: videoURL,
            storagePath: storagePath,
            durationSeconds: durationSeconds,
            hourKey: hourKey,
            includesAudio: includesAudio
        )
    }
}
