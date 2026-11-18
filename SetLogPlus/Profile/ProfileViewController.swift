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
            AppRouter.showLogin(from: self)
        case .failure(let error):
            showAlert(title: "로그아웃 실패", message: error.localizedDescription)
        }
    }
}
