import UIKit
import FirebaseAuth

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
    private let contentStackView = UIStackView()
    private let hourIndicatorStackView = UIStackView()
    private let hourStatusLabel = UILabel()
    private var didLoadInitialFeed = false

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
        let settingsButton = UIBarButtonItem(
            image: UIImage(systemName: "gearshape"),
            style: .plain,
            target: self,
            action: #selector(openSettings)
        )
        navigationItem.rightBarButtonItem = settingsButton
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

    private func setupLayout() {
        hourIndicatorStackView.axis = .horizontal
        hourIndicatorStackView.alignment = .center
        hourIndicatorStackView.distribution = .equalSpacing
        hourIndicatorStackView.spacing = 5
        hourIndicatorStackView.translatesAutoresizingMaskIntoConstraints = false
        renderHourIndicators()

        hourStatusLabel.font = .systemFont(ofSize: 13, weight: .bold)
        hourStatusLabel.textColor = AppTheme.secondaryText
        hourStatusLabel.textAlignment = .center
        hourStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        updateHourStatusLabel()

        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        contentStackView.axis = .vertical
        contentStackView.spacing = 12
        contentStackView.translatesAutoresizingMaskIntoConstraints = false

        let modeControl = BottomModeControl(selectedIndex: 1)
        modeControl.onCameraTapped = { [weak self] in
            guard let self else { return }
            AppRouter.showCamera(from: self)
        }
        modeControl.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        view.addSubview(modeControl)
        view.addSubview(hourIndicatorStackView)
        view.addSubview(hourStatusLabel)
        scrollView.addSubview(contentStackView)

        NSLayoutConstraint.activate([
            hourIndicatorStackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            hourIndicatorStackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            hourStatusLabel.topAnchor.constraint(equalTo: hourIndicatorStackView.bottomAnchor, constant: 8),
            hourStatusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            scrollView.topAnchor.constraint(equalTo: hourStatusLabel.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            scrollView.bottomAnchor.constraint(equalTo: modeControl.topAnchor, constant: -16),

            contentStackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentStackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

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

    private func fetchFeedData() {
        renderLoadingState()

        groupRepository.fetchMembers(groupID: group.id) { [weak self] memberResult in
            guard let self else { return }

            self.postRepository.fetchPosts(groupID: self.group.id) { postResult in
                DispatchQueue.main.async {
                    switch (memberResult, postResult) {
                    case (.success(let members), .success(let allPosts)):
                        self.members = members.sorted { first, second in
                            if first.role == second.role {
                                return first.displayName < second.displayName
                            }
                            return first.role == "owner"
                        }
                        self.allPosts = allPosts
                        self.updateAvailableHours()
                        self.updateSelectedPosts()
                        self.renderHourIndicators()
                        self.updateHourStatusLabel()
                        self.fetchReactionsAndRender()
                    case (.failure(let error), _), (_, .failure(let error)):
                        self.renderMessage(title: "피드를 불러오지 못했습니다", message: error.localizedDescription)
                    }
                }
            }
        }
    }

    private func renderLoadingState() {
        contentStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        contentStackView.addArrangedSubview(makeMessageCard(title: "피드를 불러오는 중입니다", message: group.name, systemImageName: "person.2"))
    }

    private func fetchReactionsAndRender() {
        reactionRepository.fetchReactions(postIDs: allPosts.map(\.id)) { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let reactionsByPostID):
                self.reactionsByPostID = reactionsByPostID
            case .failure(let error):
                ToastView.show(message: "반응을 불러오지 못했어요: \(error.localizedDescription)", in: self.view)
            }

            self.renderMemberAreas()
        }
    }

    private func renderMemberAreas() {
        contentStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        guard !members.isEmpty else {
            renderMessage(title: "멤버가 없습니다", message: "그룹 멤버 정보를 찾을 수 없습니다.")
            return
        }

        guard selectedHourKey != nil else {
            renderMessage(title: "오늘 올라온 로그가 없습니다", message: "카메라로 첫 로그를 올리면 이곳에 표시됩니다.")
            return
        }

        members.forEach { member in
            let memberPosts = posts.filter { $0.authorID == member.uid }
            contentStackView.addArrangedSubview(makeMemberArea(member: member, post: memberPosts.first))
        }
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

    private func renderHourIndicators() {
        hourIndicatorStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        guard !availableHourKeys.isEmpty else {
            let dotView = UIView()
            dotView.backgroundColor = UIColor.white.withAlphaComponent(0.12)
            dotView.layer.cornerRadius = 5
            dotView.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                dotView.widthAnchor.constraint(equalToConstant: 8),
                dotView.heightAnchor.constraint(equalToConstant: 8)
            ])

            hourIndicatorStackView.addArrangedSubview(dotView)
            return
        }

        for hourKey in availableHourKeys {
            let isSelected = hourKey == selectedHourKey
            let dotView = UIView()
            dotView.backgroundColor = isSelected ? .white : UIColor.white.withAlphaComponent(0.28)
            dotView.layer.cornerRadius = isSelected ? 5 : 3.5
            dotView.layer.borderWidth = isSelected ? 2 : 0
            dotView.layer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor
            dotView.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                dotView.widthAnchor.constraint(equalToConstant: isSelected ? 10 : 7),
                dotView.heightAnchor.constraint(equalToConstant: isSelected ? 10 : 7)
            ])

            hourIndicatorStackView.addArrangedSubview(dotView)
        }
    }

    private func renderMessage(title: String, message: String) {
        contentStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        contentStackView.addArrangedSubview(makeMessageCard(title: title, message: message, systemImageName: "play.rectangle"))
    }

    private func makeMemberArea(member: GroupMember, post: Post?) -> UIView {
        let card = UIView()
        card.isUserInteractionEnabled = true
        card.backgroundColor = post == nil ? UIColor(white: 0.08, alpha: 1) : UIColor(white: 0.12, alpha: 1)
        card.layer.cornerRadius = 18
        card.clipsToBounds = true

        if let post,
           let url = URL(string: post.videoURL) {
            card.accessibilityIdentifier = post.id

            let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(postTapped(_:)))
            tapRecognizer.delegate = self
            card.addGestureRecognizer(tapRecognizer)

            let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(postLongPressed(_:)))
            card.addGestureRecognizer(longPressRecognizer)
            tapRecognizer.require(toFail: longPressRecognizer)

            let previewView = VideoPreviewView(url: url, isMuted: true)
            previewView.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview(previewView)

            NSLayoutConstraint.activate([
                previewView.topAnchor.constraint(equalTo: card.topAnchor),
                previewView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
                previewView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
                previewView.bottomAnchor.constraint(equalTo: card.bottomAnchor)
            ])

            let overlayView = UIView()
            overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.18)
            overlayView.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview(overlayView)

            NSLayoutConstraint.activate([
                overlayView.topAnchor.constraint(equalTo: card.topAnchor),
                overlayView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
                overlayView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
                overlayView.bottomAnchor.constraint(equalTo: card.bottomAnchor)
            ])
        }

        let avatarLabel = UILabel()
        avatarLabel.text = String(member.displayName.prefix(1))
        avatarLabel.font = .systemFont(ofSize: 14, weight: .bold)
        avatarLabel.textColor = .white
        avatarLabel.textAlignment = .center
        avatarLabel.backgroundColor = member.role == "owner" ? AppTheme.neonPink : AppTheme.purple
        avatarLabel.layer.cornerRadius = 15
        avatarLabel.clipsToBounds = true
        avatarLabel.translatesAutoresizingMaskIntoConstraints = false

        let nameLabel = UILabel()
        nameLabel.text = member.displayName
        nameLabel.font = .preferredFont(forTextStyle: .subheadline)
        nameLabel.textColor = AppTheme.text
        nameLabel.layer.shadowColor = UIColor.black.cgColor
        nameLabel.layer.shadowOpacity = post == nil ? 0 : 0.55
        nameLabel.layer.shadowRadius = 3
        nameLabel.layer.shadowOffset = CGSize(width: 0, height: 1)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        let timeLabel = UILabel()
        timeLabel.text = HourSlot.displayText(date: selectedHourDate())
        timeLabel.font = .systemFont(ofSize: 20, weight: .black)
        timeLabel.textColor = post == nil ? UIColor.white.withAlphaComponent(0.12) : .white
        timeLabel.textAlignment = .center
        timeLabel.layer.shadowColor = UIColor.black.cgColor
        timeLabel.layer.shadowOpacity = post == nil ? 0 : 0.65
        timeLabel.layer.shadowRadius = 4
        timeLabel.layer.shadowOffset = CGSize(width: 0, height: 1)
        timeLabel.translatesAutoresizingMaskIntoConstraints = false

        let statusLabel = UILabel()
        statusLabel.text = post == nil ? "아직 로그 없음" : ""
        statusLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        statusLabel.textColor = UIColor.white.withAlphaComponent(0.24)
        statusLabel.textAlignment = .center
        statusLabel.layer.shadowColor = UIColor.black.cgColor
        statusLabel.layer.shadowOpacity = 0
        statusLabel.layer.shadowRadius = 4
        statusLabel.layer.shadowOffset = CGSize(width: 0, height: 1)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        let nameStackView = UIStackView(arrangedSubviews: [avatarLabel, nameLabel])
        nameStackView.axis = .horizontal
        nameStackView.alignment = .center
        nameStackView.spacing = 8
        nameStackView.translatesAutoresizingMaskIntoConstraints = false

        let reactionButton = UIButton(type: .system)
        reactionButton.setTitle(reactionButtonTitle(for: post), for: .normal)
        reactionButton.titleLabel?.font = .systemFont(ofSize: post == nil ? 22 : 24, weight: .bold)
        reactionButton.tintColor = UIColor.white.withAlphaComponent(post == nil ? 0.28 : 0.92)
        reactionButton.backgroundColor = UIColor.black.withAlphaComponent(post == nil ? 0.0 : 0.28)
        reactionButton.layer.cornerRadius = 22
        reactionButton.isEnabled = post != nil
        reactionButton.accessibilityIdentifier = post?.id
        reactionButton.addTarget(self, action: #selector(reactionButtonTapped(_:)), for: .touchUpInside)
        reactionButton.translatesAutoresizingMaskIntoConstraints = false

        let reactionSummaryLabel = UILabel()
        reactionSummaryLabel.text = reactionSummaryText(for: post)
        reactionSummaryLabel.font = .systemFont(ofSize: 13, weight: .bold)
        reactionSummaryLabel.textColor = .white
        reactionSummaryLabel.textAlignment = .right
        reactionSummaryLabel.layer.shadowColor = UIColor.black.cgColor
        reactionSummaryLabel.layer.shadowOpacity = 0.55
        reactionSummaryLabel.layer.shadowRadius = 3
        reactionSummaryLabel.layer.shadowOffset = CGSize(width: 0, height: 1)
        reactionSummaryLabel.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(nameStackView)
        card.addSubview(timeLabel)
        card.addSubview(statusLabel)
        card.addSubview(reactionButton)
        card.addSubview(reactionSummaryLabel)

        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 142),

            avatarLabel.widthAnchor.constraint(equalToConstant: 30),
            avatarLabel.heightAnchor.constraint(equalToConstant: 30),

            nameStackView.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            nameStackView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            nameStackView.trailingAnchor.constraint(lessThanOrEqualTo: reactionButton.leadingAnchor, constant: -12),

            timeLabel.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            timeLabel.centerYAnchor.constraint(equalTo: card.centerYAnchor, constant: -6),

            statusLabel.topAnchor.constraint(equalTo: timeLabel.bottomAnchor, constant: 4),
            statusLabel.centerXAnchor.constraint(equalTo: card.centerXAnchor),

            reactionButton.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            reactionButton.centerYAnchor.constraint(equalTo: card.centerYAnchor, constant: -10),
            reactionButton.widthAnchor.constraint(equalToConstant: 44),
            reactionButton.heightAnchor.constraint(equalToConstant: 44),

            reactionSummaryLabel.topAnchor.constraint(equalTo: reactionButton.bottomAnchor, constant: 6),
            reactionSummaryLabel.trailingAnchor.constraint(equalTo: reactionButton.trailingAnchor),
            reactionSummaryLabel.leadingAnchor.constraint(greaterThanOrEqualTo: card.leadingAnchor, constant: 16)
        ])

        return card
    }

    private func makeMessageCard(title: String, message: String, systemImageName: String) -> UIView {
        let card = UIView()
        AppTheme.roundCard(card, radius: 18)

        let iconImageView = UIImageView(image: UIImage(systemName: systemImageName))
        iconImageView.tintColor = AppTheme.mint
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.textColor = AppTheme.text
        titleLabel.textAlignment = .center

        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.font = .preferredFont(forTextStyle: .subheadline)
        messageLabel.textColor = AppTheme.secondaryText
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        let stackView = UIStackView(arrangedSubviews: [iconImageView, titleLabel, messageLabel])
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(stackView)

        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(greaterThanOrEqualToConstant: 220),
            iconImageView.widthAnchor.constraint(equalToConstant: 42),
            iconImageView.heightAnchor.constraint(equalToConstant: 42),
            stackView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -24),
            stackView.centerYAnchor.constraint(equalTo: card.centerYAnchor)
        ])

        return card
    }

    private func showAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "확인", style: .default))
        present(alertController, animated: true)
    }

    @objc private func openSettings() {
        navigationController?.pushViewController(GroupSettingsViewController(group: group), animated: true)
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

        self.selectedHourKey = availableHourKeys[nextIndex]
        updateSelectedPosts()
        renderHourIndicators()
        updateHourStatusLabel()
        renderMemberAreas()
    }

    @objc private func postTapped(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended,
              let card = recognizer.view else {
            return
        }

        openPost(from: card)
    }

    @objc private func reactionButtonTapped(_ sender: UIButton) {
        guard let postID = sender.accessibilityIdentifier,
              let post = posts.first(where: { $0.id == postID }) else {
            return
        }

        presentReactionPicker(for: post)
    }

    @objc private func postLongPressed(_ recognizer: UILongPressGestureRecognizer) {
        guard let card = recognizer.view else { return }

        switch recognizer.state {
        case .began:
            UIView.animate(withDuration: 0.12) {
                card.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
                card.alpha = 0.9
            }
        case .ended:
            UIView.animate(withDuration: 0.12) {
                card.transform = .identity
                card.alpha = 1
            }
            openPost(from: card)
        case .cancelled, .failed:
            UIView.animate(withDuration: 0.12) {
                card.transform = .identity
                card.alpha = 1
            }
        default:
            break
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
    func presentReactionPicker(for post: Post) {
        let alertController = UIAlertController(title: "반응 남기기", message: nil, preferredStyle: .actionSheet)
        let currentEmoji = myReaction(for: post)?.emoji

        ReactionRepository.availableEmojis.forEach { emoji in
            let title = emoji == currentEmoji ? "\(emoji) 취소" : emoji
            alertController.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.toggleReaction(post: post, emoji: emoji)
            })
        }

        alertController.addAction(UIAlertAction(title: "닫기", style: .cancel))
        present(alertController, animated: true)
    }

    func toggleReaction(post: Post, emoji: String) {
        let currentEmoji = myReaction(for: post)?.emoji
        let completion: (Result<Void, Error>) -> Void = { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }

                switch result {
                case .success:
                    self.fetchReactionsAndRender()
                case .failure(let error):
                    ToastView.show(message: "반응 저장 실패: \(error.localizedDescription)", in: self.view)
                }
            }
        }

        if currentEmoji == emoji {
            reactionRepository.removeReaction(postID: post.id, completion: completion)
        } else {
            reactionRepository.setReaction(postID: post.id, emoji: emoji, completion: completion)
        }
    }

    func myReaction(for post: Post?) -> PostReaction? {
        guard let post,
              let userID = Auth.auth().currentUser?.uid else {
            return nil
        }

        return reactionsByPostID[post.id]?.first { $0.userID == userID }
    }

    func reactionButtonTitle(for post: Post?) -> String {
        guard post != nil else { return "…" }
        return myReaction(for: post)?.emoji ?? "♡"
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
            hourStatusLabel.text = "로그 없음"
            hourStatusLabel.textColor = AppTheme.secondaryText
            return
        }

        if selectedHourKey == HourSlot.currentKey() {
            hourStatusLabel.text = "지금"
            hourStatusLabel.textColor = AppTheme.mint
        } else {
            hourStatusLabel.text = "\(HourSlot.displayText(hourKey: selectedHourKey)) · 오늘"
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
