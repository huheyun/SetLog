import FirebaseAuth
import Foundation

final class PostUploadService {
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
            completion(.failure(PostUploadError.notLoggedIn))
            return
        }

        guard limitsOnePostPerHour else {
            uploadNewPost(
                fileURL: fileURL,
                group: group,
                caption: caption,
                durationSeconds: durationSeconds,
                hourKey: hourKey,
                includesAudio: includesAudio,
                user: user,
                completion: completion
            )
            return
        }

        postRepository.fetchPost(groupID: group.id, authorID: user.uid, hourKey: hourKey) { [weak self] existingPostResult in
            switch existingPostResult {
            case .failure(let error):
                completion(.failure(error))
            case .success(let existingPost):
                if existingPost != nil {
                    completion(.failure(PostUploadError.alreadyUploadedThisHour))
                    return
                }

                self?.uploadNewPost(
                    fileURL: fileURL,
                    group: group,
                    caption: caption,
                    durationSeconds: durationSeconds,
                    hourKey: hourKey,
                    includesAudio: includesAudio,
                    user: user,
                    completion: completion
                )
            }
        }
    }

    private func uploadNewPost(
        fileURL: URL,
        group: Group,
        caption: String,
        durationSeconds: Int,
        hourKey: String,
        includesAudio: Bool,
        user: User,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        videoStorageService.uploadVideo(fileURL: fileURL, groupID: group.id, ownerUID: user.uid) { [weak self] result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let upload):
                let postID = UUID().uuidString
                let post = Post(
                    id: postID,
                    groupID: group.id,
                    authorID: user.uid,
                    authorName: user.displayName ?? "Unknown",
                    caption: caption,
                    videoURL: upload.downloadURL.absoluteString,
                    storagePath: upload.storagePath,
                    durationSeconds: durationSeconds,
                    hourKey: hourKey,
                    includesAudio: includesAudio
                )

                self?.postRepository.createPost(post) { postResult in
                    switch postResult {
                    case .failure(let error):
                        completion(.failure(error))
                    case .success:
                        completion(.success(()))
                    }
                }
            }
        }
    }
}

enum PostUploadError: LocalizedError {
    case notLoggedIn
    case alreadyUploadedThisHour

    var errorDescription: String? {
        switch self {
        case .notLoggedIn:
            return "로그인이 필요합니다."
        case .alreadyUploadedThisHour:
            return "이 그룹에는 이번 시간에 이미 영상을 올렸습니다."
        }
    }
}
