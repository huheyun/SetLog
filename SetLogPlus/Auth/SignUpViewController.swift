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

        AppTheme.styleTextField(nameTextField, placeholder: "Display name")
        nameTextField.returnKeyType = .next
        nameTextField.textContentType = .nickname
        nameTextField.delegate = self

        AppTheme.styleTextField(emailTextField, placeholder: "Email")
        emailTextField.keyboardType = .emailAddress
        emailTextField.textContentType = .username
        emailTextField.autocapitalizationType = .none
        emailTextField.returnKeyType = .next
        emailTextField.delegate = self

        AppTheme.styleTextField(passwordTextField, placeholder: "Password")
        passwordTextField.isSecureTextEntry = true
        passwordTextField.textContentType = .newPassword
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
            logoImageView.heightAnchor.constraint(equalToConstant: 68)
        ])
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
            showAlert(title: "회원가입 실패", message: "이름, 이메일, 비밀번호를 모두 입력해주세요.")
            return
        }

        setLoading(true)

        AuthService.shared.signUp(displayName: displayName, email: email, password: password) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.setLoading(false)

                switch result {
                case .success:
                    AppRouter.showLog(from: self)
                case .failure(let error):
                    self.showAlert(title: "회원가입 실패", message: error.localizedDescription)
                }
            }
        }
    }

    private func setLoading(_ isLoading: Bool) {
        createButton.isEnabled = !isLoading
        createButton.configuration?.showsActivityIndicator = isLoading
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
