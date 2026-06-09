import UIKit

final class SignUpViewController: UIViewController {
    private let nameTextField = UITextField()
    private let emailTextField = UITextField()
    private let passwordTextField = UITextField()
    private let createButton = PrimaryButton(title: "Create Account")
    private let stackView = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Sign Up"
        view.backgroundColor = AppTheme.background
        setupLayout()
        setupKeyboardDismissal()
    }

    private func setupLayout() {
        let logoImageView = UIImageView(image: UIImage(named: "SetLogPlusLogo"))
        logoImageView.contentMode = .scaleAspectFill
        logoImageView.layer.cornerRadius = 34
        logoImageView.clipsToBounds = true
        logoImageView.translatesAutoresizingMaskIntoConstraints = false

        let logoContainerView = UIView()
        logoContainerView.translatesAutoresizingMaskIntoConstraints = false
        logoContainerView.addSubview(logoImageView)

        let helperLabel = UILabel()
        helperLabel.text = "SETLOG+ 계정을 만들고 그룹 로그를 시작해요."
        helperLabel.font = .preferredFont(forTextStyle: .subheadline)
        helperLabel.textColor = AppTheme.secondaryText
        helperLabel.textAlignment = .center
        helperLabel.numberOfLines = 0

        configureTextField(nameTextField, placeholder: "Display name")
        nameTextField.returnKeyType = .next
        nameTextField.delegate = self

        configureTextField(emailTextField, placeholder: "Email")
        emailTextField.keyboardType = .emailAddress
        emailTextField.autocapitalizationType = .none
        emailTextField.returnKeyType = .next
        emailTextField.delegate = self

        configureTextField(passwordTextField, placeholder: "Password")
        passwordTextField.isSecureTextEntry = true
        passwordTextField.returnKeyType = .done
        passwordTextField.delegate = self

        createButton.addTarget(self, action: #selector(createAccountTapped), for: .touchUpInside)

        [
            logoContainerView,
            helperLabel,
            nameTextField,
            emailTextField,
            passwordTextField,
            createButton
        ].forEach { stackView.addArrangedSubview($0) }
        stackView.axis = .vertical
        stackView.spacing = 14
        stackView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            stackView.centerYAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -170),
            logoContainerView.heightAnchor.constraint(equalToConstant: 68),
            logoImageView.centerXAnchor.constraint(equalTo: logoContainerView.centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: logoContainerView.centerYAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: 68),
            logoImageView.heightAnchor.constraint(equalToConstant: 68),
            nameTextField.heightAnchor.constraint(equalToConstant: 48),
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

    @objc private func createAccountTapped() {
        view.endEditing(true)

        guard let displayName = nameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              let email = emailTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              let password = passwordTextField.text,
              !displayName.isEmpty,
              !email.isEmpty,
              !password.isEmpty else {
            showAlert(message: "이름, 이메일, 비밀번호를 모두 입력해주세요.")
            return
        }

        setLoading(true)

        AuthService.shared.signUp(displayName: displayName, email: email, password: password) { [weak self] result in
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

    private func setLoading(_ isLoading: Bool) {
        createButton.isEnabled = !isLoading
        createButton.configuration?.showsActivityIndicator = isLoading
    }

    private func showAlert(message: String) {
        let alertController = UIAlertController(title: "회원가입 실패", message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "확인", style: .default))
        present(alertController, animated: true)
    }
}

extension SignUpViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === nameTextField {
            emailTextField.becomeFirstResponder()
        } else if textField === emailTextField {
            passwordTextField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
            createAccountTapped()
        }

        return true
    }
}
