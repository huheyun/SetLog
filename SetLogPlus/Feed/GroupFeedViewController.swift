import UIKit

final class GroupFeedViewController: UIViewController {
    private let group: Group
    private let groupRepository = GroupRepository()
    private let postRepository = PostRepository()
    private let reactionRepository = ReactionRepository()
    private var members: [GroupMember] = []
    private var posts: [Post] = []
    private var allPosts: [Post] = []
    private var reactionsByPostID: [String: [PostReaction]] = [:]
    private var availableHourKeys: [String] = []
    private var selectedHourKey: String?
    private let scrollView = FeedScrollView()
    private let contentStackView = UIStackView()
    private let hourScrollView = UIScrollView()
    private let hourIndicatorStackView = UIStackView()
    private let hourStatusLabel = UILabel()
    private let headerSubtitleLabel = UILabel()
    private let modeControl = BottomModeControl(selectedIndex: 1)
    private var didLoadInitialFeed = false
    /// True once the feed has rendered real content, so refreshes don't flash the loading card.
    private var hasRenderedFeed = false

    private static let createdAtFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private var previewViewsByPostID: [String: VideoPreviewView] = [:]

    init(group: Group) {
        self.group = group
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = group.name
        view.backgroundColor = AppTheme.background
        AppTheme.applyDarkNavigation(to: navigationController)
        setupHeader()
        setupLayout()
        setupTimeNavigation()
        fetchFeedData()
        didLoadInitialFeed = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard didLoadInitialFeed else { return }
        fetchFeedData()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Let cards scroll underneath the floating mode control.
        let overlap = view.bounds.height - view.safeAreaInsets.bottom - modeControl.frame.minY
        let bottomInset = max(0, overlap) + AppTheme.Spacing.l
        if scrollView.contentInset.bottom != bottomInset {
            scrollView.contentInset.bottom = bottomInset
            scrollView.verticalScrollIndicatorInsets.bottom = bottomInset
        }
    }

    // MARK: - Layout

    private func setupHeader() {
        let titleLabel = UILabel()
        titleLabel.text = group.name
        titleLabel.font = AppTheme.roundedFont(.headline, weight: .bold)
        titleLabel.textColor = AppTheme.text
        titleLabel.textAlignment = .center
        titleLabel.lineBreakMode = .byTruncatingTail

        headerSubtitleLabel.font = AppTheme.roundedFont(.caption1, weight: .medium)
        headerSubtitleLabel.textColor = AppTheme.secondaryText
        headerSubtitleLabel.textAlignment = .center
        updateHeaderSubtitle(memberCount: group.memberIDs.count)

        let titleStackView = UIStackView(arrangedSubviews: [titleLabel, headerSubtitleLabel])
        titleStackView.axis = .vertical
        titleStackView.alignment = .center
        titleStackView.spacing = 1
        titleStackView.isAccessibilityElement = true
        titleStackView.accessibilityTraits = .header
        navigationItem.titleView = titleStackView

        let settingsButton = UIBarButtonItem(
            image: UIImage(systemName: "gearshape"),
            style: .plain,
            target: self,
            action: #selector(openSettings)
        )
        settingsButton.accessibilityLabel = "그룹 설정"
        navigationItem.rightBarButtonItem = settingsButton
    }

    private func updateHeaderSubtitle(memberCount: Int) {
        headerSubtitleLabel.text = "멤버 \(memberCount)명"
        navigationItem.titleView?.accessibilityLabel = "\(group.name), 멤버 \(memberCount)명"
    }

