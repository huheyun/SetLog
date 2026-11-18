import AVFoundation
import UIKit

/// Looping, auto-playing video preview. Playback pauses while the view is off-screen.
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
        player = AVPlayer(url: url)
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
        loadingIndicator.color = .white
        loadingIndicator.startAnimating()

        loadingLabel.text = "영상 로딩 중"
        loadingLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        loadingLabel.textColor = UIColor.white.withAlphaComponent(0.72)
        loadingLabel.textAlignment = .center

        retryButton.setTitle("다시 시도", for: .normal)
        retryButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .bold)
        retryButton.tintColor = AppTheme.mint
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

    private func showLoading() {
        loadingStackView.isHidden = false
        loadingLabel.text = "영상 로딩 중"
        retryButton.isHidden = true
        loadingIndicator.startAnimating()
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
        player.replaceCurrentItem(with: AVPlayerItem(url: url))
        player.isMuted = isMuted
        observeCurrentItem()
        player.play()
    }
}
