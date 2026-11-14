import UIKit

/// Centered icon + title + message card used for loading, empty and error states.
final class InfoCardView: UIView {
    init(
        title: String,
        message: String,
        systemImageName: String? = nil,
        titleStyle: UIFont.TextStyle = .headline,
        minimumHeight: CGFloat = 220
    ) {
        super.init(frame: .zero)
        setup(
            title: title,
            message: message,
            systemImageName: systemImageName,
            titleStyle: titleStyle,
            minimumHeight: minimumHeight
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
        minimumHeight: CGFloat
    ) {
        AppTheme.roundCard(self, radius: 18)

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .preferredFont(forTextStyle: titleStyle)
        titleLabel.textColor = AppTheme.text
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.font = .preferredFont(forTextStyle: .subheadline)
        messageLabel.textColor = AppTheme.secondaryText
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        let stackView = UIStackView(arrangedSubviews: [titleLabel, messageLabel])
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false

        if let systemImageName {
            let iconImageView = UIImageView(image: UIImage(systemName: systemImageName))
            iconImageView.tintColor = AppTheme.mint
            iconImageView.contentMode = .scaleAspectFit
            iconImageView.translatesAutoresizingMaskIntoConstraints = false
            stackView.insertArrangedSubview(iconImageView, at: 0)

            NSLayoutConstraint.activate([
                iconImageView.widthAnchor.constraint(equalToConstant: 44),
                iconImageView.heightAnchor.constraint(equalToConstant: 44)
            ])
        }

        addSubview(stackView)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: minimumHeight),
            stackView.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 20),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -20),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
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