    private func setupLayout() {
        hourScrollView.showsHorizontalScrollIndicator = false
        hourScrollView.alwaysBounceHorizontal = true
        hourScrollView.translatesAutoresizingMaskIntoConstraints = false

        hourIndicatorStackView.axis = .horizontal
        hourIndicatorStackView.alignment = .center
        hourIndicatorStackView.spacing = AppTheme.Spacing.s
        hourIndicatorStackView.translatesAutoresizingMaskIntoConstraints = false
        hourScrollView.addSubview(hourIndicatorStackView)
        renderHourIndicators()

        hourStatusLabel.font = AppTheme.roundedFont(.footnote, weight: .semibold)
        hourStatusLabel.adjustsFontForContentSizeCategory = true
        hourStatusLabel.textColor = AppTheme.secondaryText
        hourStatusLabel.textAlignment = .center
        hourStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        updateHourStatusLabel()

        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let refreshControl = UIRefreshControl()
        refreshControl.tintColor = AppTheme.secondaryText
        refreshControl.addTarget(self, action: #selector(refreshPulled), for: .valueChanged)
        scrollView.refreshControl = refreshControl

        contentStackView.axis = .vertical
        contentStackView.spacing = AppTheme.Spacing.m
        contentStackView.translatesAutoresizingMaskIntoConstraints = false

        modeControl.onCameraTapped = { [weak self] in
            guard let self else { return }
            AppRouter.showCamera(from: self)
        }
        modeControl.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        view.addSubview(modeControl)
        view.addSubview(hourScrollView)
        view.addSubview(hourStatusLabel)
        scrollView.addSubview(contentStackView)

        let horizontalMargin = AppTheme.Spacing.l

        NSLayoutConstraint.activate([
            hourScrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: AppTheme.Spacing.s),
            hourScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hourScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hourScrollView.heightAnchor.constraint(equalToConstant: 40),

            hourIndicatorStackView.topAnchor.constraint(equalTo: hourScrollView.contentLayoutGuide.topAnchor),
            hourIndicatorStackView.bottomAnchor.constraint(equalTo: hourScrollView.contentLayoutGuide.bottomAnchor),
            hourIndicatorStackView.leadingAnchor.constraint(equalTo: hourScrollView.contentLayoutGuide.leadingAnchor, constant: horizontalMargin),
            hourIndicatorStackView.trailingAnchor.constraint(equalTo: hourScrollView.contentLayoutGuide.trailingAnchor, constant: -horizontalMargin),
            hourIndicatorStackView.heightAnchor.constraint(equalTo: hourScrollView.frameLayoutGuide.heightAnchor),

            hourStatusLabel.topAnchor.constraint(equalTo: hourScrollView.bottomAnchor, constant: AppTheme.Spacing.s),
            hourStatusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: horizontalMargin),
            hourStatusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -horizontalMargin),

            scrollView.topAnchor.constraint(equalTo: hourStatusLabel.bottomAnchor, constant: AppTheme.Spacing.m),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: horizontalMargin),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -horizontalMargin),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentStackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -horizontalMargin * 2),

            modeControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            modeControl.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12)
        ])
    }

    private func setupTimeNavigation() {
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(screenTapped(_:)))
        tapRecognizer.cancelsTouchesInView = false
        tapRecognizer.delegate = self
        view.addGestureRecognizer(tapRecognizer)
    }

    // MARK: - Data

    private func fetchFeedData() {
        renderLoadingState()

        groupRepository.fetchMembers(groupID: group.id) { [weak self] memberResult in
            guard let self else { return }

            self.postRepository.fetchPosts(groupID: self.group.id) { postResult in
                DispatchQueue.main.async {
                    switch (memberResult, postResult) {
                    case (.success(let members), .success(let allPosts)):
                        self.members = members.sortedForDisplay()
                        self.allPosts = allPosts
                        allPosts.compactMap { URL(string: $0.videoURL) }.forEach(VideoCache.shared.prefetch)
                        self.updateHeaderSubtitle(memberCount: self.members.count)
                        self.updateAvailableHours()
                        self.updateSelectedPosts()
                        self.renderHourIndicators()
                        self.updateHourStatusLabel()
                        self.fetchReactionsAndRender()
                    case (.failure(let error), _), (_, .failure(let error)):
                        self.endRefreshing()
                        self.renderError(message: error.localizedDescription)
                    }
                }
            }
        }
    }

    /// Reuses the preview for a post across re-renders so playback doesn't restart/reload
    /// when the feed refreshes or the user switches hours and comes back.
    private func reusablePreviewView(postID: String, url: URL) -> VideoPreviewView {
        if let existing = previewViewsByPostID[postID] {
            existing.removeFromSuperview()
            return existing
        }
        let previewView = VideoPreviewView(url: url, isMuted: true)
        previewViewsByPostID[postID] = previewView
        return previewView
    }

    private func renderLoadingState() {
        // Keep the current cards on screen during background refreshes (e.g. returning from detail).
        guard !hasRenderedFeed else { return }

        contentStackView.replaceArrangedSubviews(with: [
            InfoCardView(
                title: "피드를 불러오는 중이에요",
                message: group.name,
                isLoading: true
            )
        ])
    }

    private func fetchReactionsAndRender() {
        reactionRepository.fetchReactions(postIDs: allPosts.map(\.id)) { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let reactionsByPostID):
                self.reactionsByPostID = reactionsByPostID
            case .failure(let error):
                ToastView.show(message: "반응을 불러오지 못했어요: \(error.localizedDescription)", style: .error, in: self.view)
            }

            self.endRefreshing()
            self.renderMemberAreas()
        }
    }

    private func renderMemberAreas() {
        guard !members.isEmpty else {
            renderMessage(title: "멤버가 없어요", message: "그룹 멤버 정보를 찾을 수 없습니다.", systemImageName: "person.2")
            return
        }

        guard selectedHourKey != nil else {
            renderMessage(
                title: "오늘 올라온 로그가 없어요",
                message: "카메라로 첫 로그를 올리면 이곳에 표시됩니다.",
                systemImageName: "video.badge.plus",
                actionTitle: "첫 로그 올리기"
            ) { [weak self] in
                guard let self else { return }
                AppRouter.showCamera(from: self)
            }
            return
        }

        hasRenderedFeed = true
        // `posts` is sorted newest first, so each member shows their latest log for the hour.
        contentStackView.replaceArrangedSubviews(with: members.map { member in
            makeMemberArea(member: member, post: posts.first { $0.authorID == member.uid })
        })
    }

    private func selectedHourDate() -> Date {
        guard let selectedHourKey,
              let date = HourSlot.date(fromKey: selectedHourKey) else {
            return Date()
        }

        return date
    }

    private func updateAvailableHours() {
        let currentHourKey = HourSlot.currentKey()
        availableHourKeys = Array(
            Set(
                allPosts
                    .map(\.hourKey)
                    .filter { HourSlot.isTodayKey($0) && $0 <= currentHourKey }
            )
        )
        .sorted()

        if let selectedHourKey,
           availableHourKeys.contains(selectedHourKey) {
            return
        }

        selectedHourKey = availableHourKeys.last
    }

    private func updateSelectedPosts() {
        guard let selectedHourKey else {
            posts = []
            return
        }

        posts = allPosts.filter { $0.hourKey == selectedHourKey }
    }

    // MARK: - Hour chips

    private func renderHourIndicators() {
        hourIndicatorStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        hourScrollView.isHidden = availableHourKeys.isEmpty

        let currentHourKey = HourSlot.currentKey()
        for (index, hourKey) in availableHourKeys.enumerated() {
            let chip = makeHourChip(
                hourKey: hourKey,
                isSelected: hourKey == selectedHourKey,
                isCurrentHour: hourKey == currentHourKey
            )
            chip.tag = index
            hourIndicatorStackView.addArrangedSubview(chip)
        }

        scrollToSelectedHourChip(animated: false)
    }

    private func makeHourChip(hourKey: String, isSelected: Bool, isCurrentHour: Bool) -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.title = HourSlot.displayText(hourKey: hourKey)
        configuration.cornerStyle = .capsule
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 14, bottom: 7, trailing: 14)
        configuration.baseBackgroundColor = isSelected ? AppTheme.neonPink : AppTheme.cardMuted
        configuration.baseForegroundColor = isSelected ? .white : AppTheme.secondaryText
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: isSelected ? .bold : .semibold).rounded
            return attributes
        }

        if isCurrentHour {
            // Small dot marks "now".
            configuration.image = UIImage(systemName: "circle.fill")
            configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 6, weight: .bold)
            configuration.imagePadding = 6
            configuration.imageColorTransformer = UIConfigurationColorTransformer { _ in
                isSelected ? .white : AppTheme.success
            }
        }

        let chip = UIButton(configuration: configuration)
        chip.enablePressAnimation()
        chip.addTarget(self, action: #selector(hourChipTapped(_:)), for: .touchUpInside)
        chip.accessibilityLabel = HourSlot.displayText(hourKey: hourKey) + (isCurrentHour ? ", 지금" : "")
        chip.accessibilityTraits = isSelected ? [.button, .selected] : .button
        chip.setContentCompressionResistancePriority(.required, for: .horizontal)
        return chip
    }

    private func scrollToSelectedHourChip(animated: Bool) {
        guard let selectedHourKey,
              let index = availableHourKeys.firstIndex(of: selectedHourKey),
              index < hourIndicatorStackView.arrangedSubviews.count else {
            return
        }

        hourScrollView.layoutIfNeeded()
        let chip = hourIndicatorStackView.arrangedSubviews[index]
        let chipFrame = hourIndicatorStackView.convert(chip.frame, to: hourScrollView)
        let maxOffsetX = max(0, hourScrollView.contentSize.width - hourScrollView.bounds.width)
        let targetX = min(max(0, chipFrame.midX - hourScrollView.bounds.width / 2), maxOffsetX)
        hourScrollView.setContentOffset(CGPoint(x: targetX, y: 0), animated: animated)
    }

    private func selectHour(at index: Int) {
        guard availableHourKeys.indices.contains(index),
              availableHourKeys[index] != selectedHourKey else {
            return
        }

        Haptics.selection()
        selectedHourKey = availableHourKeys[index]
        updateSelectedPosts()
        renderHourIndicators()
        updateHourStatusLabel()
        UIView.transition(with: contentStackView, duration: 0.2, options: [.transitionCrossDissolve, .allowUserInteraction]) {
            self.renderMemberAreas()
        }
        scrollView.setContentOffset(CGPoint(x: 0, y: -scrollView.adjustedContentInset.top), animated: false)
    }

    // MARK: - States

    private func renderMessage(
        title: String,
        message: String,
        systemImageName: String = "play.rectangle",
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        contentStackView.replaceArrangedSubviews(with: [
            InfoCardView(
                title: title,
                message: message,
                systemImageName: systemImageName,
                actionTitle: actionTitle,
                action: action
            )
        ])
    }

    private func renderError(message: String) {
        hasRenderedFeed = false
        renderMessage(
            title: "피드를 불러오지 못했어요",
            message: message,
            systemImageName: "wifi.exclamationmark",
            actionTitle: "다시 시도"
        ) { [weak self] in
            self?.fetchFeedData()
        }
    }

    private func endRefreshing() {
        if scrollView.refreshControl?.isRefreshing == true {
            scrollView.refreshControl?.endRefreshing()
        }
    }

    // MARK: - Member cards

    private func makeMemberArea(member: GroupMember, post: Post?) -> UIView {
        if let post, let url = URL(string: post.videoURL) {
            return makePostCard(member: member, post: post, url: url)
        }
        return makeEmptyCard(member: member)
    }

    private func makePostCard(member: GroupMember, post: Post, url: URL) -> UIView {
        let card = PressableControl()
        card.pressedScale = 0.98
        card.backgroundColor = AppTheme.cardMuted
        card.layer.cornerRadius = AppTheme.Radius.large
        card.layer.cornerCurve = .continuous
        card.clipsToBounds = true
        card.accessibilityIdentifier = post.id
        card.addTarget(self, action: #selector(postCardTapped(_:)), for: .touchUpInside)

        let previewView = reusablePreviewView(postID: post.id, url: url)
        previewView.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(previewView)

        let gradientView = VideoGradientView(direction: .bottomUp, maxAlpha: 0.78)
        card.addSubview(gradientView)

        let timeText = post.createdAt.map { Self.createdAtFormatter.string(from: $0) }
            ?? HourSlot.displayText(date: selectedHourDate())
        let identityView = makeIdentityView(member: member, subtitle: timeText, onDarkMedia: true)
        card.addSubview(identityView)

        let reactionButton = makeReactionButton(for: post)

        let trailingStackView = UIStackView()
        trailingStackView.axis = .horizontal
        trailingStackView.alignment = .center
        trailingStackView.spacing = AppTheme.Spacing.s
        trailingStackView.translatesAutoresizingMaskIntoConstraints = false
        if let pill = makeReactionSummaryPill(for: post) {
            trailingStackView.addArrangedSubview(pill)
        }
        trailingStackView.addArrangedSubview(reactionButton)
        card.addSubview(trailingStackView)

        let inset = AppTheme.Spacing.m + 2

        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 168),

            previewView.topAnchor.constraint(equalTo: card.topAnchor),
            previewView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            previewView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            previewView.bottomAnchor.constraint(equalTo: card.bottomAnchor),

            gradientView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            gradientView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            gradientView.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            gradientView.heightAnchor.constraint(equalTo: card.heightAnchor, multiplier: 0.62),

            identityView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: inset),
            identityView.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -inset),
            identityView.trailingAnchor.constraint(lessThanOrEqualTo: trailingStackView.leadingAnchor, constant: -AppTheme.Spacing.s),

            trailingStackView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -AppTheme.Spacing.m),
            trailingStackView.centerYAnchor.constraint(equalTo: identityView.centerYAnchor)
        ])

        let reactionSummary = reactionSummaryText(for: post)
        card.isAccessibilityElement = true
        card.accessibilityTraits = .button
        card.accessibilityLabel = "\(member.displayName), \(timeText) 로그"
            + (reactionSummary.isEmpty ? "" : ", 반응 \(reactionSummary)")
        card.accessibilityHint = "영상을 크게 봅니다"
        card.accessibilityCustomActions = [
            UIAccessibilityCustomAction(name: "반응 남기기") { [weak self, weak reactionButton] _ in
                guard let reactionButton else { return false }
                self?.reactionButtonTapped(reactionButton)
                return true
            }
        ]

        return card
    }

    private func makeEmptyCard(member: GroupMember) -> UIView {
        let card = DashedBorderView()
        card.backgroundColor = AppTheme.card
        card.layer.cornerRadius = AppTheme.Radius.large
        card.layer.cornerCurve = .continuous

        let identityView = makeIdentityView(member: member, subtitle: nil, onDarkMedia: false)
        identityView.alpha = 0.7
        card.addSubview(identityView)

        let isOwnCurrentSlot = member.uid == AuthService.shared.currentUserID
            && selectedHourKey == HourSlot.currentKey()

        let centerView: UIView
        if isOwnCurrentSlot {
            centerView = makeUploadCTAButton()
        } else {
            let iconView = UIImageView(image: UIImage(systemName: "video.slash"))
            iconView.tintColor = AppTheme.tertiaryText
            iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
            iconView.setContentHuggingPriority(.required, for: .horizontal)

            let label = UILabel()
            label.text = "아직 안 올렸어요"
            label.font = AppTheme.roundedFont(.subheadline, weight: .semibold)
            label.adjustsFontForContentSizeCategory = true
            label.textColor = AppTheme.tertiaryText

            let stackView = UIStackView(arrangedSubviews: [iconView, label])
            stackView.axis = .horizontal
            stackView.alignment = .center
            stackView.spacing = 6
            centerView = stackView
        }
        centerView.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(centerView)

        let inset = AppTheme.Spacing.m + 2

        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(greaterThanOrEqualToConstant: 112),

            identityView.topAnchor.constraint(equalTo: card.topAnchor, constant: inset),
            identityView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: inset),
            identityView.trailingAnchor.constraint(lessThanOrEqualTo: card.trailingAnchor, constant: -inset),

            centerView.topAnchor.constraint(greaterThanOrEqualTo: identityView.bottomAnchor, constant: AppTheme.Spacing.m),
            centerView.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            centerView.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -AppTheme.Spacing.l),
            centerView.leadingAnchor.constraint(greaterThanOrEqualTo: card.leadingAnchor, constant: inset),
            centerView.trailingAnchor.constraint(lessThanOrEqualTo: card.trailingAnchor, constant: -inset)
        ])

        if !isOwnCurrentSlot {
            card.isAccessibilityElement = true
            card.accessibilityLabel = "\(member.displayName), 아직 안 올렸어요"
        }

        return card
    }

    private func makeIdentityView(member: GroupMember, subtitle: String?, onDarkMedia: Bool) -> UIView {
        let avatarLabel = AppTheme.makeAvatarLabel(
            text: String(member.displayName.prefix(1)),
            size: 32,
            fontSize: 14,
            color: AppTheme.avatarColor(for: member.uid)
        )
        if onDarkMedia {
            avatarLabel.layer.borderWidth = 1.5
            avatarLabel.layer.borderColor = UIColor.white.withAlphaComponent(0.85).cgColor
        }

        let nameLabel = UILabel()
        nameLabel.text = member.displayName
        nameLabel.font = AppTheme.roundedFont(.subheadline, weight: .bold)
        nameLabel.adjustsFontForContentSizeCategory = true
        nameLabel.textColor = AppTheme.text
        nameLabel.lineBreakMode = .byTruncatingTail

        var nameView: UIView = nameLabel
        if member.isOwner {
            let crownView = UIImageView(image: UIImage(systemName: "crown.fill"))
            crownView.tintColor = AppTheme.butter
            crownView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 10, weight: .bold)
            crownView.setContentHuggingPriority(.required, for: .horizontal)
            crownView.setContentCompressionResistancePriority(.required, for: .horizontal)
            crownView.isAccessibilityElement = false

            let nameRow = UIStackView(arrangedSubviews: [nameLabel, crownView])
            nameRow.axis = .horizontal
            nameRow.alignment = .center
            nameRow.spacing = 4
            nameView = nameRow
        }

        let textStackView = UIStackView(arrangedSubviews: [nameView])
        textStackView.axis = .vertical
        textStackView.spacing = 1

        if let subtitle {
            let subtitleLabel = UILabel()
            subtitleLabel.text = subtitle
            subtitleLabel.font = UIFont.monospacedDigitSystemFont(
                ofSize: UIFont.preferredFont(forTextStyle: .caption1).pointSize,
                weight: .semibold
            ).rounded
            subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.78)
            textStackView.addArrangedSubview(subtitleLabel)
        }

        let stackView = UIStackView(arrangedSubviews: [avatarLabel, textStackView])
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = AppTheme.Spacing.s + 2
        stackView.isUserInteractionEnabled = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }

    private func makeReactionButton(for post: Post) -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.cornerStyle = .capsule
        configuration.baseBackgroundColor = UIColor.black.withAlphaComponent(0.38)
        configuration.contentInsets = .zero

        if let emoji = myReaction(for: post)?.emoji {
            configuration.title = emoji
            configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                var attributes = attributes
                attributes.font = .systemFont(ofSize: 19)
                return attributes
            }
            configuration.background.strokeColor = AppTheme.neonPink
            configuration.background.strokeWidth = 1.5
        } else {
            configuration.image = UIImage(systemName: "heart")
            configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
            configuration.baseForegroundColor = .white
        }

        let button = UIButton(configuration: configuration)
        button.enablePressAnimation()
        button.accessibilityIdentifier = post.id
        button.accessibilityLabel = myReaction(for: post).map { "내 반응 \($0.emoji), 변경" } ?? "반응 남기기"
        button.addTarget(self, action: #selector(reactionButtonTapped(_:)), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 40),
            button.heightAnchor.constraint(equalToConstant: 40)
        ])
        return button
    }

    private func makeReactionSummaryPill(for post: Post) -> UIView? {
        let summary = reactionSummaryText(for: post)
        guard !summary.isEmpty else { return nil }

        let label = UILabel()
        label.text = summary
        label.font = AppTheme.roundedFont(.caption1, weight: .bold)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false

        let pill = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        pill.layer.cornerRadius = 14
        pill.layer.cornerCurve = .continuous
        pill.clipsToBounds = true
        pill.isUserInteractionEnabled = false
        pill.contentView.addSubview(label)
        pill.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        NSLayoutConstraint.activate([
            pill.heightAnchor.constraint(greaterThanOrEqualToConstant: 28),
            label.topAnchor.constraint(equalTo: pill.contentView.topAnchor, constant: 5),
            label.bottomAnchor.constraint(equalTo: pill.contentView.bottomAnchor, constant: -5),
            label.leadingAnchor.constraint(equalTo: pill.contentView.leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: pill.contentView.trailingAnchor, constant: -10)
        ])
        return pill
    }

    private func makeUploadCTAButton() -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.title = "지금 올리기"
        configuration.image = UIImage(systemName: "camera.fill")
        configuration.imagePadding = 6
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 13, weight: .bold)
        configuration.cornerStyle = .capsule
        configuration.baseBackgroundColor = AppTheme.neonPink
        configuration.baseForegroundColor = .white
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 9, leading: 16, bottom: 9, trailing: 16)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = AppTheme.roundedFont(.subheadline, weight: .bold)
            return attributes
        }

        let button = UIButton(configuration: configuration)
        button.enablePressAnimation()
        button.accessibilityHint = "이번 시간 로그를 찍으러 카메라로 이동합니다"
        button.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            Haptics.tap()
            AppRouter.showCamera(from: self)
        }, for: .touchUpInside)
        return button
    }

    // MARK: - Actions

    @objc private func openSettings() {
        navigationController?.pushViewController(GroupSettingsViewController(group: group), animated: true)
    }

    @objc private func refreshPulled() {
        Haptics.tap()
        fetchFeedData()
    }

    @objc private func hourChipTapped(_ sender: UIButton) {
        selectHour(at: sender.tag)
        scrollToSelectedHourChip(animated: true)
    }

    @objc private func screenTapped(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else { return }

        let location = recognizer.location(in: view)
        let bottomLimit = view.bounds.height - 110
        guard location.y > view.safeAreaInsets.top + 44,
              location.y < bottomLimit else {
            return
        }

        guard let selectedHourKey,
              let currentIndex = availableHourKeys.firstIndex(of: selectedHourKey) else {
            return
        }

        let nextIndex: Int
        if location.x < view.bounds.midX, currentIndex > 0 {
            nextIndex = currentIndex - 1
        } else if location.x >= view.bounds.midX, currentIndex < availableHourKeys.count - 1 {
            nextIndex = currentIndex + 1
        } else {
            return
        }

        selectHour(at: nextIndex)
        scrollToSelectedHourChip(animated: true)
    }

    @objc private func postCardTapped(_ card: PressableControl) {
        openPost(from: card)
    }

    @objc private func reactionButtonTapped(_ sender: UIButton) {
        guard let postID = sender.accessibilityIdentifier,
              let post = posts.first(where: { $0.id == postID }) else {
            return
        }

        presentReactionPicker(currentEmoji: myReaction(for: post)?.emoji, from: sender) { [weak self] emoji in
            Haptics.selection()
            self?.toggleReaction(post: post, emoji: emoji)
        }
    }

    private func openPost(from card: UIView) {
        guard let postID = card.accessibilityIdentifier,
              let post = posts.first(where: { $0.id == postID }),
              let member = members.first(where: { $0.uid == post.authorID }) else {
            return
        }

        navigationController?.pushViewController(
            VideoDetailViewController(post: post, member: member, hourDate: selectedHourDate()),
            animated: true
        )
    }
}

