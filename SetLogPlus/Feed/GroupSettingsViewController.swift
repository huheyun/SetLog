import UIKit

final class GroupSettingsViewController: UIViewController {
    private let groupRepository = GroupRepository()
    private let group: Group
    private var members: [GroupMember] = []
    private let contentStackView = UIStackView()

    init(group: Group) {
        self.group = group
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "그룹 설정"
        view.backgroundColor = AppTheme.background
        AppTheme.applyDarkNavigation(to: navigationController)
        setupLayout()
        fetchMembers()
    }

    private func setupLayout() {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        contentStackView.axis = .vertical
        contentStackView.spacing = 14
        contentStackView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        scrollView.addSubview(contentStackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),

            contentStackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentStackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
    }

    private func fetchMembers() {
        renderLoadingState()

        groupRepository.fetchMembers(groupID: group.id) { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let members):
                self.members = members.sortedForDisplay()
            case .failure(let error):
                self.showAlert(title: "멤버 조회 실패", message: error.localizedDescription)
            }
            self.renderSettings()
        }
    }

    private func renderLoadingState() {
        contentStackView.replaceArrangedSubviews(with: [
            InfoCardView(title: group.name, message: "멤버를 불러오는 중입니다.", minimumHeight: 150)
        ])
    }

    private func renderSettings() {
        contentStackView.replaceArrangedSubviews(with: [
            makeGroupSummaryCard(),
            makeMembersCard(),
            makeActionButton()
        ])
    }

    private func makeGroupSummaryCard() -> UIView {
        let card = UIView()
        AppTheme.roundCard(card, radius: 18)

        let titleLabel = UILabel()
        titleLabel.text = group.name
        titleLabel.font = .preferredFont(forTextStyle: .title2)
        titleLabel.textColor = AppTheme.text

        let inviteLabel = UILabel()
        inviteLabel.text = "초대 코드 \(group.inviteCode)"
        inviteLabel.font = .monospacedSystemFont(ofSize: 15, weight: .semibold)
        inviteLabel.textColor = AppTheme.neonPink

        let copyButton = IconCircleButton(systemName: "doc.on.doc")
        copyButton.configuration?.baseForegroundColor = AppTheme.mint
        copyButton.addTarget(self, action: #selector(copyInviteCodeTapped), for: .touchUpInside)

        let inviteStackView = UIStackView(arrangedSubviews: [inviteLabel, copyButton])
        inviteStackView.axis = .horizontal
        inviteStackView.alignment = .center
        inviteStackView.spacing = 10

        let roleLabel = UILabel()
        roleLabel.text = isCurrentUserOwner ? "내 역할: 그룹장" : "내 역할: 그룹원"
        roleLabel.font = .preferredFont(forTextStyle: .subheadline)
        roleLabel.textColor = AppTheme.secondaryText

        let stackView = UIStackView(arrangedSubviews: [titleLabel, inviteStackView, roleLabel])
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(stackView)

        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(greaterThanOrEqualToConstant: 118),
            stackView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            stackView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            stackView.centerYAnchor.constraint(equalTo: card.centerYAnchor)
        ])

        return card
    }

    private func makeMembersCard() -> UIView {
        let card = UIView()
        AppTheme.roundCard(card, radius: 18)

        let titleLabel = UILabel()
        titleLabel.text = "멤버 \(members.count)명"
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.textColor = AppTheme.text

        let stackView = UIStackView(arrangedSubviews: [titleLabel])
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false

        members.forEach { member in
            stackView.addArrangedSubview(makeMemberRow(member))
        }

        card.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            stackView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            stackView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            stackView.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18)
        ])

        return card
    }

    private func makeMemberRow(_ member: GroupMember) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = UIColor.white.withAlphaComponent(0.035)
        containerView.layer.cornerRadius = 14

        let avatarLabel = AppTheme.makeAvatarLabel(
            text: member.isOwner ? "★" : String(member.displayName.prefix(1)),
            size: 36,
            fontSize: 15,
            color: member.isOwner ? AppTheme.neonPink : AppTheme.purple
        )

        let nameLabel = UILabel()
        nameLabel.text = member.displayName
        nameLabel.font = .systemFont(ofSize: 16, weight: .bold)
        nameLabel.textColor = AppTheme.text

        let emailLabel = UILabel()
        emailLabel.text = member.email
        emailLabel.font = .preferredFont(forTextStyle: .caption1)
        emailLabel.textColor = AppTheme.secondaryText

        let textStackView = UIStackView(arrangedSubviews: [nameLabel, emailLabel])
        textStackView.axis = .vertical
        textStackView.spacing = 3
        textStackView.translatesAutoresizingMaskIntoConstraints = false

        let roleLabel = UILabel()
        roleLabel.text = member.isOwner ? "그룹장" : "그룹원"
        roleLabel.font = .systemFont(ofSize: 12, weight: .bold)
        roleLabel.textColor = member.isOwner ? AppTheme.neonPink : AppTheme.secondaryText
        roleLabel.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        roleLabel.textAlignment = .center
        roleLabel.layer.cornerRadius = 10
        roleLabel.clipsToBounds = true
        roleLabel.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(avatarLabel)
        containerView.addSubview(textStackView)
        containerView.addSubview(roleLabel)

        NSLayoutConstraint.activate([
            containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 62),

            avatarLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            avatarLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),

            textStackView.leadingAnchor.constraint(equalTo: avatarLabel.trailingAnchor, constant: 12),
            textStackView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            textStackView.trailingAnchor.constraint(lessThanOrEqualTo: roleLabel.leadingAnchor, constant: -10),

            roleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            roleLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            roleLabel.widthAnchor.constraint(equalToConstant: 58),
            roleLabel.heightAnchor.constraint(equalToConstant: 26)
        ])

        return containerView
    }

    private func makeActionButton() -> UIButton {
        let button = PrimaryButton(title: isCurrentUserOwner ? "그룹 삭제" : "그룹 나가기")
        button.configuration?.baseBackgroundColor = .systemRed
        button.addTarget(self, action: #selector(groupActionTapped), for: .touchUpInside)
        return button
    }

    @objc private func groupActionTapped() {
        let title = isCurrentUserOwner ? "그룹을 삭제할까요?" : "그룹을 나갈까요?"
        let message = isCurrentUserOwner ? "그룹과 멤버 정보가 삭제됩니다." : "이 그룹 목록에서 빠지게 됩니다."

        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "취소", style: .cancel))
        alertController.addAction(UIAlertAction(title: isCurrentUserOwner ? "삭제" : "나가기", style: .destructive) { [weak self] _ in
            self?.performGroupAction()
        })
        present(alertController, animated: true)
    }

    @objc private func copyInviteCodeTapped() {
        UIPasteboard.general.string = group.inviteCode
        ToastView.show(message: "초대 코드가 복사됐어요", in: view)
    }

    private func performGroupAction() {
        guard let userID = AuthService.shared.currentUserID else {
            showAlert(title: "실패", message: "로그인이 필요합니다.")
            return
        }

        let completion: (Result<Void, Error>) -> Void = { [weak self] result in
            guard let self else { return }

            switch result {
            case .success:
                self.navigationController?.popToRootViewController(animated: true)
            case .failure(let error):
                self.showAlert(title: "실패", message: error.localizedDescription)
            }
        }

        if isCurrentUserOwner {
            groupRepository.deleteGroup(group: group, userID: userID, completion: completion)
        } else {
            groupRepository.leaveGroup(group: group, userID: userID, completion: completion)
        }
    }

    private var isCurrentUserOwner: Bool {
        AuthService.shared.currentUserID == group.ownerID
    }
}
