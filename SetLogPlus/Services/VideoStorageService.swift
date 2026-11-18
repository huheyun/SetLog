import FirebaseStorage
import Foundation

struct VideoUpload {
    let downloadURL: URL
    let storagePath: String
}

final class VideoStorageService {
    private let storage = Storage.storage()

    func uploadVideo(fileURL: URL, groupID: String, ownerUID: String, completion: @escaping (Result<VideoUpload, Error>) -> Void) {
        let storagePath = "videos/\(groupID)/\(ownerUID)/\(UUID().uuidString).mov"
        let reference = storage.reference().child(storagePath)

        let metadata = StorageMetadata()
        metadata.contentType = "video/quicktime"

        reference.putFile(from: fileURL, metadata: metadata) { _, error in
            if let error {
                completion(.failure(error))
                return
            }

            reference.downloadURL { url, urlError in
                if let urlError {
                    completion(.failure(urlError))
                } else if let url {
                    completion(.success(VideoUpload(downloadURL: url, storagePath: storagePath)))
                } else {
                    completion(.failure(StorageUploadError.missingDownloadURL))
                }
            }
        }
    }

    /// Deletes the object at `storagePath`. A missing object is treated as success.
    func deleteVideo(storagePath: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard !storagePath.isEmpty else {
            completion(.success(()))
            return
        }

        storage.reference(withPath: storagePath).delete { error in
            if let error, !Self.isObjectNotFound(error) {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }

    nonisolated private static func isObjectNotFound(_ error: Error) -> Bool {
        if case StorageError.objectNotFound = error {
            return true
        }
        let nsError = error as NSError
        return nsError.domain == StorageErrorDomain && nsError.code == StorageErrorCode.objectNotFound.rawValue
    }
}

enum StorageUploadError: LocalizedError {
    case missingDownloadURL

    var errorDescription: String? {
        switch self {
        case .missingDownloadURL:
            return "업로드된 영상의 다운로드 URL을 가져오지 못했습니다."
        }
    }
}
