import AVFoundation
import UIKit

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
        setup(isMuted: isMuted)
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

    private func setup(isMuted: Bool) {
        backgroundColor = AppTheme.cardMuted
        setupLoadingView()

        player.isMuted = isMuted
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill

        observeCurrentItem()

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            self?.player.seek(to: .zero)
            self?.player.play()
        }

        player.play()
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
            player.play()
        case .failed:
            loadingIndicator.stopAnimating()
            loadingStackView.isHidden = false
            loadingLabel.text = "영상을 불러오지 못했어요"
            retryButton.isHidden = false
        case .unknown:
            loadingStackView.isHidden = false
            loadingLabel.text = "영상 로딩 중"
            retryButton.isHidden = true
            loadingIndicator.startAnimating()
        @unknown default:
            loadingStackView.isHidden = false
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
        loadingLabel.text = "영상 로딩 중"
        retryButton.isHidden = true
        loadingStackView.isHidden = false
        loadingIndicator.startAnimating()
        statusObservation = nil
        player.replaceCurrentItem(with: AVPlayerItem(url: url))
        player.isMuted = isMuted
        observeCurrentItem()
        player.play()
    }
}
