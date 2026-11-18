import UIKit

final class SignUpViewController: UIViewController {
    private static let minimumPasswordLength = 6

    private let nameTextField = UITextField()
    private let emailTextField = UITextField()
    private let passwordTextField = UITextField()
    private let createButton = PrimaryButton(title: "가입하고 시작하기")
    private lazy var passwordField = AuthFormField(
        label: "비밀번호",
        textField: passwordTextField,
        helperText: "\(Self.minimumPasswordLength)자 이상 입력해주세요"
    )

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.background
        AppTheme.applyDarkNavigation(to: navigationController)
        setupLayout()
        setupKeyboardDismissal()
        updateFormState()
    }

    private func setupLayout() {
        let headerView = AuthHeaderView(
            title: "계정 만들기",
            subtitle: "SETLOG+ 계정을 만들고 그룹 로그를 시작해요.",
            logoSize: 64,
            showsWordmark: false
        )

        AppTheme.styleTextField(nameTextField, placeholder: "그룹에 보일 이름")
        nameTextField.returnKeyType = .next
        nameTextField.textContentType = .nickname
        nameTextField.delegate = self

        AppTheme.styleTextField(emailTextField, placeholder: "name@example.com")
        emailTextField.keyboardType = .emailAddress
        emailTextField.textContentType = .username
        emailTextField.autocapitalizationType = .none
        emailTextField.returnKeyType = .next
        emailTextField.delegate = self

        AppTheme.styleTextField(passwordTextField, placeholder: "비밀번호를 입력하세요")
        passwordTextField.isSecureTextEntry = true
        passwordTextField.textContentType = .newPassword
        passwordTextField.returnKeyType = .join
        passwordTextField.delegate = self
        passwordTextField.installPasswordVisibilityToggle()

        [nameTextField, emailTextField, passwordTextField].forEach {
            $0.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        }

        let nameField = AuthFormField(label: "닉네임", textField: nameTextField)
        let emailField = AuthFormField(label: "이메일", textField: emailTextField)

        let formStack = UIStackView(arrangedSubviews: [nameField, emailField, passwordField])
        formStack.axis = .vertical
        formStack.spacing = AppTheme.Spacing.l

        createButton.addTarget(self, action: #selector(createAccountTapped), for: .touchUpInside)

        let contentStack = UIStackView(arrangedSubviews: [headerView, formStack, createButton])
        contentStack.axis = .vertical
        contentStack.spacing = AppTheme.Spacing.xl
        contentStack.setCustomSpacing(AppTheme.Spacing.xxl, after: headerView)

        AuthFormLayout.install(contentStack, in: self)
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

    private var trimmedName: String {
        nameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var trimmedEmail: String {
        emailTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var isNameValid: Bool { !trimmedName.isEmpty }
    private var isEmailValid: Bool { !trimmedEmail.isEmpty && trimmedEmail.contains("@") }
    private var isPasswordValid: Bool { (passwordTextField.text ?? "").count >= Self.minimumPasswordLength }
    private var isFormValid: Bool { isNameValid && isEmailValid && isPasswordValid }

    @objc private func textFieldDidChange() {
        updateFormState()
    }

    private func updateFormState() {
        let password = passwordTextField.text ?? ""
        passwordField.setHelperState(isSatisfied: password.isEmpty ? nil : isPasswordValid)

        guard !createButton.isLoading else { return }
        createButton.isEnabled = isFormValid
    }

    // MARK: - Actions

    @objc private func createAccountTapped() {
        view.endEditing(true)
        guard !createButton.isLoading else { return }

        guard let displayName = nameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              let email = emailTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              let password = passwordTextField.text,
              !displayName.isEmpty,
              !email.isEmpty,
              !password.isEmpty else {
            Haptics.error()
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
                    Haptics.error()
                    self.showAlert(title: "회원가입 실패", message: error.localizedDescription)
                }
            }
        }
    }

    private func setLoading(_ isLoading: Bool) {
        createButton.isLoading = isLoading
        [nameTextField, emailTextField, passwordTextField].forEach { $0.isEnabled = !isLoading }
        // Avoid leaving the screen mid-request.
        navigationItem.hidesBackButton = isLoading
        if !isLoading {
            updateFormState()
        }
    }
}

extension SignUpViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === nameTextField {
            emailTextField.becomeFirstResponder()
        } else if textField === emailTextField {
            passwordTextField.becomeFirstResponder()
        } else if isFormValid {
            textField.resignFirstResponder()
            createAccountTapped()
        } else if !isNameValid {
            nameTextField.becomeFirstResponder()
        } else if !isEmailValid {
            emailTextField.becomeFirstResponder()
        }

        return true
    }
}
