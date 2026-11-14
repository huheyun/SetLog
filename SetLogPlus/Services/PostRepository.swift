import FirebaseFirestore
import Foundation

final class PostRepository {
    private let db = Firestore.firestore()

    private var postsCollection: CollectionReference {
        db.collection("posts")
    }

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

        postsCollection.document(post.id).setData(data) { error in
            completion(Result(error: error))
        }
    }

    /// All posts in a group, newest first.
    func fetchPosts(groupID: String, completion: @escaping (Result<[Post], Error>) -> Void) {
        postsCollection
            .whereField("groupID", isEqualTo: groupID)
            .getDocuments { snapshot, error in
                if let error {
                    completion(.failure(error))
                    return
                }

                let posts = (snapshot?.documents.compactMap(Self.makePost(from:)) ?? [])
                    .sorted(by: Self.isNewer)
                completion(.success(posts))
            }
    }

    func fetchPost(groupID: String, authorID: String, hourKey: String, completion: @escaping (Result<Post?, Error>) -> Void) {
        postsCollection
            .whereField("groupID", isEqualTo: groupID)
            .whereField("authorID", isEqualTo: authorID)
            .whereField("hourKey", isEqualTo: hourKey)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let error {
                    completion(.failure(error))
                    return
                }

                completion(.success(snapshot?.documents.first.flatMap(Self.makePost(from:))))
            }
    }

    nonisolated private static func isNewer(_ lhs: Post, than rhs: Post) -> Bool {
        if lhs.hourKey != rhs.hourKey {
            return lhs.hourKey > rhs.hourKey
        }
        // Pending server timestamps (nil) are the most recent writes.
        return (lhs.createdAt ?? .distantFuture) > (rhs.createdAt ?? .distantFuture)
    }

    nonisolated private static func makePost(from document: QueryDocumentSnapshot) -> Post? {
        let data = document.data()

        guard let groupID = data["groupID"] as? String,
              let authorID = data["authorID"] as? String,
              let authorName = data["authorName"] as? String,
              let caption = data["caption"] as? String,
              let videoURL = data["videoURL"] as? String,
              let storagePath = data["storagePath"] as? String else {
            return nil
        }

        return Post(
            id: document.documentID,
            groupID: groupID,
            authorID: authorID,
            authorName: authorName,
            caption: caption,
            videoURL: videoURL,
            storagePath: storagePath,
            durationSeconds: (data["durationSeconds"] as? NSNumber)?.intValue ?? 3,
            hourKey: data["hourKey"] as? String ?? "",
            includesAudio: data["includesAudio"] as? Bool ?? true,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue()
        )
    }
}
