import UIKit

final class LoginViewController: UIViewController {
    private let emailTextField = UITextField()
    private let passwordTextField = UITextField()
    private let loginButton = PrimaryButton(title: "Log In")
    private let stackView = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Login"
        view.backgroundColor = AppTheme.background
        setupLayout()
        setupKeyboardDismissal()
    }

    private func setupLayout() {
        let logoImageView = UIImageView(image: UIImage(named: "SetLogPlusLogo"))
        logoImageView.contentMode = .scaleAspectFill
        logoImageView.layer.cornerRadius = 38
        logoImageView.clipsToBounds = true
        logoImageView.translatesAutoresizingMaskIntoConstraints = false

        let logoContainerView = UIView()
        logoContainerView.translatesAutoresizingMaskIntoConstraints = false
        logoContainerView.addSubview(logoImageView)

        let titleLabel = UILabel()
        titleLabel.text = "SETLOG+"
        titleLabel.font = .systemFont(ofSize: 34, weight: .black)
        titleLabel.textColor = AppTheme.butter
        titleLabel.textAlignment = .center

        let subtitleLabel = UILabel()
        subtitleLabel.text = "짧게 찍고, 그룹과 하루를 기록해요."
        subtitleLabel.font = .preferredFont(forTextStyle: .subheadline)
        subtitleLabel.textColor = AppTheme.secondaryText
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        configureTextField(emailTextField, placeholder: "Email")
        emailTextField.keyboardType = .emailAddress
        emailTextField.autocapitalizationType = .none
        emailTextField.returnKeyType = .next
        emailTextField.delegate = self

        configureTextField(passwordTextField, placeholder: "Password")
        passwordTextField.isSecureTextEntry = true
        passwordTextField.returnKeyType = .done
        passwordTextField.delegate = self

        loginButton.addTarget(self, action: #selector(loginTapped), for: .touchUpInside)

        let signUpButton = UIButton(type: .system)
        signUpButton.setTitle("Create a new account", for: .normal)
        signUpButton.tintColor = AppTheme.lavender
        signUpButton.addTarget(self, action: #selector(signUpTapped), for: .touchUpInside)

        [
            logoContainerView,
            titleLabel,
            subtitleLabel,
            emailTextField,
            passwordTextField,
            loginButton,
            signUpButton
        ].forEach { stackView.addArrangedSubview($0) }
        stackView.axis = .vertical
        stackView.spacing = 14
        stackView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            stackView.centerYAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -160),
            logoContainerView.heightAnchor.constraint(equalToConstant: 76),
            logoImageView.centerXAnchor.constraint(equalTo: logoContainerView.centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: logoContainerView.centerYAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: 76),
            logoImageView.heightAnchor.constraint(equalToConstant: 76),
            emailTextField.heightAnchor.constraint(equalToConstant: 48),
            passwordTextField.heightAnchor.constraint(equalToConstant: 48)
        ])
    }

    private func configureTextField(_ textField: UITextField, placeholder: String) {
        textField.placeholder = placeholder
        textField.borderStyle = .none
        textField.backgroundColor = AppTheme.card
        textField.textColor = AppTheme.text
        textField.tintColor = AppTheme.neonPink
        textField.layer.cornerRadius = 14
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        textField.leftViewMode = .always
        textField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.45)]
        )
        textField.autocorrectionType = .no
    }

    private func setupKeyboardDismissal() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func loginTapped() {
        view.endEditing(true)

        guard let email = emailTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              let password = passwordTextField.text,
              !email.isEmpty,
              !password.isEmpty else {
            showAlert(message: "이메일과 비밀번호를 입력해주세요.")
            return
        }

        setLoading(true)

        AuthService.shared.signIn(email: email, password: password) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.setLoading(false)

                switch result {
                case .success:
                    AppRouter.showMainApp(from: self)
                case .failure(let error):
                    self.showAlert(message: error.localizedDescription)
                }
            }
        }
    }

    @objc private func signUpTapped() {
        navigationController?.pushViewController(SignUpViewController(), animated: true)
    }

    private func setLoading(_ isLoading: Bool) {
        loginButton.isEnabled = !isLoading
        loginButton.configuration?.showsActivityIndicator = isLoading
    }

    private func showAlert(message: String) {
        let alertController = UIAlertController(title: "로그인 실패", message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "확인", style: .default))
        present(alertController, animated: true)
    }
}

extension LoginViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === emailTextField {
            passwordTextField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
            loginTapped()
        }

        return true
    }
}
