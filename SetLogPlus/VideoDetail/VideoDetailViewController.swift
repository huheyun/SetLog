import AVKit
import FirebaseFirestore
import UIKit

final class VideoDetailViewController: UIViewController {
    private let post: Post
    private let member: GroupMember
    private let hourDate: Date
    private let player: AVPlayer
    private let reactionRepository = ReactionRepository()
    private let commentRepository = CommentRepository()
    private let postRepository = PostRepository()
    private let playerViewController = AVPlayerViewController()
    private let soundButton = IconCircleButton(systemName: "speaker.wave.2.fill", accessibilityLabel: "소리 끄기")
    private let reactionButton = IconCircleButton(systemName: "heart", accessibilityLabel: "반응 남기기")
    private let commentButton = IconCircleButton(systemName: "bubble.right", accessibilityLabel: "댓글")
    private let commentBadgeLabel = UILabel()
    private let commentPreviewButton = UIButton(type: .system)
    private let moreButton = IconCircleButton(systemName: "ellipsis", accessibilityLabel: "게시물 관리")
    private let reactionSummaryPill = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let reactionSummaryLabel = UILabel()
    private let loadingContainerView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))
    private let loadingIndicatorView = UIActivityIndicatorView(style: .medium)
    private let loadingLabel = UILabel()
    private let playbackIconContainer = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))
    private let playbackIconView = UIImageView()
    private var playerStatusObservation: NSKeyValueObservation?
    private var playbackEndObserver: NSObjectProtocol?
    private var reactions: [PostReaction] = []
    private var comments: [PostComment] = []
    private var commentsListener: ListenerRegistration?
    private var isDeleting = false
    private var isMuted = false
    private var isPausedByUser = false

    init(post: Post, member: GroupMember, hourDate: Date) {
        self.post = post
        self.member = member
        self.hourDate = hourDate
        if let url = URL(string: post.videoURL) {
            player = AVPlayer(url: VideoCache.shared.playableURL(for: url))
        } else {
            player = AVPlayer()
        }
        player.actionAtItemEnd = .none
        super.init(nibName: nil, bundle: nil)
    }

    deinit {
        commentsListener?.remove()
        if let playbackEndObserver {
            NotificationCenter.default.removeObserver(playbackEndObserver)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = ""
        view.backgroundColor = .black
        navigationController?.setNavigationBarHidden(true, animated: false)
        setupLayout()
        observePlayerStatus()
        observePlaybackEnd()
        fetchReactions()
        listenComments()
    }

    private var isOwnPost: Bool {
        guard let currentUserID = AuthService.shared.currentUserID else { return false }
        return post.authorID == currentUserID
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Re-hide after a cancelled interactive pop, which restores the bar in `viewWillDisappear`.
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !isPausedByUser {
            player.play()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        player.pause()
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    // MARK: - Layout

    private func setupLayout() {
        let videoContainerView = UIView()
        videoContainerView.backgroundColor = .black
        videoContainerView.translatesAutoresizingMaskIntoConstraints = false

        player.isMuted = isMuted
        playerViewController.player = player
        playerViewController.showsPlaybackControls = false
        playerViewController.videoGravity = .resizeAspectFill
        playerViewController.view.backgroundColor = .black
        addChild(playerViewController)
        videoContainerView.addSubview(playerViewController.view)
        playerViewController.view.translatesAutoresizingMaskIntoConstraints = false
        playerViewController.didMove(toParent: self)

        let topGradientView = VideoGradientView(direction: .topDown, maxAlpha: 0.6)
        let bottomGradientView = VideoGradientView(direction: .bottomUp, maxAlpha: 0.75)

        // Top bar: back button + author.
        let closeButton = IconCircleButton(systemName: "chevron.backward", accessibilityLabel: "뒤로")
        closeButton.configuration?.baseBackgroundColor = UIColor.black.withAlphaComponent(0.35)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        moreButton.configuration?.baseBackgroundColor = UIColor.black.withAlphaComponent(0.35)
        moreButton.addTarget(self, action: #selector(moreTapped), for: .touchUpInside)
        moreButton.isHidden = !isOwnPost

        let avatarLabel = AppTheme.makeAvatarLabel(
            text: String(member.displayName.prefix(1)),
            size: 36,
            fontSize: 15,
            color: AppTheme.avatarColor(for: member.uid)
        )
        avatarLabel.layer.borderWidth = 1.5
        avatarLabel.layer.borderColor = UIColor.white.withAlphaComponent(0.85).cgColor

        let nameLabel = UILabel()
        nameLabel.text = member.displayName
        nameLabel.font = AppTheme.roundedFont(.headline, weight: .bold)
        nameLabel.adjustsFontForContentSizeCategory = true
        nameLabel.textColor = .white
        nameLabel.lineBreakMode = .byTruncatingTail

        let timeLabel = UILabel()
        timeLabel.text = "\(HourSlot.displayText(date: hourDate)) 로그"
        timeLabel.font = AppTheme.roundedFont(.caption1, weight: .semibold)
        timeLabel.adjustsFontForContentSizeCategory = true
        timeLabel.textColor = UIColor.white.withAlphaComponent(0.75)

        let authorTextStackView = UIStackView(arrangedSubviews: [nameLabel, timeLabel])
        authorTextStackView.axis = .vertical
        authorTextStackView.spacing = 1

        let authorStackView = UIStackView(arrangedSubviews: [avatarLabel, authorTextStackView])
        authorStackView.axis = .horizontal
        authorStackView.alignment = .center
        authorStackView.spacing = AppTheme.Spacing.s + 2
        authorStackView.isAccessibilityElement = true
        authorStackView.accessibilityTraits = .header
        authorStackView.accessibilityLabel = "\(member.displayName), \(HourSlot.displayText(date: hourDate)) 로그"
        authorStackView.translatesAutoresizingMaskIntoConstraints = false

        // Bottom bar: caption + reaction summary, reaction & sound buttons.
        let captionLabel = UILabel()
        let caption = post.caption.trimmingCharacters(in: .whitespacesAndNewlines)
        captionLabel.text = caption
        captionLabel.isHidden = caption.isEmpty
        captionLabel.font = AppTheme.roundedFont(.body, weight: .semibold)
        captionLabel.adjustsFontForContentSizeCategory = true
        captionLabel.textColor = .white
        captionLabel.numberOfLines = 3

        reactionSummaryLabel.font = AppTheme.roundedFont(.subheadline, weight: .bold)
        reactionSummaryLabel.adjustsFontForContentSizeCategory = true
        reactionSummaryLabel.textColor = .white
        reactionSummaryLabel.translatesAutoresizingMaskIntoConstraints = false

        reactionSummaryPill.layer.cornerRadius = 16
        reactionSummaryPill.layer.cornerCurve = .continuous
        reactionSummaryPill.clipsToBounds = true
        reactionSummaryPill.isHidden = true
        reactionSummaryPill.contentView.addSubview(reactionSummaryLabel)

        setupCommentPreviewButton()

        let leadingStackView = UIStackView(arrangedSubviews: [captionLabel, reactionSummaryPill, commentPreviewButton])
        leadingStackView.axis = .vertical
        leadingStackView.alignment = .leading
        leadingStackView.spacing = AppTheme.Spacing.s
        leadingStackView.translatesAutoresizingMaskIntoConstraints = false

        soundButton.configuration?.baseBackgroundColor = UIColor.black.withAlphaComponent(0.35)
        soundButton.addTarget(self, action: #selector(soundTapped), for: .touchUpInside)
        updateSoundButton()

        reactionButton.configuration?.baseBackgroundColor = UIColor.black.withAlphaComponent(0.35)
        reactionButton.addTarget(self, action: #selector(reactionTapped), for: .touchUpInside)
        updateReactionButton()

        commentButton.configuration?.baseBackgroundColor = UIColor.black.withAlphaComponent(0.35)
        commentButton.addTarget(self, action: #selector(commentsTapped), for: .touchUpInside)
        setupCommentBadge()
        updateCommentViews()

        let buttonsStackView = UIStackView(arrangedSubviews: [reactionButton, commentButton, soundButton])
        buttonsStackView.axis = .vertical
        buttonsStackView.spacing = AppTheme.Spacing.m
        buttonsStackView.translatesAutoresizingMaskIntoConstraints = false

        // Loading state.
        loadingContainerView.layer.cornerRadius = 20
        loadingContainerView.layer.cornerCurve = .continuous
        loadingContainerView.clipsToBounds = true
        loadingContainerView.translatesAutoresizingMaskIntoConstraints = false

        loadingIndicatorView.color = .white
        loadingIndicatorView.startAnimating()

        loadingLabel.text = "영상 로딩 중"
        loadingLabel.font = AppTheme.roundedFont(.footnote, weight: .semibold)
        loadingLabel.adjustsFontForContentSizeCategory = true
        loadingLabel.textColor = UIColor.white.withAlphaComponent(0.85)
        loadingLabel.textAlignment = .center
        loadingLabel.numberOfLines = 0

        let loadingStackView = UIStackView(arrangedSubviews: [loadingIndicatorView, loadingLabel])
        loadingStackView.axis = .vertical
        loadingStackView.alignment = .center
        loadingStackView.spacing = 10
        loadingStackView.translatesAutoresizingMaskIntoConstraints = false
        loadingContainerView.contentView.addSubview(loadingStackView)

        // Play/pause feedback.
        playbackIconContainer.layer.cornerRadius = 36
        playbackIconContainer.clipsToBounds = true
        playbackIconContainer.alpha = 0
        playbackIconContainer.isUserInteractionEnabled = false
        playbackIconContainer.translatesAutoresizingMaskIntoConstraints = false
        playbackIconView.tintColor = .white
        playbackIconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 28, weight: .bold)
        playbackIconView.translatesAutoresizingMaskIntoConstraints = false
        playbackIconContainer.contentView.addSubview(playbackIconView)

        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(videoTapped))
        tapRecognizer.cancelsTouchesInView = false
        tapRecognizer.delegate = self
        view.addGestureRecognizer(tapRecognizer)

        let swipeDownRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(closeTapped))
        swipeDownRecognizer.direction = .down
        swipeDownRecognizer.delegate = self
        view.addGestureRecognizer(swipeDownRecognizer)

        authorStackView.accessibilityCustomActions = [
            UIAccessibilityCustomAction(name: "재생/일시정지") { [weak self] _ in
                self?.togglePlayback()
                return true
            }
        ]

        view.addSubview(videoContainerView)
        view.addSubview(topGradientView)
        view.addSubview(bottomGradientView)
        view.addSubview(closeButton)
        view.addSubview(authorStackView)
        view.addSubview(moreButton)
        view.addSubview(leadingStackView)
        view.addSubview(buttonsStackView)
        view.addSubview(playbackIconContainer)
        view.addSubview(loadingContainerView)

        let margin = AppTheme.Spacing.l

        NSLayoutConstraint.activate([
            videoContainerView.topAnchor.constraint(equalTo: view.topAnchor),
            videoContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            videoContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            videoContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            playerViewController.view.topAnchor.constraint(equalTo: videoContainerView.topAnchor),
            playerViewController.view.leadingAnchor.constraint(equalTo: videoContainerView.leadingAnchor),
            playerViewController.view.trailingAnchor.constraint(equalTo: videoContainerView.trailingAnchor),
            playerViewController.view.bottomAnchor.constraint(equalTo: videoContainerView.bottomAnchor),

            topGradientView.topAnchor.constraint(equalTo: view.topAnchor),
            topGradientView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topGradientView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topGradientView.bottomAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: 56),

            bottomGradientView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomGradientView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomGradientView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomGradientView.topAnchor.constraint(lessThanOrEqualTo: buttonsStackView.topAnchor, constant: -56),
            bottomGradientView.topAnchor.constraint(lessThanOrEqualTo: leadingStackView.topAnchor, constant: -56),

            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: AppTheme.Spacing.s),
            closeButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: margin),

            authorStackView.leadingAnchor.constraint(equalTo: closeButton.trailingAnchor, constant: AppTheme.Spacing.m),
            authorStackView.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
            authorStackView.trailingAnchor.constraint(lessThanOrEqualTo: moreButton.leadingAnchor, constant: -AppTheme.Spacing.m),

            moreButton.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
            moreButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -margin),

            buttonsStackView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -margin),
            buttonsStackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -margin),

            leadingStackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: margin + 4),
            leadingStackView.bottomAnchor.constraint(equalTo: buttonsStackView.bottomAnchor),
            leadingStackView.trailingAnchor.constraint(lessThanOrEqualTo: buttonsStackView.leadingAnchor, constant: -margin),

            reactionSummaryLabel.topAnchor.constraint(equalTo: reactionSummaryPill.contentView.topAnchor, constant: 7),
            reactionSummaryLabel.bottomAnchor.constraint(equalTo: reactionSummaryPill.contentView.bottomAnchor, constant: -7),
            reactionSummaryLabel.leadingAnchor.constraint(equalTo: reactionSummaryPill.contentView.leadingAnchor, constant: 12),
            reactionSummaryLabel.trailingAnchor.constraint(equalTo: reactionSummaryPill.contentView.trailingAnchor, constant: -12),

            playbackIconContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            playbackIconContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            playbackIconContainer.widthAnchor.constraint(equalToConstant: 72),
            playbackIconContainer.heightAnchor.constraint(equalToConstant: 72),
            playbackIconView.centerXAnchor.constraint(equalTo: playbackIconContainer.contentView.centerXAnchor),
            playbackIconView.centerYAnchor.constraint(equalTo: playbackIconContainer.contentView.centerYAnchor),

            loadingContainerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingContainerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            loadingContainerView.widthAnchor.constraint(greaterThanOrEqualToConstant: 132),
            loadingContainerView.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -64),

            loadingStackView.topAnchor.constraint(equalTo: loadingContainerView.contentView.topAnchor, constant: 22),
            loadingStackView.bottomAnchor.constraint(equalTo: loadingContainerView.contentView.bottomAnchor, constant: -22),
            loadingStackView.leadingAnchor.constraint(equalTo: loadingContainerView.contentView.leadingAnchor, constant: 20),
            loadingStackView.trailingAnchor.constraint(equalTo: loadingContainerView.contentView.trailingAnchor, constant: -20)
        ])

        let preferredBottomGradientHeight = bottomGradientView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.36)
        preferredBottomGradientHeight.priority = .defaultLow
        preferredBottomGradientHeight.isActive = true
    }

    private func observePlayerStatus() {
        guard let item = player.currentItem else {
            loadingLabel.text = "영상을 불러오지 못했어요"
            loadingIndicatorView.stopAnimating()
            return
        }

        playerStatusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                guard self?.isDeleting != true else { return }
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

    @objc private func videoTapped() {
        togglePlayback()
    }

    private func togglePlayback() {
        if player.timeControlStatus == .paused {
            isPausedByUser = false
            player.play()
            flashPlaybackIcon(systemName: "play.fill")
        } else {
            isPausedByUser = true
            player.pause()
            flashPlaybackIcon(systemName: "pause.fill")
        }
        Haptics.selection()
    }

    private func flashPlaybackIcon(systemName: String) {
        playbackIconView.image = UIImage(systemName: systemName)
        playbackIconContainer.layer.removeAllAnimations()
        playbackIconContainer.alpha = 0
        playbackIconContainer.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)

        UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseOut, .beginFromCurrentState]) {
            self.playbackIconContainer.alpha = 1
            self.playbackIconContainer.transform = .identity
        } completion: { _ in
            UIView.animate(withDuration: 0.3, delay: 0.45, options: [.curveEaseIn, .beginFromCurrentState]) {
                self.playbackIconContainer.alpha = 0
                self.playbackIconContainer.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            }
        }
    }

    @objc private func reactionTapped() {
        presentReactionPicker(currentEmoji: myReaction()?.emoji, from: reactionButton) { [weak self] emoji in
            Haptics.selection()
            self?.toggleReaction(emoji: emoji)
        }
    }

    private func updateSoundButton() {
        soundButton.setSymbol(
            isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
            tintColor: isMuted ? AppTheme.secondaryText : .white
        )
        soundButton.accessibilityLabel = isMuted ? "소리 켜기" : "소리 끄기"
    }

    private func fetchReactions() {
        reactionRepository.fetchReactions(postIDs: [post.id]) { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let reactionsByPostID):
                self.reactions = reactionsByPostID[self.post.id] ?? []
                self.updateReactionButton()
            case .failure(let error):
                ToastView.show(message: "반응을 불러오지 못했어요: \(error.localizedDescription)", style: .error, in: self.view)
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
                Haptics.success()
                self.fetchReactions()
            case .failure(let error):
                ToastView.show(message: "반응 저장 실패: \(error.localizedDescription)", style: .error, in: self.view)
            }
        }
    }

    private func myReaction() -> PostReaction? {
        reactions.reaction(by: AuthService.shared.currentUserID)
    }

    private func updateReactionButton() {
        let emoji = myReaction()?.emoji
        if let emoji {
            reactionButton.setSymbol("heart.fill", tintColor: AppTheme.neonPink)
            reactionButton.accessibilityLabel = "내 반응 \(emoji), 변경"
        } else {
            reactionButton.setSymbol("heart", tintColor: .white)
            reactionButton.accessibilityLabel = "반응 남기기"
        }

        let summary = reactionSummaryText()
        reactionSummaryLabel.text = summary
        reactionSummaryPill.accessibilityLabel = summary.isEmpty ? nil : "반응 \(summary)"
        reactionSummaryPill.isAccessibilityElement = !summary.isEmpty
        reactionSummaryPill.isHidden = summary.isEmpty
    }

    private func reactionSummaryText() -> String {
        ReactionFormatter.summaryText(for: reactions, maxEmojiCount: 3)
    }

    @objc private func closeTapped() {
        guard !isDeleting else { return }
        navigationController?.popViewController(animated: true)
    }

    // MARK: - Comments

    private func setupCommentBadge() {
        commentBadgeLabel.font = UIFont.systemFont(ofSize: 11, weight: .bold).rounded
        commentBadgeLabel.textColor = .black
        commentBadgeLabel.backgroundColor = AppTheme.neonPink
        commentBadgeLabel.textAlignment = .center
        commentBadgeLabel.layer.cornerRadius = 9
        commentBadgeLabel.layer.cornerCurve = .continuous
        commentBadgeLabel.clipsToBounds = true
        commentBadgeLabel.isUserInteractionEnabled = false
        commentBadgeLabel.isAccessibilityElement = false
        commentBadgeLabel.isHidden = true
        commentBadgeLabel.translatesAutoresizingMaskIntoConstraints = false
        commentButton.addSubview(commentBadgeLabel)

        NSLayoutConstraint.activate([
            commentBadgeLabel.heightAnchor.constraint(equalToConstant: 18),
            commentBadgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 18),
            commentBadgeLabel.centerXAnchor.constraint(equalTo: commentButton.trailingAnchor, constant: -6),
            commentBadgeLabel.centerYAnchor.constraint(equalTo: commentButton.topAnchor, constant: 6)
        ])
    }

    private func setupCommentPreviewButton() {
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0)
        configuration.titleLineBreakMode = .byTruncatingTail
        configuration.titleAlignment = .leading
        commentPreviewButton.configuration = configuration
        commentPreviewButton.contentHorizontalAlignment = .leading
        commentPreviewButton.isHidden = true
        commentPreviewButton.addTarget(self, action: #selector(commentsTapped), for: .touchUpInside)
    }

    private func listenComments() {
        commentsListener = commentRepository.listenComments(postID: post.id) { [weak self] result in
            guard let self, !self.isDeleting else { return }

            switch result {
            case .success(let comments):
                self.comments = comments
                self.updateCommentViews()
            case .failure(let error):
                // Non-blocking: the sheet surfaces errors when the user opens it.
                print("[VideoDetail] Failed to listen comments: \(error)")
            }
        }
    }

    private func updateCommentViews() {
        let count = comments.count
        commentBadgeLabel.text = count > 99 ? "99+" : "\(count)"
        commentBadgeLabel.isHidden = count == 0
        commentButton.accessibilityLabel = count == 0 ? "댓글 남기기" : "댓글 \(count)개 보기"

        guard count > 0 else {
            commentPreviewButton.isHidden = true
            return
        }

        let preview = NSMutableAttributedString(
            string: "댓글 \(count)",
            attributes: [
                .font: AppTheme.roundedFont(.subheadline, weight: .bold),
                .foregroundColor: UIColor.white
            ]
        )
        if let latest = comments.last {
            let snippet = latest.text.replacingOccurrences(of: "\n", with: " ")
            preview.append(NSAttributedString(
                string: "  \(latest.authorName) \(snippet)",
                attributes: [
                    .font: AppTheme.roundedFont(.subheadline, weight: .medium),
                    .foregroundColor: UIColor.white.withAlphaComponent(0.75)
                ]
            ))
        }
        commentPreviewButton.configuration?.attributedTitle = AttributedString(preview)
        commentPreviewButton.accessibilityLabel = "댓글 \(count)개 보기"
        commentPreviewButton.isHidden = false
    }

    @objc private func commentsTapped() {
        guard !isDeleting, presentedViewController == nil else { return }
        let commentsViewController = CommentsViewController(post: post, initialComments: comments)
        present(commentsViewController, animated: true)
    }

    // MARK: - Own post management

    @objc private func moreTapped() {
        guard isOwnPost, !isDeleting else { return }

        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        // Retaking only makes sense for the current hour; an older slot can't be refilled.
        if post.hourKey == HourSlot.currentKey() {
            actionSheet.addAction(UIAlertAction(title: "다시 찍기", style: .default) { [weak self] _ in
                self?.confirmRetake()
            })
        }
        actionSheet.addAction(UIAlertAction(title: "삭제", style: .destructive) { [weak self] _ in
            self?.confirmDelete()
        })
        actionSheet.addAction(UIAlertAction(title: "취소", style: .cancel))
        presentActionSheet(actionSheet, from: moreButton)
    }

    private func confirmRetake() {
        let alert = UIAlertController(
            title: "다시 찍을까요?",
            message: "지금 게시물과 반응, 댓글이 삭제되고 카메라가 열려요.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        alert.addAction(UIAlertAction(title: "다시 찍기", style: .destructive) { [weak self] _ in
            self?.deletePost { viewController in
                AppRouter.showCamera(from: viewController)
            }
        })
        present(alert, animated: true)
    }

    private func confirmDelete() {
        let alert = UIAlertController(
            title: "게시물을 삭제할까요?",
            message: "삭제한 영상과 반응, 댓글은 되돌릴 수 없어요.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        alert.addAction(UIAlertAction(title: "삭제", style: .destructive) { [weak self] _ in
            self?.deletePost { viewController in
                viewController.popAfterDeletion()
            }
        })
        present(alert, animated: true)
    }

    private func deletePost(onSuccess: @escaping (VideoDetailViewController) -> Void) {
        guard !isDeleting else { return }
        setDeleting(true)

        postRepository.deletePost(post) { [weak self] result in
            guard let self else { return }

            switch result {
            case .success:
                self.commentsListener?.remove()
                self.commentsListener = nil
                self.player.pause()
                onSuccess(self)
            case .failure(let error):
                self.setDeleting(false)
                ToastView.show(message: "삭제하지 못했어요: \(error.localizedDescription)", style: .error, in: self.view)
            }
        }
    }

    private func setDeleting(_ deleting: Bool) {
        isDeleting = deleting
        view.isUserInteractionEnabled = !deleting
        navigationController?.interactivePopGestureRecognizer?.isEnabled = !deleting

        if deleting {
            loadingLabel.text = "삭제하는 중"
            loadingIndicatorView.startAnimating()
            loadingContainerView.isHidden = false
        } else {
            let isReady = player.currentItem?.status == .readyToPlay
            loadingContainerView.isHidden = isReady
            if isReady {
                loadingIndicatorView.stopAnimating()
            } else {
                loadingLabel.text = "영상 로딩 중"
            }
        }
    }

    private func popAfterDeletion() {
        guard let navigationController else { return }
        navigationController.interactivePopGestureRecognizer?.isEnabled = true

        let previousViewController = navigationController.viewControllers.dropLast().last
        navigationController.popViewController(animated: true)
        if let previousView = previousViewController?.view {
            ToastView.show(message: "삭제했어요", style: .success, in: previousView)
        }
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
