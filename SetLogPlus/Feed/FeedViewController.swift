import AudioToolbox
import FirebaseAuth
import UIKit

final class FeedViewController: UIViewController {
    private let groupRepository = GroupRepository()
    private let notificationService = NotificationService()
    private var groups: [Group] = []
    private let contentStackView = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = ""
        view.backgroundColor = AppTheme.background
        AppTheme.applyDarkNavigation(to: navigationController)
        setupLayout()
        fetchGroups()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        fetchGroups()
    }

    private func setupLayout() {
        let logoImageView = UIImageView(image: UIImage(named: "SetLogPlusLogo"))
        logoImageView.contentMode = .scaleAspectFill
        logoImageView.layer.cornerRadius = 19
        logoImageView.clipsToBounds = true
        logoImageView.translatesAutoresizingMaskIntoConstraints = false

        let logoLabel = UILabel()
        logoLabel.text = "SETLOG+"
        logoLabel.font = .systemFont(ofSize: 24, weight: .black)
        logoLabel.textColor = AppTheme.butter

        let logoStackView = UIStackView(arrangedSubviews: [logoImageView, logoLabel])
        logoStackView.axis = .horizontal
        logoStackView.alignment = .center
        logoStackView.spacing = 10
        logoStackView.translatesAutoresizingMaskIntoConstraints = false

        let addButton = IconCircleButton(systemName: "plus")
        addButton.addTarget(self, action: #selector(createGroupTapped), for: .touchUpInside)

        let bellButton = IconCircleButton(systemName: "bell")
        bellButton.addTarget(self, action: #selector(openNotifications), for: .touchUpInside)
        let profileButton = IconCircleButton(systemName: "person.crop.circle.fill")
        profileButton.addTarget(self, action: #selector(openProfile), for: .touchUpInside)

        let topButtonStack = UIStackView(arrangedSubviews: [addButton, bellButton, profileButton])
        topButtonStack.axis = .horizontal
        topButtonStack.spacing = 14
        topButtonStack.translatesAutoresizingMaskIntoConstraints = false

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

        view.addSubview(logoStackView)
        view.addSubview(topButtonStack)
        view.addSubview(scrollView)
        view.addSubview(modeControl)
        scrollView.addSubview(contentStackView)

        NSLayoutConstraint.activate([
            logoStackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            logoStackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),

            logoImageView.widthAnchor.constraint(equalToConstant: 38),
            logoImageView.heightAnchor.constraint(equalToConstant: 38),

            topButtonStack.centerYAnchor.constraint(equalTo: logoStackView.centerYAnchor),
            topButtonStack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),

            scrollView.topAnchor.constraint(equalTo: logoStackView.bottomAnchor, constant: 28),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
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

    private func fetchGroups() {
        guard let uid = Auth.auth().currentUser?.uid else {
            renderEmptyState(message: "현재 로그인된 사용자를 찾을 수 없습니다.")
            return
        }

        renderLoadingState()

        groupRepository.fetchGroups(for: uid) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }

                switch result {
                case .success(let groups):
                    self.groups = groups
                    self.renderGroups()
                case .failure(let error):
                    self.renderEmptyState(message: "그룹을 불러오지 못했습니다.\n\(error.localizedDescription)")
                }
            }
        }
    }

    private func renderLoadingState() {
        contentStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        contentStackView.addArrangedSubview(makeInfoCard(title: "그룹을 불러오는 중", message: "잠시만 기다려주세요.", systemImageName: "person.2"))
    }

    private func renderGroups() {
        contentStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if groups.isEmpty {
            renderEmptyState(message: "아직 그룹이 없습니다.\n오른쪽 위 + 버튼으로 첫 그룹을 만들어보세요.")
            return
        }

        groups.forEach { group in
            contentStackView.addArrangedSubview(makeGroupCard(group))
        }
    }

    private func renderEmptyState(message: String) {
        contentStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        contentStackView.addArrangedSubview(makeInfoCard(title: "그룹이 없습니다", message: message, systemImageName: "person.2"))
    }

    private func makeInfoCard(title: String, message: String, systemImageName: String) -> UIView {
        let card = UIView()
        AppTheme.roundCard(card, radius: 22)

        let iconImageView = UIImageView(image: UIImage(systemName: systemImageName))
        iconImageView.tintColor = AppTheme.mint
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .preferredFont(forTextStyle: .title2)
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
        stackView.spacing = 14
        stackView.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(stackView)

        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(greaterThanOrEqualToConstant: 220),
            iconImageView.widthAnchor.constraint(equalToConstant: 48),
            iconImageView.heightAnchor.constraint(equalToConstant: 48),
            stackView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -24),
            stackView.centerYAnchor.constraint(equalTo: card.centerYAnchor)
        ])

        return card
    }

    private func makeGroupCard(_ group: Group) -> UIView {
        let card = UIView()
        AppTheme.roundCard(card, radius: 18)
        card.isUserInteractionEnabled = true
        card.accessibilityLabel = "\(group.name) 그룹 열기"

        let nameLabel = UILabel()
        nameLabel.text = group.name
        nameLabel.font = .preferredFont(forTextStyle: .headline)
        nameLabel.textColor = AppTheme.text

        let memberLabel = UILabel()
        memberLabel.text = "멤버 \(group.memberIDs.count)명 · 코드 \(group.inviteCode)"
        memberLabel.font = .preferredFont(forTextStyle: .caption1)
        memberLabel.textColor = AppTheme.neonPink

        let textStack = UIStackView(arrangedSubviews: [nameLabel, memberLabel])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let cameraImageView = UIImageView(image: UIImage(systemName: "camera.fill"))
        cameraImageView.tintColor = UIColor(white: 0.45, alpha: 1)
        cameraImageView.translatesAutoresizingMaskIntoConstraints = false

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(groupCardTapped(_:)))
        card.addGestureRecognizer(tapGesture)
        card.tag = groups.firstIndex { $0.id == group.id } ?? 0

        card.addSubview(textStack)
        card.addSubview(cameraImageView)

        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 72),
            textStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            textStack.centerYAnchor.constraint(equalTo: card.centerYAnchor),

            cameraImageView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            cameraImageView.centerYAnchor.constraint(equalTo: card.centerYAnchor)
        ])

        return card
    }

    @objc private func groupCardTapped(_ sender: UITapGestureRecognizer) {
        guard let card = sender.view,
              groups.indices.contains(card.tag) else {
            return
        }

        navigationController?.pushViewController(GroupFeedViewController(group: groups[card.tag]), animated: true)
    }

    private func currentAppUser() -> AppUser? {
        guard let user = Auth.auth().currentUser else { return nil }

        return AppUser(
            uid: user.uid,
            email: user.email ?? "",
            displayName: user.displayName ?? user.email ?? "사용자"
        )
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
        present(alertController, animated: true)
    }

    private func showCreateGroupAlert() {
        guard let owner = currentAppUser() else {
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
                self?.showAlert(title: "그룹 생성 실패", message: "그룹 이름을 입력해주세요.")
                return
            }

            self.createGroup(name: name, owner: owner)
        })

        present(alertController, animated: true)
    }

    private func showJoinGroupAlert() {
        guard let user = currentAppUser() else {
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
                self?.showAlert(title: "그룹 참여 실패", message: "초대 코드를 입력해주세요.")
                return
            }

            self.joinGroup(inviteCode: code, user: user)
        })

        present(alertController, animated: true)
    }

    private func createGroup(name: String, owner: AppUser) {
        groupRepository.createGroup(name: name, owner: owner) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }

                switch result {
                case .success:
                    self.fetchGroups()
                case .failure(let error):
                    self.showAlert(title: "그룹 생성 실패", message: error.localizedDescription)
                }
            }
        }
    }

    private func joinGroup(inviteCode: String, user: AppUser) {
        groupRepository.joinGroup(inviteCode: inviteCode, user: user) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }

                switch result {
                case .success(let group):
                    self.fetchGroups()
                    self.navigationController?.pushViewController(GroupFeedViewController(group: group), animated: true)
                case .failure(let error):
                    self.showAlert(title: "그룹 참여 실패", message: error.localizedDescription)
                }
            }
        }
    }

    private func showAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "확인", style: .default))
        present(alertController, animated: true)
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
        notificationService.fetchTodayLogNotifications(groups: groups, excluding: Auth.auth().currentUser?.uid) { [weak self] result in
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
            case .failure(let error):
                self.showAlert(title: "알림 조회 실패", message: error.localizedDescription)
            }
        }
    }
}
