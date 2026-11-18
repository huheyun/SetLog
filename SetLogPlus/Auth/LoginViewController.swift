import UIKit

final class LoginViewController: UIViewController {
    private let emailTextField = UITextField()
    private let passwordTextField = UITextField()
    private let loginButton = PrimaryButton(title: "로그인")
    private let signUpButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.background
        // The brand header replaces the navigation title; keep the pushed screen's back button compact.
        navigationItem.backButtonDisplayMode = .minimal
        setupLayout()
        setupKeyboardDismissal()
        updateLoginButtonState()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    private func setupLayout() {
        let headerView = AuthHeaderView(
            title: nil,
            subtitle: "짧게 찍고, 그룹과 하루를 기록해요."
        )

        AppTheme.styleTextField(emailTextField, placeholder: "name@example.com")
        emailTextField.keyboardType = .emailAddress
        emailTextField.textContentType = .username
        emailTextField.autocapitalizationType = .none
        emailTextField.returnKeyType = .next
        emailTextField.delegate = self

        AppTheme.styleTextField(passwordTextField, placeholder: "비밀번호를 입력하세요")
        passwordTextField.isSecureTextEntry = true
        passwordTextField.textContentType = .password
        passwordTextField.returnKeyType = .go
        passwordTextField.delegate = self
        passwordTextField.installPasswordVisibilityToggle()

        [emailTextField, passwordTextField].forEach {
            $0.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        }

        let emailField = AuthFormField(label: "이메일", textField: emailTextField)
        let passwordField = AuthFormField(label: "비밀번호", textField: passwordTextField)

        let formStack = UIStackView(arrangedSubviews: [emailField, passwordField])
        formStack.axis = .vertical
        formStack.spacing = AppTheme.Spacing.l

        loginButton.addTarget(self, action: #selector(loginTapped), for: .touchUpInside)

        configureSignUpButton()

        let contentStack = UIStackView(arrangedSubviews: [headerView, formStack, loginButton, signUpButton])
        contentStack.axis = .vertical
        contentStack.spacing = AppTheme.Spacing.xl
        contentStack.setCustomSpacing(AppTheme.Spacing.xxl + AppTheme.Spacing.s, after: headerView)
        contentStack.setCustomSpacing(AppTheme.Spacing.m, after: loginButton)

        AuthFormLayout.install(contentStack, in: self)
    }

    private func configureSignUpButton() {
        var configuration = UIButton.Configuration.plain()
        var attributed = AttributedString("아직 계정이 없나요? ")
        attributed.font = .preferredFont(forTextStyle: .subheadline)
        attributed.foregroundColor = AppTheme.secondaryText
        var action = AttributedString("회원가입")
        action.font = AppTheme.roundedFont(.subheadline, weight: .semibold)
        action.foregroundColor = AppTheme.neonPink
        attributed.append(action)
        configuration.attributedTitle = attributed
        configuration.titleLineBreakMode = .byWordWrapping
        signUpButton.configuration = configuration
        signUpButton.titleLabel?.adjustsFontForContentSizeCategory = true
        signUpButton.accessibilityLabel = "회원가입"
        signUpButton.accessibilityHint = "새 계정을 만듭니다"
        signUpButton.enablePressAnimation(scale: 0.97)
        signUpButton.addTarget(self, action: #selector(signUpTapped), for: .touchUpInside)
    }

    private func setupKeyboardDismissal() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    // MARK: - Validation

    private var trimmedEmail: String {
        emailTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var isFormValid: Bool {
        let email = trimmedEmail
        return !email.isEmpty && email.contains("@") && !(passwordTextField.text ?? "").isEmpty
    }

    @objc private func textFieldDidChange() {
        updateLoginButtonState()
    }

    private func updateLoginButtonState() {
        guard !loginButton.isLoading else { return }
        loginButton.isEnabled = isFormValid
    }

    // MARK: - Actions

    @objc private func loginTapped() {
        view.endEditing(true)
        guard !loginButton.isLoading else { return }

        guard let email = emailTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              let password = passwordTextField.text,
              !email.isEmpty,
              !password.isEmpty else {
            Haptics.error()
            showAlert(title: "로그인 실패", message: "이메일과 비밀번호를 입력해주세요.")
            return
        }

        setLoading(true)

        AuthService.shared.signIn(email: email, password: password) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.setLoading(false)

                switch result {
                case .success:
                    AppRouter.showLog(from: self)
                case .failure(let error):
                    Haptics.error()
                    self.showAlert(title: "로그인 실패", message: error.localizedDescription)
                }
            }
        }
    }

    @objc private func signUpTapped() {
        navigationController?.pushViewController(SignUpViewController(), animated: true)
    }

    private func setLoading(_ isLoading: Bool) {
        loginButton.isLoading = isLoading
        [emailTextField, passwordTextField].forEach { $0.isEnabled = !isLoading }
        signUpButton.isEnabled = !isLoading
        if !isLoading {
            updateLoginButtonState()
        }
    }
}

extension LoginViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === emailTextField {
            passwordTextField.becomeFirstResponder()
        } else if isFormValid {
            textField.resignFirstResponder()
            loginTapped()
        } else if trimmedEmail.isEmpty || !trimmedEmail.contains("@") {
            emailTextField.becomeFirstResponder()
        }

        return true
    }
}
