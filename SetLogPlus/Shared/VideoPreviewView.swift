import AVFoundation
import UIKit

/// Looping, auto-playing video preview. Playback pauses while the view is off-screen.
///
/// The preview is transparent to touches (except its "다시 시도" button), so it can sit inside
/// a tappable card such as a `PressableControl` without swallowing the tap.
final class VideoPreviewView: UIView {
    private let url: URL
    private let player: AVPlayer
    private let isMuted: Bool
    private let loadingStackView = UIStackView()
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    private let loadingLabel = UILabel()
    private let retryButton = UIButton(type: .system)
    private var statusObservation: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?

    init(url: URL, isMuted: Bool = true) {
        self.url = url
        player = AVPlayer(url: VideoCache.shared.playableURL(for: url))
        self.isMuted = isMuted
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
    }

    override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    private var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hitView = super.hitTest(point, with: event),
              hitView.isDescendant(of: retryButton) else {
            return nil
        }
        return hitView
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            player.pause()
        } else {
            player.play()
        }
    }

    private func setup() {
        backgroundColor = AppTheme.cardMuted
        setupLoadingView()

        player.isMuted = isMuted
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill

        observeCurrentItem()

        // Observe all items and filter, so looping keeps working after `retryTapped` swaps the item.
        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let item = notification.object as? AVPlayerItem,
                  item === self.player.currentItem else {
                return
            }
            self.player.seek(to: .zero)
            self.player.play()
        }
    }

    private func setupLoadingView() {
        loadingIndicator.color = AppTheme.secondaryText
        loadingIndicator.startAnimating()

        loadingLabel.text = "영상 로딩 중"
        loadingLabel.font = AppTheme.roundedFont(.caption1, weight: .semibold)
        loadingLabel.adjustsFontForContentSizeCategory = true
        loadingLabel.textColor = AppTheme.tertiaryText
        loadingLabel.textAlignment = .center

        var retryConfiguration = UIButton.Configuration.filled()
        retryConfiguration.title = "다시 시도"
        retryConfiguration.image = UIImage(systemName: "arrow.clockwise")
        retryConfiguration.imagePadding = 6
        retryConfiguration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 11, weight: .bold)
        retryConfiguration.cornerStyle = .capsule
        retryConfiguration.baseBackgroundColor = AppTheme.neonPink.withAlphaComponent(0.18)
        retryConfiguration.baseForegroundColor = AppTheme.neonPink
        retryConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
        retryConfiguration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = AppTheme.roundedFont(.caption1, weight: .bold)
            return attributes
        }
        retryButton.configuration = retryConfiguration
        retryButton.enablePressAnimation()
        retryButton.isHidden = true
        retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)

        loadingStackView.axis = .vertical
        loadingStackView.alignment = .center
        loadingStackView.spacing = 8
        loadingStackView.translatesAutoresizingMaskIntoConstraints = false
        loadingStackView.addArrangedSubview(loadingIndicator)
        loadingStackView.addArrangedSubview(loadingLabel)
        loadingStackView.addArrangedSubview(retryButton)

        addSubview(loadingStackView)
        loadingStackView.isHidden = true

        NSLayoutConstraint.activate([
            loadingStackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            loadingStackView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    private func handleStatus(_ status: AVPlayerItem.Status) {
        switch status {
        case .readyToPlay:
            loadingStackView.isHidden = true
            loadingIndicator.stopAnimating()
            retryButton.isHidden = true
            if window != nil {
                player.play()
            }
        case .failed:
            loadingIndicator.stopAnimating()
            loadingStackView.isHidden = false
            loadingLabel.text = "영상을 불러오지 못했어요"
            retryButton.isHidden = false
        case .unknown:
            showLoading()
        @unknown default:
            loadingStackView.isHidden = false
        }
    }

    /// The spinner appears only if loading takes noticeably long, so cached clips don't flash it.
    private func showLoading() {
        loadingLabel.text = "영상 로딩 중"
        retryButton.isHidden = true
        loadingStackView.isHidden = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self, self.player.currentItem?.status == .unknown else { return }
            self.loadingStackView.isHidden = false
            self.loadingIndicator.startAnimating()
        }
    }

    private func observeCurrentItem() {
        statusObservation = player.currentItem?.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                self?.handleStatus(item.status)
            }
        }
    }

    @objc private func retryTapped() {
        showLoading()
        statusObservation = nil
        player.replaceCurrentItem(with: AVPlayerItem(url: VideoCache.shared.playableURL(for: url)))
        player.isMuted = isMuted
        observeCurrentItem()
        player.play()
    }
}
