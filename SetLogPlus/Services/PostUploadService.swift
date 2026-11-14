import FirebaseAuth
import Foundation

final class PostUploadService {
    /// When enabled, a user can post at most once per group per hour.
    private let limitsOnePostPerHour = false
    private let videoStorageService = VideoStorageService()
    private let postRepository = PostRepository()

    func uploadPost(
        fileURL: URL,
        group: Group,
        caption: String,
        durationSeconds: Int,
        hourKey: String,
        includesAudio: Bool,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let user = Auth.auth().currentUser else {
            completion(.failure(AuthError.notLoggedIn))
            return
        }

        let upload = { [videoStorageService, postRepository] in
            videoStorageService.uploadVideo(fileURL: fileURL, groupID: group.id, ownerUID: user.uid) { result in
                switch result {
                case .failure(let error):
                    completion(.failure(error))
                case .success(let upload):
                    let post = Post(
                        id: UUID().uuidString,
                        groupID: group.id,
                        authorID: user.uid,
                        authorName: user.displayName ?? user.email ?? "사용자",
                        caption: caption,
                        videoURL: upload.downloadURL.absoluteString,
                        storagePath: upload.storagePath,
                        durationSeconds: durationSeconds,
                        hourKey: hourKey,
                        includesAudio: includesAudio
                    )
                    postRepository.createPost(post, completion: completion)
                }
            }
        }

        guard limitsOnePostPerHour else {
            upload()
            return
        }

        postRepository.fetchPost(groupID: group.id, authorID: user.uid, hourKey: hourKey) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(.some):
                completion(.failure(PostUploadError.alreadyUploadedThisHour))
            case .success(.none):
                upload()
            }
        }
    }
}

enum PostUploadError: LocalizedError {
    case alreadyUploadedThisHour

    var errorDescription: String? {
        switch self {
        case .alreadyUploadedThisHour:
            return "이 그룹에는 이번 시간에 이미 영상을 올렸습니다."
        }
    }
}
