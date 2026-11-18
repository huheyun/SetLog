import UIKit

/// Centered icon + title + message card used for loading, empty and error states.
/// Pass `actionTitle`/`action` to show a call-to-action button (e.g. "다시 시도", "그룹 만들기").
/// Pass `isLoading: true` to show a spinner instead of the icon.
final class InfoCardView: UIView {
    private let action: (() -> Void)?

    init(
        title: String,
        message: String,
        systemImageName: String? = nil,
        titleStyle: UIFont.TextStyle = .headline,
        minimumHeight: CGFloat = 220,
        isLoading: Bool = false,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.action = action
        super.init(frame: .zero)
        setup(
            title: title,
            message: message,
            systemImageName: systemImageName,
            titleStyle: titleStyle,
            minimumHeight: minimumHeight,
            isLoading: isLoading,
            actionTitle: actionTitle
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup(
        title: String,
        message: String,
        systemImageName: String?,
        titleStyle: UIFont.TextStyle,
        minimumHeight: CGFloat,
        isLoading: Bool,
        actionTitle: String?
    ) {
        AppTheme.roundCard(self, radius: AppTheme.Radius.large)

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = AppTheme.roundedFont(titleStyle, weight: .bold)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = AppTheme.text
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.font = .preferredFont(forTextStyle: .subheadline)
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.textColor = AppTheme.secondaryText
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        let stackView = UIStackView(arrangedSubviews: [titleLabel, messageLabel])
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = AppTheme.Spacing.s
        stackView.translatesAutoresizingMaskIntoConstraints = false

        if isLoading {
            let indicator = UIActivityIndicatorView(style: .medium)
            indicator.color = AppTheme.secondaryText
            indicator.startAnimating()
            stackView.insertArrangedSubview(indicator, at: 0)
            stackView.setCustomSpacing(AppTheme.Spacing.l, after: indicator)
        } else if let systemImageName {
            let iconBackground = UIView()
            iconBackground.backgroundColor = AppTheme.neonPink.withAlphaComponent(0.14)
            iconBackground.layer.cornerRadius = 32
            iconBackground.translatesAutoresizingMaskIntoConstraints = false

            let iconImageView = UIImageView(image: UIImage(systemName: systemImageName))
            iconImageView.tintColor = AppTheme.neonPink
            iconImageView.contentMode = .scaleAspectFit
            iconImageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 26, weight: .semibold)
            iconImageView.translatesAutoresizingMaskIntoConstraints = false
            iconBackground.addSubview(iconImageView)

            stackView.insertArrangedSubview(iconBackground, at: 0)
            stackView.setCustomSpacing(AppTheme.Spacing.l, after: iconBackground)

            NSLayoutConstraint.activate([
                iconBackground.widthAnchor.constraint(equalToConstant: 64),
                iconBackground.heightAnchor.constraint(equalToConstant: 64),
                iconImageView.centerXAnchor.constraint(equalTo: iconBackground.centerXAnchor),
                iconImageView.centerYAnchor.constraint(equalTo: iconBackground.centerYAnchor)
            ])
        }

        if let actionTitle, action != nil {
            let button = PrimaryButton(title: actionTitle)
            button.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)
            stackView.setCustomSpacing(AppTheme.Spacing.xl, after: messageLabel)
            stackView.addArrangedSubview(button)
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: 180).isActive = true
        }

        addSubview(stackView)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: minimumHeight),
            stackView.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: AppTheme.Spacing.xl),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -AppTheme.Spacing.xl),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: AppTheme.Spacing.xl),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -AppTheme.Spacing.xl),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        isAccessibilityElement = action == nil
        accessibilityLabel = "\(title). \(message)"
    }

    @objc private func actionTapped() {
        action?()
    }
}

extension UIStackView {
    func removeAllArrangedSubviews() {
        arrangedSubviews.forEach { $0.removeFromSuperview() }
    }

    func replaceArrangedSubviews(with views: [UIView]) {
        removeAllArrangedSubviews()
        views.forEach { addArrangedSubview($0) }
    }
}
