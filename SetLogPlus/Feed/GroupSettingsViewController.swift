import UIKit

final class GroupSettingsViewController: UIViewController {
    private let groupRepository = GroupRepository()
    private let group: Group
    private var members: [GroupMember] = []
    private var membersLoadError: Error?
    private let contentStackView = UIStackView()
    private weak var actionButton: PrimaryButton?

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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
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

    private func fetchMembers() {
        membersLoadError = nil
        renderLoadingState()

        groupRepository.fetchMembers(groupID: group.id) { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let members):
                self.members = members.sortedForDisplay()
            case .failure(let error):
                self.membersLoadError = error
            }
            self.renderSettings()
        }
    }

    private func renderLoadingState() {
        contentStackView.replaceArrangedSubviews(with: [
            InfoCardView(title: group.name, message: "멤버를 불러오는 중이에요.", minimumHeight: 180, isLoading: true)
        ])
    }

    private func renderSettings() {
        contentStackView.replaceArrangedSubviews(with: [
            makeGroupSummaryCard(),
            FeedGroupComponents.makeSection(title: "초대", content: makeInviteCard()),
            FeedGroupComponents.makeSection(title: membersSectionTitle, content: makeMembersContent()),
            makeActionSection()
        ])
    }

    private var membersSectionTitle: String {
        membersLoadError == nil ? "멤버 \(members.count)" : "멤버"
    }

    // MARK: - Summary

    private func makeGroupSummaryCard() -> UIView {
        let card = UIView()
        AppTheme.roundCard(card, radius: AppTheme.Radius.large)

        let tileView = FeedGroupComponents.makeGroupTile(name: group.name, id: group.id, size: 56)

        let titleLabel = UILabel()
        titleLabel.text = group.name
        titleLabel.font = AppTheme.roundedFont(.title2, weight: .bold)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = AppTheme.text
        titleLabel.numberOfLines = 2

        let memberCount = membersLoadError == nil ? members.count : group.memberIDs.count
        let memberLabel = UILabel()
        memberLabel.text = "멤버 \(memberCount)명"
        memberLabel.font = .preferredFont(forTextStyle: .subheadline)
        memberLabel.adjustsFontForContentSizeCategory = true
        memberLabel.textColor = AppTheme.secondaryText

        let rolePill = FeedGroupComponents.makePill(
            text: isCurrentUserOwner ? "그룹장" : "그룹원",
            color: isCurrentUserOwner ? AppTheme.neonPink : AppTheme.secondaryText
        )
        rolePill.accessibilityLabel = isCurrentUserOwner ? "내 역할: 그룹장" : "내 역할: 그룹원"

        let metaStack = UIStackView(arrangedSubviews: [memberLabel, rolePill])
        metaStack.axis = .horizontal
        metaStack.alignment = .center
        metaStack.spacing = AppTheme.Spacing.s

        let textStack = UIStackView(arrangedSubviews: [titleLabel, metaStack])
        textStack.axis = .vertical
        textStack.alignment = .leading
        textStack.spacing = 6

        let rowStack = UIStackView(arrangedSubviews: [tileView, textStack])
        rowStack.axis = .horizontal
        rowStack.alignment = .center
        rowStack.spacing = AppTheme.Spacing.l
        rowStack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(rowStack)

        NSLayoutConstraint.activate([
            rowStack.topAnchor.constraint(equalTo: card.topAnchor, constant: AppTheme.Spacing.xl - 4),
            rowStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -(AppTheme.Spacing.xl - 4)),
            rowStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: AppTheme.Spacing.screen),
            rowStack.trailingAnchor.constraint(lessThanOrEqualTo: card.trailingAnchor, constant: -AppTheme.Spacing.screen)
        ])

        return card
    }

    // MARK: - Invite

    private func makeInviteCard() -> UIView {
        let captionLabel = UILabel()
        captionLabel.text = "초대 코드"
        captionLabel.font = .preferredFont(forTextStyle: .caption1)
        captionLabel.adjustsFontForContentSizeCategory = true
        captionLabel.textColor = AppTheme.secondaryText

        let codeLabel = UILabel()
        codeLabel.text = group.inviteCode
        codeLabel.font = UIFontMetrics(forTextStyle: .title2).scaledFont(for: .monospacedSystemFont(ofSize: 22, weight: .bold))
        codeLabel.adjustsFontForContentSizeCategory = true
        codeLabel.textColor = AppTheme.text
        codeLabel.adjustsFontSizeToFitWidth = true
        codeLabel.minimumScaleFactor = 0.7

        let codeStack = UIStackView(arrangedSubviews: [captionLabel, codeLabel])
        codeStack.axis = .vertical
        codeStack.spacing = 2
        codeStack.isAccessibilityElement = true
        codeStack.accessibilityLabel = "초대 코드 \(group.inviteCode.map(String.init).joined(separator: " "))"

        let copyButton = IconCircleButton(systemName: "doc.on.doc", tintColor: AppTheme.text, accessibilityLabel: "초대 코드 복사")
        copyButton.addTarget(self, action: #selector(copyInviteCodeTapped), for: .touchUpInside)

        let shareButton = IconCircleButton(systemName: "square.and.arrow.up", tintColor: AppTheme.neonPink, accessibilityLabel: "초대 코드 공유")
        shareButton.addAction(UIAction { [weak self, weak shareButton] _ in
            self?.shareInviteCode(from: shareButton)
        }, for: .touchUpInside)

        let buttonStack = UIStackView(arrangedSubviews: [copyButton, shareButton])
        buttonStack.axis = .horizontal
        buttonStack.spacing = AppTheme.Spacing.s
        buttonStack.setContentHuggingPriority(.required, for: .horizontal)
        buttonStack.setContentCompressionResistancePriority(.required, for: .horizontal)

        let rowStack = UIStackView(arrangedSubviews: [codeStack, buttonStack])
        rowStack.axis = .horizontal
        rowStack.alignment = .center
        rowStack.spacing = AppTheme.Spacing.m

        let hintLabel = UILabel()
        hintLabel.text = "친구에게 코드를 보내면 + 버튼의 '초대 코드로 참여'로 들어올 수 있어요."
        hintLabel.font = .preferredFont(forTextStyle: .footnote)
        hintLabel.adjustsFontForContentSizeCategory = true
        hintLabel.textColor = AppTheme.tertiaryText
        hintLabel.numberOfLines = 0

        let stackView = UIStackView(arrangedSubviews: [rowStack, hintLabel])
        stackView.axis = .vertical
        stackView.spacing = AppTheme.Spacing.m
        stackView.translatesAutoresizingMaskIntoConstraints = false

        let card = UIView()
        AppTheme.roundCard(card, radius: AppTheme.Radius.medium)
        card.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: card.topAnchor, constant: AppTheme.Spacing.l),
            stackView.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -AppTheme.Spacing.l),
            stackView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: AppTheme.Spacing.l),
            stackView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -AppTheme.Spacing.l)
        ])

        return card
    }

    // MARK: - Members

    private func makeMembersContent() -> UIView {
        if membersLoadError != nil {
            return InfoCardView(
                title: "멤버를 불러오지 못했어요",
                message: "네트워크 상태를 확인하고 다시 시도해주세요.",
                systemImageName: "wifi.exclamationmark",
                minimumHeight: 200,
                actionTitle: "다시 시도",
                action: { [weak self] in self?.fetchMembers() }
            )
        }

        if members.isEmpty {
            return InfoCardView(
                title: "멤버가 없어요",
                message: "초대 코드를 공유해 친구를 불러보세요.",
                systemImageName: "person.2",
                minimumHeight: 160
            )
        }

        return FeedGroupComponents.makeGroupedCard(rows: members.map(makeMemberRow))
    }

    private func makeMemberRow(_ member: GroupMember) -> UIView {
        let row = UIView()

        let isMe = member.uid == AuthService.shared.currentUserID
        let avatarLabel = AppTheme.makeAvatarLabel(
            text: String(member.displayName.prefix(1)),
            size: 40,
            fontSize: 16,
            color: AppTheme.avatarColor(for: member.uid)
        )

        let nameLabel = UILabel()
        nameLabel.text = isMe ? "\(member.displayName) (나)" : member.displayName
        nameLabel.font = AppTheme.roundedFont(.body, weight: .semibold)
        nameLabel.adjustsFontForContentSizeCategory = true
        nameLabel.textColor = AppTheme.text

        let emailLabel = UILabel()
        emailLabel.text = member.email
        emailLabel.font = .preferredFont(forTextStyle: .caption1)
        emailLabel.adjustsFontForContentSizeCategory = true
        emailLabel.textColor = AppTheme.secondaryText
        emailLabel.lineBreakMode = .byTruncatingMiddle

        let textStackView = UIStackView(arrangedSubviews: [nameLabel, emailLabel])
        textStackView.axis = .vertical
        textStackView.spacing = 2

        var arrangedSubviews: [UIView] = [avatarLabel, textStackView]
        if member.isOwner {
            arrangedSubviews.append(FeedGroupComponents.makePill(text: "그룹장", color: AppTheme.neonPink))
        }

        let rowStack = UIStackView(arrangedSubviews: arrangedSubviews)
        rowStack.axis = .horizontal
        rowStack.alignment = .center
        rowStack.spacing = AppTheme.Spacing.m
        rowStack.translatesAutoresizingMaskIntoConstraints = false

        row.addSubview(rowStack)
        row.isAccessibilityElement = true
        row.accessibilityLabel = [
            member.displayName,
            isMe ? "나" : nil,
            member.isOwner ? "그룹장" : "그룹원",
            member.email
        ].compactMap { $0 }.joined(separator: ", ")

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

    // MARK: - Danger zone

    private func makeActionSection() -> UIView {
        let button = PrimaryButton(title: isCurrentUserOwner ? "그룹 삭제" : "그룹 나가기", style: .destructive)
        button.addTarget(self, action: #selector(groupActionTapped), for: .touchUpInside)
        actionButton = button

        let footnoteLabel = UILabel()
        footnoteLabel.text = isCurrentUserOwner
            ? "그룹장이 그룹을 삭제하면 모든 멤버가 이 그룹에서 빠지게 돼요."
            : "나가도 초대 코드로 언제든 다시 참여할 수 있어요."
        footnoteLabel.font = .preferredFont(forTextStyle: .footnote)
        footnoteLabel.adjustsFontForContentSizeCategory = true
        footnoteLabel.textColor = AppTheme.tertiaryText
        footnoteLabel.textAlignment = .center
        footnoteLabel.numberOfLines = 0

        let stackView = UIStackView(arrangedSubviews: [button, footnoteLabel])
        stackView.axis = .vertical
        stackView.spacing = AppTheme.Spacing.s + 2
        return stackView
    }

    // MARK: - Actions

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
        ToastView.show(message: "초대 코드를 복사했어요", style: .success, in: view)
    }

    private func shareInviteCode(from sourceView: UIView?) {
        let text = "SetLog+에서 '\(group.name)' 그룹에 함께해요!\n초대 코드: \(group.inviteCode)"
        let activityViewController = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let popover = activityViewController.popoverPresentationController {
            let anchorView = sourceView ?? view
            popover.sourceView = anchorView
            popover.sourceRect = anchorView?.bounds ?? .zero
        }
        present(activityViewController, animated: true)
    }

    private func performGroupAction() {
        guard let userID = AuthService.shared.currentUserID else {
            showAlert(title: "실패", message: "로그인이 필요합니다.")
            return
        }

        actionButton?.isLoading = true

        let completion: (Result<Void, Error>) -> Void = { [weak self] result in
            guard let self else { return }
            self.actionButton?.isLoading = false

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
