import CryptoKit
import Foundation

/// Disk cache for downloaded videos so a clip that was already loaded plays instantly
/// when the user comes back to it (instead of streaming it again).
final class VideoCache {
    static let shared = VideoCache()

    private let directory: URL
    private var inFlight: Set<String> = []
    private static let maxAge: TimeInterval = 7 * 24 * 60 * 60

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        directory = caches.appendingPathComponent("VideoCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        removeExpiredFiles()
    }

    /// Local file URL if cached; otherwise the remote URL (and a download starts in the background).
    func playableURL(for remoteURL: URL) -> URL {
        if let cached = cachedURL(for: remoteURL) {
            return cached
        }
        prefetch(remoteURL)
        return remoteURL
    }

    func cachedURL(for remoteURL: URL) -> URL? {
        guard !remoteURL.isFileURL else { return remoteURL }
        let fileURL = localFileURL(for: remoteURL)
        return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
    }

    func prefetch(_ remoteURL: URL) {
        guard !remoteURL.isFileURL else { return }
        let key = Self.key(for: remoteURL)
        guard cachedURL(for: remoteURL) == nil, !inFlight.contains(key) else { return }
        inFlight.insert(key)

        let destination = localFileURL(for: remoteURL)
        Task {
            defer { inFlight.remove(key) }
            do {
                let (temporaryURL, response) = try await URLSession.shared.download(from: remoteURL)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                    try? FileManager.default.removeItem(at: temporaryURL)
                    return
                }
                try? FileManager.default.removeItem(at: destination)
                try FileManager.default.moveItem(at: temporaryURL, to: destination)
            } catch {
                // Best effort: playback falls back to streaming.
            }
        }
    }

    private func localFileURL(for remoteURL: URL) -> URL {
        directory.appendingPathComponent(Self.key(for: remoteURL)).appendingPathExtension("mov")
    }

    /// Firebase download URLs carry a token query; key on the object path so a new token still hits the cache.
    private static func key(for remoteURL: URL) -> String {
        var components = URLComponents(url: remoteURL, resolvingAgainstBaseURL: false)
        components?.query = nil
        let source = components?.string ?? remoteURL.absoluteString
        return SHA256.hash(data: Data(source.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func removeExpiredFiles() {
        let directory = directory
        let maxAge = Self.maxAge
        Task.detached(priority: .background) {
            let fileManager = FileManager.default
            guard let files = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey]
            ) else { return }

            let cutoff = Date().addingTimeInterval(-maxAge)
            for file in files {
                let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                if let modified, modified < cutoff {
                    try? fileManager.removeItem(at: file)
                }
            }
        }
    }
}
