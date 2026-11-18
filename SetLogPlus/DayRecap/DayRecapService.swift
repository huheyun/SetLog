import AVFoundation
import Foundation
import UIKit

/// Builds a "하루 영상": downloads a day's clips and stitches them, in order, into one
/// 1080x1920 video with a small "이름 · HH:00" caption over each clip.
///
/// All heavy lifting (downloads, asset loading, export) happens inside AVFoundation/URLSession
/// async APIs, so the service itself can stay on the main actor.
final class DayRecapService {
    struct Clip {
        let post: Post
        let authorName: String
        let hourText: String
    }

    enum Progress {
        case downloading(completed: Int, total: Int)
        case composing
    }

    struct Output {
        let url: URL
        let includedCount: Int
        let failedCount: Int
    }

    static let renderSize = CGSize(width: 1080, height: 1920)
    private static let frameDuration = CMTime(value: 1, timescale: 30)

    /// Every file the service writes lives here; delete the folder to clean up.
    let workDirectory: URL

    init(workDirectory: URL) {
        self.workDirectory = workDirectory
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: workDirectory)
    }

    /// Clips that fail to download or load are skipped (and counted in `failedCount`).
    /// Throws `DayRecapError.noPlayableClips` if none of them could be used.
    func makeRecap(clips: [Clip], progress: @escaping (Progress) -> Void) async throws -> Output {
        try FileManager.default.createDirectory(at: workDirectory, withIntermediateDirectories: true)

        progress(.downloading(completed: 0, total: clips.count))
        let localURLs = await downloadAll(clips, progress: progress)
        try Task.checkCancellation()

        progress(.composing)
        var segments: [Segment] = []
        for (index, clip) in clips.enumerated() {
            guard let url = localURLs[index], let segment = try? await loadSegment(clip: clip, url: url) else {
                continue
            }
            segments.append(segment)
        }
        try Task.checkCancellation()

        guard !segments.isEmpty else {
            throw DayRecapError.noPlayableClips
        }

        let outputURL = workDirectory
            .appendingPathComponent("SetLog_DayRecap_\(UUID().uuidString.prefix(8))")
            .appendingPathExtension("mp4")

        // AVVideoCompositionCoreAnimationTool crashes inside Core Animation on the iOS Simulator
        // (IOSurface XPC misuse), so captions are only rendered on real devices.
        #if targetEnvironment(simulator)
        let rendersCaptions = false
        #else
        let rendersCaptions = true
        #endif

        do {
            try await export(segments: segments, to: outputURL, withCaptions: rendersCaptions)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            // Captions are a nice-to-have: if the Core Animation pass fails, retry without it.
            try? FileManager.default.removeItem(at: outputURL)
            try Task.checkCancellation()
            try await export(segments: segments, to: outputURL, withCaptions: false)
        }

        return Output(url: outputURL, includedCount: segments.count, failedCount: clips.count - segments.count)
    }

    // MARK: - Download

    private func downloadAll(_ clips: [Clip], progress: @escaping (Progress) -> Void) async -> [URL?] {
        var results = [URL?](repeating: nil, count: clips.count)
        var completed = 0

        await withTaskGroup(of: (Int, URL?).self) { group in
            for (index, clip) in clips.enumerated() {
                group.addTask {
                    (index, try? await self.localFile(for: clip.post, index: index))
                }
            }
            for await (index, url) in group {
                results[index] = url
                completed += 1
                progress(.downloading(completed: completed, total: clips.count))
            }
        }
        return results
    }

    private func localFile(for post: Post, index: Int) async throws -> URL {
        guard let remoteURL = URL(string: post.videoURL) else {
            throw DayRecapError.invalidURL
        }
        if let cachedURL = VideoCache.shared.cachedURL(for: remoteURL) {
            return cachedURL
        }

        let (temporaryURL, response) = try await URLSession.shared.download(from: remoteURL)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            try? FileManager.default.removeItem(at: temporaryURL)
            throw DayRecapError.downloadFailed
        }

        let destination = workDirectory.appendingPathComponent("clip-\(index)").appendingPathExtension("mov")
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        return destination
    }

    // MARK: - Composition

    private struct Segment {
        let clip: Clip
        /// Keep the source asset alive until export finishes; tracks don't retain their asset.
        let asset: AVURLAsset
        let videoTrack: AVAssetTrack
        let videoRange: CMTimeRange
        let audioTrack: AVAssetTrack?
        let audioRange: CMTimeRange?
        let naturalSize: CGSize
        let preferredTransform: CGAffineTransform
    }

    private func loadSegment(clip: Clip, url: URL) async throws -> Segment {
        let asset = AVURLAsset(url: url)
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw DayRecapError.missingVideoTrack
        }
        let (trackRange, naturalSize, transform) = try await videoTrack.load(.timeRange, .naturalSize, .preferredTransform)
        let assetDuration = try await asset.load(.duration)

        let duration = CMTimeMinimum(trackRange.duration, assetDuration)
        guard duration.isValid, duration.seconds > 0.05, naturalSize.width > 0, naturalSize.height > 0 else {
            throw DayRecapError.missingVideoTrack
        }

        var audioTrack: AVAssetTrack?
        var audioRange: CMTimeRange?
        if let track = try? await asset.loadTracks(withMediaType: .audio).first,
           let range = try? await track.load(.timeRange),
           range.duration.seconds > 0 {
            audioTrack = track
            audioRange = CMTimeRange(start: range.start, duration: CMTimeMinimum(range.duration, duration))
        }

        return Segment(
            clip: clip,
            asset: asset,
            videoTrack: videoTrack,
            videoRange: CMTimeRange(start: trackRange.start, duration: duration),
            audioTrack: audioTrack,
            audioRange: audioRange,
            naturalSize: naturalSize,
            preferredTransform: transform
        )
    }

    private func export(segments: [Segment], to outputURL: URL, withCaptions: Bool) async throws {
        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw DayRecapError.compositionFailed
        }
        // Only add an audio track when at least one clip has sound; muted clips leave a silent gap.
        let audioTrack = segments.contains { $0.audioTrack != nil }
            ? composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            : nil

        var layerConfiguration = AVVideoCompositionLayerInstruction.Configuration(trackID: videoTrack.trackID)
        var captionTimings: [(clip: Clip, start: CMTime, duration: CMTime)] = []
        var cursor = CMTime.zero
        var audioEnd = CMTime.zero

        for segment in segments {
            try videoTrack.insertTimeRange(segment.videoRange, of: segment.videoTrack, at: cursor)
            if let audioTrack, let sourceAudio = segment.audioTrack, let audioRange = segment.audioRange {
                // Keep audio aligned with video: pad over muted clips with an explicit empty edit.
                if audioEnd < cursor {
                    audioTrack.insertEmptyTimeRange(CMTimeRange(start: audioEnd, end: cursor))
                }
                if (try? audioTrack.insertTimeRange(audioRange, of: sourceAudio, at: cursor)) != nil {
                    audioEnd = cursor + audioRange.duration
                }
            }
            layerConfiguration.setTransform(Self.aspectFillTransform(for: segment), at: cursor)
            captionTimings.append((segment.clip, cursor, segment.videoRange.duration))
            cursor = cursor + segment.videoRange.duration
        }

        let totalRange = CMTimeRange(start: .zero, duration: cursor)
        let instruction = AVVideoCompositionInstruction(configuration: .init(
            backgroundColor: UIColor.black.cgColor,
            layerInstructions: [AVVideoCompositionLayerInstruction(configuration: layerConfiguration)],
            timeRange: totalRange
        ))

        let animationTool = withCaptions ? Self.makeCaptionTool(timings: captionTimings) : nil
        let videoComposition = AVVideoComposition(configuration: .init(
            animationTool: animationTool,
            frameDuration: Self.frameDuration,
            instructions: [instruction],
            renderSize: Self.renderSize
        ))

        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw DayRecapError.compositionFailed
        }
        exportSession.videoComposition = videoComposition
        exportSession.shouldOptimizeForNetworkUse = true
        try? FileManager.default.removeItem(at: outputURL)
        try await exportSession.export(to: outputURL, as: .mp4)
    }

    /// Orients the clip upright, then scales it to fill 1080x1920 (center-cropped).
    private static func aspectFillTransform(for segment: Segment) -> CGAffineTransform {
        let transform = segment.preferredTransform
        let orientedRect = CGRect(origin: .zero, size: segment.naturalSize).applying(transform)
        let orientedSize = CGSize(width: abs(orientedRect.width), height: abs(orientedRect.height))
        let scale = max(renderSize.width / orientedSize.width, renderSize.height / orientedSize.height)
        let offsetX = (renderSize.width - orientedSize.width * scale) / 2
        let offsetY = (renderSize.height - orientedSize.height * scale) / 2

        return transform
            .concatenating(CGAffineTransform(translationX: -orientedRect.minX, y: -orientedRect.minY))
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(translationX: offsetX, y: offsetY))
    }

    // MARK: - Captions

    private static func makeCaptionTool(timings: [(clip: Clip, start: CMTime, duration: CMTime)]) -> AVVideoCompositionCoreAnimationTool {
        let frame = CGRect(origin: .zero, size: renderSize)
        let parentLayer = CALayer()
        parentLayer.frame = frame
        let videoLayer = CALayer()
        videoLayer.frame = frame
        parentLayer.addSublayer(videoLayer)

        for timing in timings {
            let caption = makeCaptionLayer(text: "\(timing.clip.authorName) · \(timing.clip.hourText)")
            caption.opacity = 0

            // Visible only during its clip; the animation is removed afterwards, reverting to hidden.
            let visibility = CABasicAnimation(keyPath: "opacity")
            visibility.fromValue = 1
            visibility.toValue = 1
            visibility.beginTime = AVCoreAnimationBeginTimeAtZero + timing.start.seconds
            visibility.duration = timing.duration.seconds
            visibility.isRemovedOnCompletion = true
            caption.add(visibility, forKey: "visibility")

            parentLayer.addSublayer(caption)
        }

        return AVVideoCompositionCoreAnimationTool(configuration: .init(
            postProcessingAsVideoLayer: videoLayer,
            containingLayer: parentLayer
        ))
    }

    /// Rounded dark pill in the bottom-left corner. Core Animation coordinates here are bottom-up.
    private static func makeCaptionLayer(text: String) -> CALayer {
        let baseFont = UIFont.systemFont(ofSize: 40, weight: .bold)
        let font = baseFont.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: 40) } ?? baseFont
        let attributed = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: UIColor.white
        ])

        let maxTextWidth = renderSize.width - 56 * 2 - 36 * 2
        let measured = attributed.boundingRect(
            with: CGSize(width: maxTextWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        let textSize = CGSize(width: min(ceil(measured.width) + 2, maxTextWidth), height: ceil(font.lineHeight))

        let pill = CALayer()
        pill.frame = CGRect(x: 56, y: 150, width: textSize.width + 36 * 2, height: textSize.height + 22 * 2)
        pill.backgroundColor = UIColor.black.withAlphaComponent(0.5).cgColor
        pill.cornerRadius = pill.frame.height / 2
        pill.masksToBounds = true

        let textLayer = CATextLayer()
        textLayer.string = attributed
        textLayer.frame = CGRect(x: 36, y: 22, width: textSize.width, height: textSize.height)
        textLayer.truncationMode = .end
        textLayer.contentsScale = 1
        textLayer.alignmentMode = .left
        pill.addSublayer(textLayer)
        return pill
    }
}

enum DayRecapError: LocalizedError {
    case invalidURL
    case downloadFailed
    case missingVideoTrack
    case noPlayableClips
    case compositionFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL, .downloadFailed:
            return "영상을 내려받지 못했어요."
        case .missingVideoTrack:
            return "영상을 읽을 수 없어요."
        case .noPlayableClips:
            return "불러올 수 있는 영상이 없어요."
        case .compositionFailed:
            return "영상을 합치지 못했어요."
        }
    }
}
