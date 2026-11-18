import FirebaseAuth
import UIKit

final class ProfileViewController: UIViewController {
    private let groupRepository = GroupRepository()
    private var groups: [Group] = []
    private var hasLoadedGroups = false
    private let contentStackView = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "프로필"
        view.backgroundColor = AppTheme.background
        AppTheme.applyDarkNavigation(to: navigationController)
        setupLayout()
        renderProfile()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        fetchGroups()
    }

    private func setupLayout() {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        contentStackView.axis = .vertical
        contentStackView.spacing = AppTheme.Spacing.xl
        contentStackView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        scrollView.addSubview(contentStackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: AppTheme.Spacing.l),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -AppTheme.Spacing.l),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: AppTheme.Spacing.m),
            contentStackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -AppTheme.Spacing.xxl),
            contentStackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
    }

    private func fetchGroups() {
        guard let uid = AuthService.shared.currentUserID else {
            hasLoadedGroups = true
            renderProfile()
            return
        }

        groupRepository.fetchGroups(for: uid) { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let groups):
                self.groups = groups
            case .failure:
                ToastView.show(message: "그룹을 불러오지 못했어요", style: .error, in: self.view)
            }
            self.hasLoadedGroups = true
            self.renderProfile()
        }
    }

    private func renderProfile() {
        let groupsTitle = hasLoadedGroups ? "내 그룹 \(groups.count)" : "내 그룹"
        contentStackView.replaceArrangedSubviews(with: [
            makeUserCard(),
            FeedGroupComponents.makeSection(title: groupsTitle, content: makeGroupsContent()),
            makeReminderSection(),
            makeLogoutSection()
        ])
    }

    // MARK: - User

    private func makeUserCard() -> UIView {
        let card = UIView()
        AppTheme.roundCard(card, radius: AppTheme.Radius.large)

        let user = Auth.auth().currentUser
        let displayName = user?.displayName ?? "사용자"
        let email = user?.email ?? "이메일 없음"

        let avatarLabel = AppTheme.makeAvatarLabel(
            text: String(displayName.prefix(1)),
            size: 64,
            fontSize: 28,
            color: user.map { AppTheme.avatarColor(for: $0.uid) } ?? AppTheme.neonPink
        )

        let nameLabel = UILabel()
        nameLabel.text = displayName
        nameLabel.font = AppTheme.roundedFont(.title2, weight: .bold)
        nameLabel.adjustsFontForContentSizeCategory = true
        nameLabel.textColor = AppTheme.text
        nameLabel.numberOfLines = 2

        let emailLabel = UILabel()
        emailLabel.text = email
        emailLabel.font = .preferredFont(forTextStyle: .subheadline)
        emailLabel.adjustsFontForContentSizeCategory = true
        emailLabel.textColor = AppTheme.secondaryText
        emailLabel.lineBreakMode = .byTruncatingMiddle

        let textStackView = UIStackView(arrangedSubviews: [nameLabel, emailLabel])
        textStackView.axis = .vertical
        textStackView.spacing = AppTheme.Spacing.xs
        textStackView.isAccessibilityElement = true
        textStackView.accessibilityLabel = "\(displayName), \(email)"

        let editButton = IconCircleButton(systemName: "pencil", tintColor: AppTheme.text, accessibilityLabel: "닉네임 변경", size: 40)
        editButton.addTarget(self, action: #selector(editNameTapped), for: .touchUpInside)

        let rowStack = UIStackView(arrangedSubviews: [avatarLabel, textStackView, editButton])
        rowStack.axis = .horizontal
        rowStack.alignment = .center
        rowStack.spacing = AppTheme.Spacing.l
        rowStack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(rowStack)

        NSLayoutConstraint.activate([
            rowStack.topAnchor.constraint(equalTo: card.topAnchor, constant: AppTheme.Spacing.xl - 4),
            rowStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -(AppTheme.Spacing.xl - 4)),
            rowStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: AppTheme.Spacing.screen),
            rowStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -AppTheme.Spacing.l)
        ])

        return card
    }

    // MARK: - Groups

    private func makeGroupsContent() -> UIView {
        guard hasLoadedGroups else {
            return InfoCardView(title: "그룹을 불러오는 중", message: "잠시만 기다려주세요.", minimumHeight: 140, isLoading: true)
        }

        guard !groups.isEmpty else {
            return InfoCardView(
                title: "아직 참여 중인 그룹이 없어요",
                message: "홈의 + 버튼으로 그룹을 만들거나 참여해보세요.",
                systemImageName: "person.2",
                minimumHeight: 180
            )
        }

        return FeedGroupComponents.makeGroupedCard(rows: groups.map(makeGroupRow))
    }

    private func makeGroupRow(_ group: Group) -> UIView {
        let row = UIView()

        let tileView = FeedGroupComponents.makeGroupTile(name: group.name, id: group.id, size: 40)

        let nameLabel = UILabel()
        nameLabel.text = group.name
        nameLabel.font = AppTheme.roundedFont(.body, weight: .semibold)
        nameLabel.adjustsFontForContentSizeCategory = true
        nameLabel.textColor = AppTheme.text

        let memberLabel = UILabel()
        memberLabel.text = "멤버 \(group.memberIDs.count)명"
        memberLabel.font = .preferredFont(forTextStyle: .caption1)
        memberLabel.adjustsFontForContentSizeCategory = true
        memberLabel.textColor = AppTheme.secondaryText

        let textStack = UIStackView(arrangedSubviews: [nameLabel, memberLabel])
        textStack.axis = .vertical
        textStack.spacing = 2

        var arrangedSubviews: [UIView] = [tileView, textStack]
        let isOwner = group.ownerID == AuthService.shared.currentUserID
        if isOwner {
            arrangedSubviews.append(FeedGroupComponents.makePill(text: "그룹장", color: AppTheme.neonPink))
        }

        let rowStack = UIStackView(arrangedSubviews: arrangedSubviews)
        rowStack.axis = .horizontal
        rowStack.alignment = .center
        rowStack.spacing = AppTheme.Spacing.m
        rowStack.translatesAutoresizingMaskIntoConstraints = false

        row.addSubview(rowStack)
        row.isAccessibilityElement = true
        row.accessibilityLabel = "\(group.name), 멤버 \(group.memberIDs.count)명" + (isOwner ? ", 그룹장" : "")

        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 64),
            rowStack.topAnchor.constraint(greaterThanOrEqualTo: row.topAnchor, constant: AppTheme.Spacing.m),
            rowStack.bottomAnchor.constraint(lessThanOrEqualTo: row.bottomAnchor, constant: -AppTheme.Spacing.m),
            rowStack.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            rowStack.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: AppTheme.Spacing.l),
            rowStack.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -AppTheme.Spacing.l)
        ])

        return row
    }

    // MARK: - Reminder

    private func makeReminderSection() -> UIView {
        var rows = [makeReminderToggleRow()]
        if ReminderService.isEnabled {
            rows.append(makeReminderRangeRow())
        }
        return FeedGroupComponents.makeSection(title: "알림", content: FeedGroupComponents.makeGroupedCard(rows: rows))
    }

    private func makeReminderToggleRow() -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = "매시간 촬영 알림"
        titleLabel.font = AppTheme.roundedFont(.body, weight: .semibold)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = AppTheme.text

        let subtitleLabel = UILabel()
        subtitleLabel.text = ReminderService.rangeDescription
        subtitleLabel.font = .preferredFont(forTextStyle: .caption1)
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.textColor = AppTheme.secondaryText

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.isAccessibilityElement = false

        let toggle = UISwitch()
        toggle.isOn = ReminderService.isEnabled
        toggle.onTintColor = AppTheme.neonPink
        toggle.accessibilityLabel = "매시간 촬영 알림"
        toggle.accessibilityHint = ReminderService.rangeDescription
        toggle.setContentHuggingPriority(.required, for: .horizontal)
        toggle.setContentCompressionResistancePriority(.required, for: .horizontal)
        toggle.addTarget(self, action: #selector(reminderSwitchChanged(_:)), for: .valueChanged)

        return makeReminderRow(arrangedSubviews: [textStack, toggle])
    }

    private func makeReminderRangeRow() -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = "시간대"
        titleLabel.font = AppTheme.roundedFont(.body, weight: .semibold)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = AppTheme.text
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let startButton = makeHourMenuButton(isStart: true)
        let endButton = makeHourMenuButton(isStart: false)

        let tildeLabel = UILabel()
        tildeLabel.text = "~"
        tildeLabel.font = .preferredFont(forTextStyle: .body)
        tildeLabel.textColor = AppTheme.secondaryText
        tildeLabel.isAccessibilityElement = false

        let pickerStack = UIStackView(arrangedSubviews: [startButton, tildeLabel, endButton])
        pickerStack.axis = .horizontal
        pickerStack.alignment = .center
        pickerStack.spacing = AppTheme.Spacing.s
        pickerStack.setContentHuggingPriority(.required, for: .horizontal)

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        return makeReminderRow(arrangedSubviews: [titleLabel, spacer, pickerStack])
    }

    private func makeHourMenuButton(isStart: Bool) -> UIButton {
        let start = ReminderService.startHour
        let end = ReminderService.endHour
        let current = isStart ? start : end

        var configuration = UIButton.Configuration.filled()
        configuration.title = "\(current)시"
        configuration.baseBackgroundColor = AppTheme.cardMuted
        configuration.baseForegroundColor = AppTheme.text
        configuration.cornerStyle = .medium
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = AppTheme.roundedFont(.subheadline, weight: .semibold)
            return attributes
        }

        let actions = (0...23).map { hour in
            let isValid = isStart ? hour < end : hour > start
            let action = UIAction(title: "\(hour)시", state: hour == current ? .on : .off) { [weak self] _ in
                self?.updateReminderRange(start: isStart ? hour : start, end: isStart ? end : hour)
            }
            if !isValid {
                action.attributes = .disabled
            }
            return action
        }

        let button = UIButton(configuration: configuration)
        button.menu = UIMenu(title: isStart ? "시작 시간" : "끝 시간", children: actions)
        button.showsMenuAsPrimaryAction = true
        button.accessibilityLabel = isStart ? "시작 시간" : "끝 시간"
        button.accessibilityValue = "\(current)시"
        return button
    }

    private func makeReminderRow(arrangedSubviews: [UIView]) -> UIView {
        let row = UIView()

        let rowStack = UIStackView(arrangedSubviews: arrangedSubviews)
        rowStack.axis = .horizontal
        rowStack.alignment = .center
        rowStack.spacing = AppTheme.Spacing.m
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(rowStack)

        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 64),
            rowStack.topAnchor.constraint(greaterThanOrEqualTo: row.topAnchor, constant: AppTheme.Spacing.m),
            rowStack.bottomAnchor.constraint(lessThanOrEqualTo: row.bottomAnchor, constant: -AppTheme.Spacing.m),
            rowStack.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            rowStack.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: AppTheme.Spacing.l),
            rowStack.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -AppTheme.Spacing.l)
        ])

        return row
    }

    private func updateReminderRange(start: Int, end: Int) {
        guard ReminderService.setHourRange(start: start, end: end) else {
            Haptics.error()
            ToastView.show(message: "시작 시간은 끝 시간보다 빨라야 해요", style: .error, in: view)
            return
        }
        Haptics.selection()
        ToastView.show(message: "\(start)시 ~ \(end)시로 변경했어요", style: .success, in: view)
        renderProfile()
    }

    @objc private func reminderSwitchChanged(_ sender: UISwitch) {
        guard sender.isOn else {
            ReminderService.disable()
            ToastView.show(message: "알림을 껐어요", in: view)
            renderProfile()
            return
        }

        sender.isEnabled = false
        ReminderService.requestAuthorizationAndEnable { [weak self, weak sender] result in
            sender?.isEnabled = true
            guard let self else { return }

            switch result {
            case .enabled:
                Haptics.success()
                ToastView.show(message: "알림을 켰어요", style: .success, in: self.view)
                self.renderProfile()
            case .denied:
                sender?.setOn(false, animated: true)
                self.showNotificationPermissionAlert()
            case .failed(let error):
                sender?.setOn(false, animated: true)
                self.showAlert(title: "알림을 켜지 못했어요", message: error.localizedDescription)
            }
        }
    }

    private func showNotificationPermissionAlert() {
        let alertController = UIAlertController(
            title: "알림 권한이 꺼져 있어요",
            message: "설정에서 알림을 허용하면 매시간 촬영 알림을 받을 수 있어요.",
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "취소", style: .cancel))
        alertController.addAction(UIAlertAction(title: "설정 열기", style: .default) { _ in
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
        })
        present(alertController, animated: true)
    }

    // MARK: - Logout

    private func makeLogoutSection() -> UIView {
        let logoutButton = PrimaryButton(title: "로그아웃", style: .destructive)
        logoutButton.addTarget(self, action: #selector(logoutTapped), for: .touchUpInside)
        return FeedGroupComponents.makeSection(title: "계정", content: logoutButton)
    }

    // MARK: - Actions

    @objc private func editNameTapped() {
        let alertController = UIAlertController(title: "닉네임 변경", message: nil, preferredStyle: .alert)
        alertController.addTextField { textField in
            textField.placeholder = "닉네임"
            textField.text = Auth.auth().currentUser?.displayName
            textField.returnKeyType = .done
        }
        alertController.addAction(UIAlertAction(title: "취소", style: .cancel))
        alertController.addAction(UIAlertAction(title: "저장", style: .default) { [weak self, weak alertController] _ in
            guard let self,
                  let displayName = alertController?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !displayName.isEmpty else {
                return
            }

            AuthService.shared.updateDisplayName(displayName) { [weak self] result in
                guard let self else { return }

                switch result {
                case .success:
                    ToastView.show(message: "닉네임을 변경했어요", style: .success, in: self.view)
                    self.renderProfile()
                case .failure(let error):
                    self.showAlert(title: "닉네임 변경 실패", message: error.localizedDescription)
                }
            }
        })
        present(alertController, animated: true)
    }

    @objc private func logoutTapped() {
        let alertController = UIAlertController(title: "로그아웃할까요?", message: nil, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "취소", style: .cancel))
        alertController.addAction(UIAlertAction(title: "로그아웃", style: .destructive) { [weak self] _ in
            self?.performLogout()
        })
        present(alertController, animated: true)
    }

    private func performLogout() {
        switch AuthService.shared.signOut() {
        case .success:
            ReminderService.disable()
            AppRouter.showLogin(from: self)
        case .failure(let error):
            showAlert(title: "로그아웃 실패", message: error.localizedDescription)
        }
    }
}
