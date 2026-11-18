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
