import AVKit
import UIKit

final class VideoDetailViewController: UIViewController {
    private let post: Post
    private let member: GroupMember
    private let hourDate: Date
    private let player: AVPlayer
    private let reactionRepository = ReactionRepository()
    private let playerViewController = AVPlayerViewController()
    private let soundButton = IconCircleButton(systemName: "speaker.wave.2.fill")
    private let reactionButton = IconCircleButton(systemName: "heart")
    private let reactionSummaryLabel = UILabel()
    private let loadingContainerView = UIView()
    private let loadingIndicatorView = UIActivityIndicatorView(style: .large)
    private let loadingLabel = UILabel()
    private var playerStatusObservation: NSKeyValueObservation?
    private var playbackEndObserver: NSObjectProtocol?
    private var reactions: [PostReaction] = []
    private var isMuted = false

    init(post: Post, member: GroupMember, hourDate: Date) {
        self.post = post
        self.member = member
        self.hourDate = hourDate
        if let url = URL(string: post.videoURL) {
            player = AVPlayer(url: url)
        } else {
            player = AVPlayer()
        }
        player.actionAtItemEnd = .none
        super.init(nibName: nil, bundle: nil)
    }

    deinit {
        if let playbackEndObserver {
            NotificationCenter.default.removeObserver(playbackEndObserver)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = ""
        view.backgroundColor = AppTheme.background
        navigationController?.setNavigationBarHidden(true, animated: false)
        setupLayout()
        observePlayerStatus()
        observePlaybackEnd()
        fetchReactions()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        player.play()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        player.pause()
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    private func setupLayout() {
        let videoContainerView = UIView()
        videoContainerView.backgroundColor = AppTheme.cardMuted
        videoContainerView.translatesAutoresizingMaskIntoConstraints = false

        player.isMuted = isMuted
        playerViewController.player = player
        playerViewController.showsPlaybackControls = false
        addChild(playerViewController)
        videoContainerView.addSubview(playerViewController.view)
        playerViewController.view.translatesAutoresizingMaskIntoConstraints = false
        playerViewController.didMove(toParent: self)

        let closeButton = IconCircleButton(systemName: "xmark")
        closeButton.configuration?.baseBackgroundColor = UIColor.black.withAlphaComponent(0.42)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        let nameLabel = UILabel()
        nameLabel.text = member.displayName
        nameLabel.font = .systemFont(ofSize: 18, weight: .black)
        nameLabel.textColor = .white
        AppTheme.applyTextShadow(to: nameLabel, opacity: 0.6, radius: 5)

        let timeLabel = UILabel()
        timeLabel.text = HourSlot.displayText(date: hourDate)
        timeLabel.font = .systemFont(ofSize: 34, weight: .black)
        timeLabel.textColor = .white
        AppTheme.applyTextShadow(to: timeLabel, opacity: 0.6, radius: 5)

        let textStackView = UIStackView(arrangedSubviews: [nameLabel, timeLabel])
        textStackView.axis = .vertical
        textStackView.spacing = 6
        textStackView.translatesAutoresizingMaskIntoConstraints = false

        soundButton.configuration?.baseBackgroundColor = UIColor.black.withAlphaComponent(0.42)
        soundButton.addTarget(self, action: #selector(soundTapped), for: .touchUpInside)
        updateSoundButton()

        reactionButton.configuration?.baseBackgroundColor = UIColor.black.withAlphaComponent(0.42)
        reactionButton.addTarget(self, action: #selector(reactionTapped), for: .touchUpInside)
        updateReactionButton()

        reactionSummaryLabel.font = .systemFont(ofSize: 15, weight: .black)
        reactionSummaryLabel.textColor = .white
        reactionSummaryLabel.textAlignment = .right
        AppTheme.applyTextShadow(to: reactionSummaryLabel, opacity: 0.6)
        reactionSummaryLabel.translatesAutoresizingMaskIntoConstraints = false

        loadingContainerView.backgroundColor = UIColor.black.withAlphaComponent(0.42)
        loadingContainerView.layer.cornerRadius = 16
        loadingContainerView.translatesAutoresizingMaskIntoConstraints = false

        loadingIndicatorView.color = .white
        loadingIndicatorView.startAnimating()

        loadingLabel.text = "영상 로딩 중"
        loadingLabel.font = .systemFont(ofSize: 14, weight: .bold)
        loadingLabel.textColor = .white

        let loadingStackView = UIStackView(arrangedSubviews: [loadingIndicatorView, loadingLabel])
        loadingStackView.axis = .vertical
        loadingStackView.alignment = .center
        loadingStackView.spacing = 10
        loadingStackView.translatesAutoresizingMaskIntoConstraints = false
        loadingContainerView.addSubview(loadingStackView)

        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(closeTapped))
        tapRecognizer.cancelsTouchesInView = false
        tapRecognizer.delegate = self
        view.addGestureRecognizer(tapRecognizer)

        view.addSubview(videoContainerView)
        view.addSubview(closeButton)
        view.addSubview(textStackView)
        view.addSubview(soundButton)
        view.addSubview(reactionButton)
        view.addSubview(reactionSummaryLabel)
        view.addSubview(loadingContainerView)

        NSLayoutConstraint.activate([
            videoContainerView.topAnchor.constraint(equalTo: view.topAnchor),
            videoContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            videoContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            videoContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            playerViewController.view.topAnchor.constraint(equalTo: videoContainerView.topAnchor),
            playerViewController.view.leadingAnchor.constraint(equalTo: videoContainerView.leadingAnchor),
            playerViewController.view.trailingAnchor.constraint(equalTo: videoContainerView.trailingAnchor),
            playerViewController.view.bottomAnchor.constraint(equalTo: videoContainerView.bottomAnchor),

            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            closeButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),

            textStackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 22),
            textStackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -34),
            textStackView.trailingAnchor.constraint(lessThanOrEqualTo: reactionSummaryLabel.leadingAnchor, constant: -18),

            soundButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -22),
            soundButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),

            reactionButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -22),
            reactionButton.bottomAnchor.constraint(equalTo: soundButton.topAnchor, constant: -14),

