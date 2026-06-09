import AVFoundation
import Foundation

final class VideoAudioService {
    func makeMutedCopy(from sourceURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        let asset = AVURLAsset(url: sourceURL)
        let composition = AVMutableComposition()

        guard let sourceVideoTrack = asset.tracks(withMediaType: .video).first,
              let compositionVideoTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
              ) else {
            completion(.failure(VideoAudioError.missingVideoTrack))
            return
        }

        do {
            try compositionVideoTrack.insertTimeRange(
                CMTimeRange(start: .zero, duration: asset.duration),
                of: sourceVideoTrack,
                at: .zero
            )
            compositionVideoTrack.preferredTransform = sourceVideoTrack.preferredTransform
        } catch {
            completion(.failure(error))
            return
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")

        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            completion(.failure(VideoAudioError.exportUnavailable))
            return
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov
        exportSession.shouldOptimizeForNetworkUse = true
        exportSession.exportAsynchronously {
            DispatchQueue.main.async {
                switch exportSession.status {
                case .completed:
                    completion(.success(outputURL))
                case .failed, .cancelled:
                    completion(.failure(exportSession.error ?? VideoAudioError.exportFailed))
                default:
                    completion(.failure(VideoAudioError.exportFailed))
                }
            }
        }
    }
}

enum VideoAudioError: LocalizedError {
    case missingVideoTrack
    case exportUnavailable
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .missingVideoTrack:
            return "영상 트랙을 찾을 수 없습니다."
        case .exportUnavailable:
            return "무음 영상을 만들 수 없습니다."
        case .exportFailed:
            return "무음 영상 저장에 실패했습니다."
        }
    }
}