private extension GroupFeedViewController {
    func toggleReaction(post: Post, emoji: String) {
        reactionRepository.toggleReaction(
            postID: post.id,
            emoji: emoji,
            currentEmoji: myReaction(for: post)?.emoji
        ) { [weak self] result in
            guard let self else { return }

            switch result {
            case .success:
                Haptics.success()
                self.fetchReactionsAndRender()
            case .failure(let error):
                ToastView.show(message: "반응 저장 실패: \(error.localizedDescription)", style: .error, in: self.view)
            }
        }
    }

    func myReaction(for post: Post?) -> PostReaction? {
        guard let post else { return nil }
        return reactionsByPostID[post.id]?.reaction(by: AuthService.shared.currentUserID)
    }

    func reactionSummaryText(for post: Post?) -> String {
        guard let post,
              let reactions = reactionsByPostID[post.id],
              !reactions.isEmpty else {
            return ""
        }

        return ReactionFormatter.summaryText(for: reactions, maxEmojiCount: 2)
    }

    func updateHourStatusLabel() {
        guard let selectedHourKey else {
            hourStatusLabel.text = "오늘은 아직 조용해요"
            hourStatusLabel.textColor = AppTheme.tertiaryText
            return
        }

        let memberIDs = Set(members.map(\.uid))
        let postedCount = Set(posts.map(\.authorID)).intersection(memberIDs).count
        let progressText = members.isEmpty ? "" : " · \(postedCount)/\(members.count)명 올림"

        if selectedHourKey == HourSlot.currentKey() {
            hourStatusLabel.text = "지금 \(HourSlot.displayText(hourKey: selectedHourKey))\(progressText)"
            hourStatusLabel.textColor = AppTheme.success
        } else {
            hourStatusLabel.text = "오늘 \(HourSlot.displayText(hourKey: selectedHourKey))\(progressText)"
            hourStatusLabel.textColor = AppTheme.secondaryText
        }
    }
}

