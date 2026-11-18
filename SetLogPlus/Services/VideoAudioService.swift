import AVFoundation
import Foundation

final class VideoAudioService {
    /// Writes a copy of the video at `sourceURL` with its audio tracks removed.
    func makeMutedCopy(from sourceURL: URL) async throws -> URL {
        let asset = AVURLAsset(url: sourceURL)

        guard let sourceVideoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw VideoAudioError.missingVideoTrack
        }

        let duration = try await asset.load(.duration)
        let preferredTransform = try await sourceVideoTrack.load(.preferredTransform)

        let composition = AVMutableComposition()
        guard let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw VideoAudioError.missingVideoTrack
        }

        try compositionVideoTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: duration),
            of: sourceVideoTrack,
            at: .zero
        )
        compositionVideoTrack.preferredTransform = preferredTransform

        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw VideoAudioError.exportUnavailable
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")

        exportSession.shouldOptimizeForNetworkUse = true
        try await exportSession.export(to: outputURL, as: .mov)
        return outputURL
    }

    func makeMutedCopy(from sourceURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        Task { @MainActor in
            do {
                completion(.success(try await makeMutedCopy(from: sourceURL)))
            } catch {
                completion(.failure(error))
            }
        }
    }
}

enum VideoAudioError: LocalizedError {
    case missingVideoTrack
    case exportUnavailable

    var errorDescription: String? {
        switch self {
        case .missingVideoTrack:
            return "영상 트랙을 찾을 수 없습니다."
        case .exportUnavailable:
            return "무음 영상을 만들 수 없습니다."
        }
    }
}
