import UIKit

enum ToastView {
    enum Style {
        case info
        case success
        case error

        var symbolName: String? {
            switch self {
            case .info: return nil
            case .success: return "checkmark.circle.fill"
            case .error: return "exclamationmark.triangle.fill"
            }
        }

        var tintColor: UIColor {
            switch self {
            case .info: return AppTheme.text
            case .success: return AppTheme.success
            case .error: return AppTheme.danger
            }
        }
    }

    private static let toastTag = 0x7057

    static func show(message: String, style: Style = .info, in view: UIView) {
        // Replace any toast that's still on screen instead of stacking them.
        view.viewWithTag(toastTag)?.removeFromSuperview()

        let container = UIVisualEffectView(effect: UIBlurEffect(style: .systemThickMaterialDark))
        container.tag = toastTag
        container.layer.cornerRadius = 22
        container.layer.cornerCurve = .continuous
        container.layer.borderWidth = 1
        container.layer.borderColor = AppTheme.separator.cgColor
        container.clipsToBounds = true
        container.alpha = 0
        container.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = message
        label.font = AppTheme.roundedFont(.subheadline, weight: .semibold)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = AppTheme.text
        label.numberOfLines = 0
        label.textAlignment = .center

        let stackView = UIStackView(arrangedSubviews: [label])
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false

        if let symbolName = style.symbolName {
            let iconView = UIImageView(image: UIImage(systemName: symbolName))
            iconView.tintColor = style.tintColor
            iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
            iconView.setContentHuggingPriority(.required, for: .horizontal)
            stackView.insertArrangedSubview(iconView, at: 0)
        }

        container.contentView.addSubview(stackView)
        view.addSubview(container)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: container.contentView.topAnchor, constant: 12),
            stackView.bottomAnchor.constraint(equalTo: container.contentView.bottomAnchor, constant: -12),
            stackView.leadingAnchor.constraint(equalTo: container.contentView.leadingAnchor, constant: 18),
            stackView.trailingAnchor.constraint(equalTo: container.contentView.trailingAnchor, constant: -18),

            container.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            container.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -96),
            container.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 28),
            container.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -28)
        ])

        switch style {
        case .success: Haptics.success()
        case .error: Haptics.error()
        case .info: break
        }
        UIAccessibility.post(notification: .announcement, argument: message)

        container.transform = CGAffineTransform(translationX: 0, y: 12)
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
            container.alpha = 1
            container.transform = .identity
        } completion: { _ in
            UIView.animate(withDuration: 0.25, delay: 1.6) {
                container.alpha = 0
                container.transform = CGAffineTransform(translationX: 0, y: 8)
            } completion: { _ in
                container.removeFromSuperview()
            }
        }
    }
}
