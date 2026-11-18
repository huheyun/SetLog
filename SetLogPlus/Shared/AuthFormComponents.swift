import UIKit

// Building blocks shared by the login and sign-up screens.

/// Logo + wordmark + title/tagline block shown at the top of auth screens.
final class AuthHeaderView: UIView {
    init(title: String?, subtitle: String, logoSize: CGFloat = 84, showsWordmark: Bool = true) {
        super.init(frame: .zero)
        setup(title: title, subtitle: subtitle, logoSize: logoSize, showsWordmark: showsWordmark)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup(title: String?, subtitle: String, logoSize: CGFloat, showsWordmark: Bool) {
        let logoImageView = UIImageView(image: UIImage(named: "SetLogPlusLogo"))
        logoImageView.contentMode = .scaleAspectFill
        logoImageView.layer.cornerRadius = logoSize * 0.28
        logoImageView.layer.cornerCurve = .continuous
        logoImageView.layer.borderWidth = 1
        logoImageView.layer.borderColor = AppTheme.separator.cgColor
        logoImageView.clipsToBounds = true
        logoImageView.isAccessibilityElement = false
        logoImageView.translatesAutoresizingMaskIntoConstraints = false

        // Soft accent glow behind the logo.
        let logoContainer = UIView()
        logoContainer.layer.shadowColor = AppTheme.neonPink.cgColor
        logoContainer.layer.shadowOpacity = 0.35
        logoContainer.layer.shadowRadius = 24
        logoContainer.layer.shadowOffset = .zero
        logoContainer.translatesAutoresizingMaskIntoConstraints = false
        logoContainer.addSubview(logoImageView)

        let stack = UIStackView(arrangedSubviews: [logoContainer])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = AppTheme.Spacing.s
        stack.setCustomSpacing(AppTheme.Spacing.l, after: logoContainer)
        stack.translatesAutoresizingMaskIntoConstraints = false

        if showsWordmark {
            let wordmarkLabel = UILabel()
            wordmarkLabel.text = "SETLOG+"
            wordmarkLabel.font = AppTheme.roundedFont(.largeTitle, weight: .black)
            wordmarkLabel.adjustsFontForContentSizeCategory = true
            wordmarkLabel.textColor = AppTheme.butter
            wordmarkLabel.textAlignment = .center
            wordmarkLabel.accessibilityTraits = .header
            stack.addArrangedSubview(wordmarkLabel)
        }

        if let title {
            let titleLabel = UILabel()
            titleLabel.text = title
            titleLabel.font = AppTheme.titleFont
            titleLabel.adjustsFontForContentSizeCategory = true
            titleLabel.textColor = AppTheme.text
            titleLabel.textAlignment = .center
            titleLabel.numberOfLines = 0
            titleLabel.accessibilityTraits = .header
            stack.addArrangedSubview(titleLabel)
        }

        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = .preferredFont(forTextStyle: .subheadline)
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.textColor = AppTheme.secondaryText
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        stack.addArrangedSubview(subtitleLabel)

        addSubview(stack)
        NSLayoutConstraint.activate([
            logoContainer.widthAnchor.constraint(equalToConstant: logoSize),
            logoContainer.heightAnchor.constraint(equalToConstant: logoSize),
            logoImageView.topAnchor.constraint(equalTo: logoContainer.topAnchor),
            logoImageView.bottomAnchor.constraint(equalTo: logoContainer.bottomAnchor),
            logoImageView.leadingAnchor.constraint(equalTo: logoContainer.leadingAnchor),
            logoImageView.trailingAnchor.constraint(equalTo: logoContainer.trailingAnchor),

            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }
}

/// Caption label + text field + optional helper text, stacked vertically.
final class AuthFormField: UIStackView {
    let textField: UITextField
    private let helperText: String?
    private let helperLabel = UILabel()

    init(label: String, textField: UITextField, helperText: String? = nil) {
        self.textField = textField
        self.helperText = helperText
        super.init(frame: .zero)

        axis = .vertical
        spacing = AppTheme.Spacing.s

        let captionLabel = AppTheme.makeSectionHeader(label)
        captionLabel.isAccessibilityElement = false
        textField.accessibilityLabel = label
        addArrangedSubview(captionLabel)
        addArrangedSubview(textField)

        helperLabel.font = .preferredFont(forTextStyle: .caption1)
        helperLabel.adjustsFontForContentSizeCategory = true
        helperLabel.textColor = AppTheme.tertiaryText
        helperLabel.numberOfLines = 0
        helperLabel.text = helperText
        helperLabel.isHidden = helperText == nil
        addArrangedSubview(helperLabel)
        setCustomSpacing(AppTheme.Spacing.s - 2, after: textField)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Colors the helper text: `nil` = neutral, `true` = rule satisfied, `false` = rule violated.
    func setHelperState(isSatisfied: Bool?) {
        guard let helperText else { return }
        let color: UIColor
        switch isSatisfied {
        case .some(true): color = AppTheme.success
        case .some(false): color = AppTheme.danger
        case .none: color = AppTheme.tertiaryText
        }

        let attributed = NSMutableAttributedString()
        if isSatisfied == true,
           let image = UIImage(systemName: "checkmark.circle.fill")?.withTintColor(color, renderingMode: .alwaysOriginal) {
            attributed.append(NSAttributedString(attachment: NSTextAttachment(image: image)))
            attributed.append(NSAttributedString(string: " "))
        }
        attributed.append(NSAttributedString(string: helperText))
        helperLabel.attributedText = attributed
        helperLabel.textColor = color
        helperLabel.accessibilityLabel = helperText
    }
}

extension UITextField {
    /// Adds an eye button to the right side that toggles secure entry.
    func installPasswordVisibilityToggle() {
        clearButtonMode = .never

        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: "eye.slash")
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        configuration.baseForegroundColor = AppTheme.tertiaryText
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 16)

        let button = UIButton(configuration: configuration)
        button.accessibilityLabel = "비밀번호 보기"
        button.frame = CGRect(x: 0, y: 0, width: 48, height: 44)
        button.addAction(UIAction { [weak self, weak button] _ in
            guard let self, let button else { return }
            let wasFirstResponder = self.isFirstResponder
            // Re-assigning the text keeps it from being cleared on the next keystroke.
            let currentText = self.text
            self.isSecureTextEntry.toggle()
            self.text = nil
            self.text = currentText
            if wasFirstResponder { _ = self.becomeFirstResponder() }

            let isHidden = self.isSecureTextEntry
            button.configuration?.image = UIImage(systemName: isHidden ? "eye.slash" : "eye")
            button.configuration?.baseForegroundColor = isHidden ? AppTheme.tertiaryText : AppTheme.neonPink
            button.accessibilityLabel = isHidden ? "비밀번호 보기" : "비밀번호 숨기기"
            Haptics.selection()
        }, for: .touchUpInside)

        rightView = button
        rightViewMode = .always
    }
}

enum AuthFormLayout {
    /// Pins a keyboard-avoiding scroll view to `viewController.view` and centers `content` inside it
    /// when it fits, with 20pt side margins.
    @discardableResult
    static func install(_ content: UIView, in viewController: UIViewController) -> UIScrollView {
        guard let view = viewController.view else { return UIScrollView() }

        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive
        scrollView.showsVerticalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        content.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(content)

        let contentGuide = scrollView.contentLayoutGuide
        let frameGuide = scrollView.frameLayoutGuide
        let margin = AppTheme.Spacing.screen
        let vertical = AppTheme.Spacing.xl

        // Fill the visible height so the form sits centered when it fits; grow (and scroll) when it doesn't.
        let fillHeight = contentGuide.heightAnchor.constraint(greaterThanOrEqualTo: frameGuide.heightAnchor)
        let preferredHeight = contentGuide.heightAnchor.constraint(equalTo: frameGuide.heightAnchor)
        preferredHeight.priority = .defaultLow
        let centerY = content.centerYAnchor.constraint(equalTo: contentGuide.centerYAnchor)
        centerY.priority = .defaultHigh

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),

            contentGuide.widthAnchor.constraint(equalTo: frameGuide.widthAnchor),
            fillHeight,
            preferredHeight,

            content.leadingAnchor.constraint(equalTo: contentGuide.leadingAnchor, constant: margin),
            content.trailingAnchor.constraint(equalTo: contentGuide.trailingAnchor, constant: -margin),
            content.topAnchor.constraint(greaterThanOrEqualTo: contentGuide.topAnchor, constant: vertical),
            content.bottomAnchor.constraint(lessThanOrEqualTo: contentGuide.bottomAnchor, constant: -vertical),
            centerY
        ])
        return scrollView
    }
}