extension GroupFeedViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard gestureRecognizer is UITapGestureRecognizer else { return true }

        var touchedView = touch.view
        while let view = touchedView {
            if view is UIControl {
                return false
            }
            touchedView = view.superview
        }

        if gestureRecognizer.view === view {
            let locationInStack = touch.location(in: contentStackView)
            if contentStackView.bounds.contains(locationInStack) {
                return false
            }
        }

        return true
    }
}

/// Lets a drag that starts on a tappable card still scroll the feed.
private final class FeedScrollView: UIScrollView {
    override func touchesShouldCancel(in view: UIView) -> Bool {
        true
    }
}

/// Card with a dashed outline, used for members who haven't posted for the hour.
private final class DashedBorderView: UIView {
    private let borderLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        borderLayer.fillColor = UIColor.clear.cgColor
        borderLayer.strokeColor = UIColor.white.withAlphaComponent(0.14).cgColor
        borderLayer.lineWidth = 1.5
        borderLayer.lineDashPattern = [6, 5]
        layer.addSublayer(borderLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let inset = borderLayer.lineWidth / 2
        borderLayer.frame = bounds
        borderLayer.path = UIBezierPath(
            roundedRect: bounds.insetBy(dx: inset, dy: inset),
            cornerRadius: layer.cornerRadius - inset
        ).cgPath
    }
}
