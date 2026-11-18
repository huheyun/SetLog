import UIKit

/// Full-width capsule button with an optional loading state.
final class PrimaryButton: UIButton {
    enum Style {
        case primary
        case secondary
        case destructive
    }

    private let title: String
    private let style: Style

    /// Shows a spinner and disables the button while `true`.
    var isLoading = false {
        didSet {
            guard isLoading != oldValue else { return }
            isEnabled = !isLoading
            setNeedsUpdateConfiguration()
        }
    }

    init(title: String, style: Style = .primary) {
        self.title = title
        self.style = style
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.cornerStyle = .capsule
        configuration.imagePadding = 8
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = AppTheme.roundedFont(.headline, weight: .semibold)
            return attributes
        }
        self.configuration = configuration

        configurationUpdateHandler = { [weak self] button in
            guard let self, var configuration = button.configuration else { return }
            configuration.showsActivityIndicator = self.isLoading
            configuration.title = self.isLoading ? nil : self.title

            switch self.style {
            case .primary:
                configuration.baseBackgroundColor = AppTheme.neonPink
                configuration.baseForegroundColor = .white
            case .secondary:
                configuration.baseBackgroundColor = AppTheme.cardMuted
                configuration.baseForegroundColor = AppTheme.text
            case .destructive:
                configuration.baseBackgroundColor = AppTheme.danger.withAlphaComponent(0.16)
                configuration.baseForegroundColor = AppTheme.danger
            }

            if !button.isEnabled && !self.isLoading {
                configuration.baseBackgroundColor = configuration.baseBackgroundColor?.withAlphaComponent(0.35)
                configuration.baseForegroundColor = configuration.baseForegroundColor?.withAlphaComponent(0.5)
            }
            button.configuration = configuration

            let pressed = button.isHighlighted
            UIView.animate(withDuration: pressed ? 0.12 : 0.28, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
                button.transform = pressed ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
            }
        }

        heightAnchor.constraint(greaterThanOrEqualToConstant: 54).isActive = true
        addAction(UIAction { _ in Haptics.tap() }, for: .touchUpInside)
    }
}