            reactionSummaryLabel.trailingAnchor.constraint(equalTo: reactionButton.leadingAnchor, constant: -10),
            reactionSummaryLabel.centerYAnchor.constraint(equalTo: reactionButton.centerYAnchor),
            reactionSummaryLabel.leadingAnchor.constraint(greaterThanOrEqualTo: textStackView.trailingAnchor, constant: 10),

            loadingContainerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingContainerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            loadingContainerView.widthAnchor.constraint(equalToConstant: 132),
            loadingContainerView.heightAnchor.constraint(equalToConstant: 112),

            loadingStackView.centerXAnchor.constraint(equalTo: loadingContainerView.centerXAnchor),
            loadingStackView.centerYAnchor.constraint(equalTo: loadingContainerView.centerYAnchor)
        ])
    }

    private func observePlayerStatus() {
        guard let item = player.currentItem else {
            loadingLabel.text = "영상을 불러오지 못했어요"
            loadingIndicatorView.stopAnimating()
            return
        }

        playerStatusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                switch item.status {
                case .readyToPlay:
                    self?.loadingContainerView.isHidden = true
                    self?.loadingIndicatorView.stopAnimating()
                case .failed:
                    self?.loadingContainerView.isHidden = false
                    self?.loadingLabel.text = "영상을 불러오지 못했어요"
                    self?.loadingIndicatorView.stopAnimating()
                case .unknown:
                    self?.loadingContainerView.isHidden = false
                    self?.loadingLabel.text = "영상 로딩 중"
                    self?.loadingIndicatorView.startAnimating()
                @unknown default:
                    self?.loadingContainerView.isHidden = false
                    self?.loadingLabel.text = "영상 로딩 중"
                    self?.loadingIndicatorView.startAnimating()
                }
            }
        }
    }

    /// Loops playback like the feed preview.
    private func observePlaybackEnd() {
        guard let item = player.currentItem else { return }

        playbackEndObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.player.seek(to: .zero)
            self?.player.play()
        }
    }

    @objc private func soundTapped() {
        isMuted.toggle()
        player.isMuted = isMuted
        updateSoundButton()
    }

    @objc private func reactionTapped() {
        presentReactionPicker(currentEmoji: myReaction()?.emoji, from: reactionButton) { [weak self] emoji in
            self?.toggleReaction(emoji: emoji)
        }
    }

    private func updateSoundButton() {
        var configuration = soundButton.configuration
        configuration?.image = UIImage(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
        configuration?.baseForegroundColor = isMuted ? AppTheme.secondaryText : .white
        soundButton.configuration = configuration
    }

    private func fetchReactions() {
        reactionRepository.fetchReactions(postIDs: [post.id]) { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let reactionsByPostID):
                self.reactions = reactionsByPostID[self.post.id] ?? []
                self.updateReactionButton()
            case .failure(let error):
                ToastView.show(message: "반응을 불러오지 못했어요: \(error.localizedDescription)", in: self.view)
            }
        }
    }

    private func toggleReaction(emoji: String) {
        reactionRepository.toggleReaction(
            postID: post.id,
            emoji: emoji,
            currentEmoji: myReaction()?.emoji
        ) { [weak self] result in
            guard let self else { return }

            switch result {
            case .success:
                self.fetchReactions()
            case .failure(let error):
                ToastView.show(message: "반응 저장 실패: \(error.localizedDescription)", in: self.view)
            }
        }
    }

    private func myReaction() -> PostReaction? {
        reactions.reaction(by: AuthService.shared.currentUserID)
    }

    private func updateReactionButton() {
        var configuration = reactionButton.configuration
        let emoji = myReaction()?.emoji
        configuration?.image = emoji == nil ? UIImage(systemName: "heart") : nil
        configuration?.title = emoji
        configuration?.baseForegroundColor = .white
        reactionButton.configuration = configuration
        reactionSummaryLabel.text = reactionSummaryText()
    }

    private func reactionSummaryText() -> String {
        ReactionFormatter.summaryText(for: reactions, maxEmojiCount: 3)
    }

    @objc private func closeTapped() {
        navigationController?.popViewController(animated: true)
    }
}

extension VideoDetailViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var touchedView = touch.view

        while let view = touchedView {
            if view is UIControl {
                return false
            }
            touchedView = view.superview
        }

        return true
    }
}
