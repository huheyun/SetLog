import FirebaseAuth
import UIKit

final class ProfileViewController: UIViewController {
    private let groupRepository = GroupRepository()
    private var groups: [Group] = []
    private let contentStackView = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "프로필"
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

    private func fetchGroups() {
        guard let uid = Auth.auth().currentUser?.uid else {
            renderProfile()
            return
        }

        groupRepository.fetchGroups(for: uid) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }

                if case .success(let groups) = result {
                    self.groups = groups
                }

                self.renderProfile()
            }
        }
    }

    private func renderProfile() {
        contentStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        contentStackView.addArrangedSubview(makeUserCard())
        contentStackView.addArrangedSubview(makeGroupsCard())
        contentStackView.addArrangedSubview(makeLogoutButton())
    }

    private func makeUserCard() -> UIView {
        let card = UIView()
        AppTheme.roundCard(card, radius: 18)

        let user = Auth.auth().currentUser
        let displayName = user?.displayName ?? "사용자"
        let email = user?.email ?? "이메일 없음"

        let avatarLabel = UILabel()
        avatarLabel.text = String(displayName.prefix(1))
        avatarLabel.font = .systemFont(ofSize: 30, weight: .black)
        avatarLabel.textColor = .white
        avatarLabel.textAlignment = .center
        avatarLabel.backgroundColor = AppTheme.neonPink
        avatarLabel.layer.cornerRadius = 34
        avatarLabel.clipsToBounds = true
        avatarLabel.translatesAutoresizingMaskIntoConstraints = false

        let nameLabel = UILabel()
        nameLabel.text = displayName
        nameLabel.font = .systemFont(ofSize: 24, weight: .black)
        nameLabel.textColor = AppTheme.text

        let emailLabel = UILabel()
        emailLabel.text = email
        emailLabel.font = .preferredFont(forTextStyle: .subheadline)
        emailLabel.textColor = AppTheme.secondaryText

        let editButton = UIButton(type: .system)
        editButton.setImage(UIImage(systemName: "pencil"), for: .normal)
        editButton.tintColor = AppTheme.mint
        editButton.addTarget(self, action: #selector(editNameTapped), for: .touchUpInside)
        editButton.translatesAutoresizingMaskIntoConstraints = false

        let textStackView = UIStackView(arrangedSubviews: [nameLabel, emailLabel])
        textStackView.axis = .vertical
        textStackView.spacing = 4
        textStackView.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(avatarLabel)
        card.addSubview(textStackView)
        card.addSubview(editButton)

        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(greaterThanOrEqualToConstant: 126),

            avatarLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            avatarLabel.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            avatarLabel.widthAnchor.constraint(equalToConstant: 68),
            avatarLabel.heightAnchor.constraint(equalToConstant: 68),

            textStackView.leadingAnchor.constraint(equalTo: avatarLabel.trailingAnchor, constant: 16),
            textStackView.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            textStackView.trailingAnchor.constraint(lessThanOrEqualTo: editButton.leadingAnchor, constant: -12),

            editButton.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            editButton.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            editButton.widthAnchor.constraint(equalToConstant: 34),
            editButton.heightAnchor.constraint(equalToConstant: 34)
        ])

        return card
    }

    private func makeGroupsCard() -> UIView {
        let card = UIView()
        AppTheme.roundCard(card, radius: 18)

        let titleLabel = UILabel()
        titleLabel.text = "내 그룹 \(groups.count)개"
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.textColor = AppTheme.text

        let stackView = UIStackView(arrangedSubviews: [titleLabel])
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false

        if groups.isEmpty {
            let emptyLabel = UILabel()
            emptyLabel.text = "아직 참여 중인 그룹이 없습니다."
            emptyLabel.font = .preferredFont(forTextStyle: .subheadline)
            emptyLabel.textColor = AppTheme.secondaryText
            stackView.addArrangedSubview(emptyLabel)
        } else {
            groups.forEach { group in
                stackView.addArrangedSubview(makeGroupRow(group))
            }
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

    private func makeGroupRow(_ group: Group) -> UIView {
        let row = UIView()
        row.backgroundColor = UIColor.white.withAlphaComponent(0.035)
        row.layer.cornerRadius = 14

        let nameLabel = UILabel()
        nameLabel.text = group.name
        nameLabel.font = .systemFont(ofSize: 16, weight: .bold)
        nameLabel.textColor = AppTheme.text

        let memberLabel = UILabel()
        memberLabel.text = "멤버 \(group.memberIDs.count)명"
        memberLabel.font = .preferredFont(forTextStyle: .caption1)
        memberLabel.textColor = AppTheme.secondaryText

        let stackView = UIStackView(arrangedSubviews: [nameLabel, memberLabel])
        stackView.axis = .vertical
        stackView.spacing = 3
        stackView.translatesAutoresizingMaskIntoConstraints = false

        row.addSubview(stackView)

        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 58),
            stackView.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 14),
            stackView.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -14),
            stackView.centerYAnchor.constraint(equalTo: row.centerYAnchor)
        ])

        return row
    }

    private func makeLogoutButton() -> UIButton {
        let logoutButton = PrimaryButton(title: "로그아웃")
        logoutButton.configuration?.baseBackgroundColor = UIColor.white.withAlphaComponent(0.12)
        logoutButton.configuration?.baseForegroundColor = .systemRed
        logoutButton.addTarget(self, action: #selector(logoutTapped), for: .touchUpInside)
        logoutButton.translatesAutoresizingMaskIntoConstraints = false
        return logoutButton
    }

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

            AuthService.shared.updateDisplayName(displayName) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        ToastView.show(message: "닉네임이 변경됐어요", in: self.view)
                        self.renderProfile()
                    case .failure(let error):
                        self.showAlert(title: "닉네임 변경 실패", message: error.localizedDescription)
                    }
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

    private func showAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "확인", style: .default))
        present(alertController, animated: true)
    }
}
