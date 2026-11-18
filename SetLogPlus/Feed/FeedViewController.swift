import AudioToolbox
import UIKit

final class FeedViewController: UIViewController {
    private let groupRepository = GroupRepository()
    private let notificationService = NotificationService()
    private var groups: [Group] = []
    private var hasLoadedGroups = false
    private let scrollView = UIScrollView()
    private let refreshControl = UIRefreshControl()
    private let contentStackView = UIStackView()
    private let addButton = IconCircleButton(systemName: "plus", accessibilityLabel: "그룹 추가")

    override func viewDidLoad() {
        super.viewDidLoad()
        title = ""
        view.backgroundColor = AppTheme.background
        AppTheme.applyDarkNavigation(to: navigationController)
        setupLayout()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // The feed draws its own header, so the (empty) navigation bar is hidden here.
        navigationController?.setNavigationBarHidden(true, animated: animated)
        fetchGroups()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Give pushed screens (group feed, profile) their navigation bar back.
        // Also runs when an interactive pop back to the feed is cancelled.
        if let navigationController, navigationController.topViewController !== self {
            navigationController.setNavigationBarHidden(false, animated: animated)
        }
    }

    private func setupLayout() {
        let logoImageView = UIImageView(image: UIImage(named: "SetLogPlusLogo"))
        logoImageView.contentMode = .scaleAspectFill
        logoImageView.layer.cornerRadius = 11
        logoImageView.layer.cornerCurve = .continuous
        logoImageView.clipsToBounds = true
        logoImageView.isAccessibilityElement = false
        logoImageView.translatesAutoresizingMaskIntoConstraints = false

        let logoLabel = UILabel()
        logoLabel.text = "SETLOG+"
        logoLabel.font = .systemFont(ofSize: 24, weight: .black)
        logoLabel.textColor = AppTheme.butter
        logoLabel.accessibilityLabel = "SetLog Plus"
        logoLabel.accessibilityTraits = .header
        logoLabel.adjustsFontSizeToFitWidth = true
        logoLabel.minimumScaleFactor = 0.7

        let logoStackView = UIStackView(arrangedSubviews: [logoImageView, logoLabel])
        logoStackView.axis = .horizontal
        logoStackView.alignment = .center
        logoStackView.spacing = 10
        logoStackView.translatesAutoresizingMaskIntoConstraints = false

        let subtitleLabel = UILabel()
        subtitleLabel.text = "오늘의 3초를 남겨보세요"
        subtitleLabel.font = AppTheme.roundedFont(.subheadline, weight: .medium)
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.textColor = AppTheme.secondaryText
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        addButton.addTarget(self, action: #selector(createGroupTapped), for: .touchUpInside)

        let bellButton = IconCircleButton(systemName: "bell", accessibilityLabel: "알림")
        bellButton.addTarget(self, action: #selector(openNotifications), for: .touchUpInside)
        let profileButton = IconCircleButton(systemName: "person.crop.circle.fill", accessibilityLabel: "프로필")
        profileButton.addTarget(self, action: #selector(openProfile), for: .touchUpInside)

        let topButtonStack = UIStackView(arrangedSubviews: [addButton, bellButton, profileButton])
        topButtonStack.axis = .horizontal
        topButtonStack.spacing = AppTheme.Spacing.s
        topButtonStack.translatesAutoresizingMaskIntoConstraints = false

        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        refreshControl.tintColor = AppTheme.secondaryText
        refreshControl.addAction(UIAction { [weak self] _ in
            Haptics.selection()
            self?.fetchGroups { [weak self] in
                self?.refreshControl.endRefreshing()
            }
        }, for: .valueChanged)
        scrollView.refreshControl = refreshControl

        contentStackView.axis = .vertical
        contentStackView.spacing = AppTheme.Spacing.m
        contentStackView.translatesAutoresizingMaskIntoConstraints = false

        let modeControl = BottomModeControl(selectedIndex: 1)
        modeControl.onCameraTapped = { [weak self] in
            guard let self else { return }
            AppRouter.showCamera(from: self)
        }
        modeControl.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(logoStackView)
        view.addSubview(topButtonStack)
        view.addSubview(subtitleLabel)
        view.addSubview(scrollView)
        view.addSubview(modeControl)
        scrollView.addSubview(contentStackView)

        let margin = AppTheme.Spacing.screen

        NSLayoutConstraint.activate([
            logoStackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: margin),
            logoStackView.centerYAnchor.constraint(equalTo: topButtonStack.centerYAnchor),
            logoStackView.trailingAnchor.constraint(lessThanOrEqualTo: topButtonStack.leadingAnchor, constant: -AppTheme.Spacing.m),

            logoImageView.widthAnchor.constraint(equalToConstant: 36),
            logoImageView.heightAnchor.constraint(equalToConstant: 36),

            topButtonStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: AppTheme.Spacing.s),
            topButtonStack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -margin),

            subtitleLabel.topAnchor.constraint(equalTo: topButtonStack.bottomAnchor, constant: AppTheme.Spacing.m),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: margin + 2),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -margin),

            scrollView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: AppTheme.Spacing.l),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: AppTheme.Spacing.l),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -AppTheme.Spacing.l),
            scrollView.bottomAnchor.constraint(equalTo: modeControl.topAnchor, constant: -AppTheme.Spacing.l),

            contentStackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: AppTheme.Spacing.xs),
            contentStackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -AppTheme.Spacing.l),
            contentStackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            modeControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            modeControl.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12)
        ])
    }

    private func fetchGroups(completion: (() -> Void)? = nil) {
        guard let uid = AuthService.shared.currentUserID else {
            renderInfo(InfoCardView(
                title: "로그인이 필요해요",
                message: "현재 로그인된 사용자를 찾을 수 없어요.",
                systemImageName: "person.crop.circle.badge.exclamationmark",
                titleStyle: .title3
            ))
            completion?()
            return
        }

        if !hasLoadedGroups {
            renderInfo(InfoCardView(
                title: "그룹을 불러오는 중",
                message: "잠시만 기다려주세요.",
                titleStyle: .title3,
                isLoading: true
            ))
        }

        groupRepository.fetchGroups(for: uid) { [weak self] result in
            guard let self else { return }
            defer { completion?() }

            switch result {
            case .success(let groups):
                self.hasLoadedGroups = true
                self.groups = groups
                self.renderGroups()
            case .failure(let error):
                if self.hasLoadedGroups && !self.groups.isEmpty {
                    // Keep the list on screen; a refresh failure doesn't need to wipe it.
                    ToastView.show(message: "그룹을 새로 불러오지 못했어요", style: .error, in: self.view)
                } else {
                    self.renderInfo(InfoCardView(
                        title: "그룹을 불러오지 못했어요",
                        message: error.localizedDescription,
                        systemImageName: "wifi.exclamationmark",
                        titleStyle: .title3,
                        actionTitle: "다시 시도",
                        action: { [weak self] in self?.fetchGroups() }
                    ))
                }
            }
        }
    }

    private func renderGroups() {
        guard !groups.isEmpty else {
            let emptyCard = InfoCardView(
                title: "아직 그룹이 없어요",
                message: "친구들과 함께할 그룹을 만들거나\n초대 코드로 참여해보세요.",
                systemImageName: "person.2.fill",
                titleStyle: .title3,
                minimumHeight: 280,
                actionTitle: "그룹 만들기",
                action: { [weak self] in self?.createGroupTapped() }
            )
            renderInfo(emptyCard)
            return
        }

        let header = AppTheme.makeSectionHeader("내 그룹 \(groups.count)")
        header.accessibilityTraits = .header
        header.accessibilityLabel = "내 그룹 \(groups.count)개"
        let headerContainer = UIView()
        header.translatesAutoresizingMaskIntoConstraints = false
        headerContainer.addSubview(header)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: headerContainer.topAnchor),
            header.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor),
            header.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: AppTheme.Spacing.xs),
            header.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor)
        ])

        contentStackView.replaceArrangedSubviews(with: [headerContainer] + groups.map(makeGroupCard))
        contentStackView.setCustomSpacing(AppTheme.Spacing.s, after: headerContainer)
    }

    private func renderInfo(_ infoCard: InfoCardView) {
        contentStackView.replaceArrangedSubviews(with: [infoCard])
    }

    private func makeGroupCard(_ group: Group) -> UIView {
        let card = PressableControl()
        AppTheme.roundCard(card, radius: AppTheme.Radius.medium)
        card.isAccessibilityElement = true
        card.accessibilityTraits = .button
        card.accessibilityLabel = "\(group.name), 멤버 \(group.memberIDs.count)명"
        card.accessibilityHint = "그룹 피드를 엽니다"
        card.addAction(UIAction { [weak self] _ in
            Haptics.tap()
            self?.openGroupFeed(group)
        }, for: .touchUpInside)

        let tileView = FeedGroupComponents.makeGroupTile(name: group.name, id: group.id, size: 48)

        let nameLabel = UILabel()
        nameLabel.text = group.name
        nameLabel.font = AppTheme.roundedFont(.headline, weight: .semibold)
        nameLabel.adjustsFontForContentSizeCategory = true
        nameLabel.textColor = AppTheme.text

        let avatarStack = FeedGroupComponents.makeMemberAvatarStack(memberIDs: group.memberIDs, size: 20)

        let memberLabel = UILabel()
        memberLabel.text = "멤버 \(group.memberIDs.count)명"
        memberLabel.font = .preferredFont(forTextStyle: .footnote)
        memberLabel.adjustsFontForContentSizeCategory = true
        memberLabel.textColor = AppTheme.secondaryText

        let memberRow = UIStackView(arrangedSubviews: [avatarStack, memberLabel])
        memberRow.axis = .horizontal
        memberRow.alignment = .center
        memberRow.spacing = AppTheme.Spacing.s

        let textStack = UIStackView(arrangedSubviews: [nameLabel, memberRow])
        textStack.axis = .vertical
        textStack.alignment = .leading
        textStack.spacing = 6

        let chevronImageView = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevronImageView.tintColor = AppTheme.tertiaryText
        chevronImageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        chevronImageView.setContentHuggingPriority(.required, for: .horizontal)
        chevronImageView.setContentCompressionResistancePriority(.required, for: .horizontal)

        let rowStack = UIStackView(arrangedSubviews: [tileView, textStack, chevronImageView])
        rowStack.axis = .horizontal
        rowStack.alignment = .center
        rowStack.spacing = AppTheme.Spacing.m + 2
        rowStack.isUserInteractionEnabled = false
        rowStack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(rowStack)

        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(greaterThanOrEqualToConstant: 80),
            rowStack.topAnchor.constraint(greaterThanOrEqualTo: card.topAnchor, constant: AppTheme.Spacing.l),
            rowStack.bottomAnchor.constraint(lessThanOrEqualTo: card.bottomAnchor, constant: -AppTheme.Spacing.l),
            rowStack.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            rowStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: AppTheme.Spacing.l),
            rowStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -AppTheme.Spacing.l)
        ])

        return card
    }

    private func openGroupFeed(_ group: Group) {
        navigationController?.pushViewController(GroupFeedViewController(group: group), animated: true)
    }

    @objc private func createGroupTapped() {
        let alertController = UIAlertController(title: "그룹", message: nil, preferredStyle: .actionSheet)
        alertController.addAction(UIAlertAction(title: "새 그룹 만들기", style: .default) { [weak self] _ in
            self?.showCreateGroupAlert()
        })
        alertController.addAction(UIAlertAction(title: "초대 코드로 참여", style: .default) { [weak self] _ in
            self?.showJoinGroupAlert()
        })
        alertController.addAction(UIAlertAction(title: "취소", style: .cancel))
        presentActionSheet(alertController, from: addButton)
    }

    private func showCreateGroupAlert() {
        guard let owner = AuthService.shared.currentAppUser else {
            showAlert(title: "그룹 생성 실패", message: "로그인이 필요합니다.")
            return
        }

        let alertController = UIAlertController(title: "새 그룹 만들기", message: "함께 로그를 남길 그룹 이름을 입력하세요.", preferredStyle: .alert)
        alertController.addTextField { textField in
            textField.placeholder = "예: 보존서고"
            textField.autocorrectionType = .no
            textField.returnKeyType = .done
        }

        alertController.addAction(UIAlertAction(title: "취소", style: .cancel))
        alertController.addAction(UIAlertAction(title: "만들기", style: .default) { [weak self, weak alertController] _ in
            guard let self,
                  let name = alertController?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !name.isEmpty else {
                if let view = self?.view {
                    ToastView.show(message: "그룹 이름을 입력해주세요", style: .error, in: view)
                }
                return
            }

            self.createGroup(name: name, owner: owner)
        })

        present(alertController, animated: true)
    }

    private func showJoinGroupAlert() {
        guard let user = AuthService.shared.currentAppUser else {
            showAlert(title: "그룹 참여 실패", message: "로그인이 필요합니다.")
            return
        }

        let alertController = UIAlertController(title: "초대 코드 입력", message: "친구에게 받은 6자리 초대 코드를 입력하세요.", preferredStyle: .alert)
        alertController.addTextField { textField in
            textField.placeholder = "예: AB12CD"
            textField.autocapitalizationType = .allCharacters
            textField.autocorrectionType = .no
            textField.returnKeyType = .done
        }

        alertController.addAction(UIAlertAction(title: "취소", style: .cancel))
        alertController.addAction(UIAlertAction(title: "참여", style: .default) { [weak self, weak alertController] _ in
            guard let self,
                  let code = alertController?.textFields?.first?.text,
                  !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                if let view = self?.view {
                    ToastView.show(message: "초대 코드를 입력해주세요", style: .error, in: view)
                }
                return
            }

            self.joinGroup(inviteCode: code, user: user)
        })

        present(alertController, animated: true)
    }

    private func createGroup(name: String, owner: AppUser) {
        groupRepository.createGroup(name: name, owner: owner) { [weak self] result in
            guard let self else { return }

            switch result {
            case .success:
                ToastView.show(message: "'\(name)' 그룹을 만들었어요", style: .success, in: self.view)
                self.fetchGroups()
            case .failure(let error):
                self.showAlert(title: "그룹 생성 실패", message: error.localizedDescription)
            }
        }
    }

    private func joinGroup(inviteCode: String, user: AppUser) {
        groupRepository.joinGroup(inviteCode: inviteCode, user: user) { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let group):
                self.openGroupFeed(group)
            case .failure(let error):
                self.showAlert(title: "그룹 참여 실패", message: error.localizedDescription)
            }
        }
    }

    @objc private func openProfile() {
        navigationController?.pushViewController(ProfileViewController(), animated: true)
    }

    @objc private func openNotifications() {
        guard !groups.isEmpty else {
            ToastView.show(message: "아직 받을 알림이 없어요", in: view)
            return
        }

        AudioServicesPlaySystemSound(SystemSoundID(1007))
        notificationService.fetchTodayLogNotifications(groups: groups, excluding: AuthService.shared.currentUserID) { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let notifications):
                guard !notifications.isEmpty else {
                    ToastView.show(message: "새 멤버 로그가 없어요", in: self.view)
                    return
                }

                self.showAlert(
                    title: "새 로그 알림",
                    message: notifications.map(\.message).joined(separator: "\n\n")
                )
            case .failure:
                ToastView.show(message: "알림을 불러오지 못했어요", style: .error, in: self.view)
            }
        }
    }
}
