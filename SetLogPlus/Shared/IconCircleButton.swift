import UIKit

/// 44pt circular icon button. Always pass an `accessibilityLabel` for icon-only buttons.
final class IconCircleButton: UIButton {
    init(
        systemName: String,
        tintColor: UIColor = AppTheme.text,
        accessibilityLabel: String? = nil,
        size: CGFloat = 44
    ) {
        super.init(frame: .zero)
        setup(systemName: systemName, tintColor: tintColor, size: size)
        self.accessibilityLabel = accessibilityLabel
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Updates the icon (e.g. toggling mute).
    func setSymbol(_ systemName: String, tintColor: UIColor? = nil) {
        configuration?.image = UIImage(systemName: systemName)
        if let tintColor {
            configuration?.baseForegroundColor = tintColor
        }
    }

    private func setup(systemName: String, tintColor: UIColor, size: CGFloat) {
        var configuration = UIButton.Configuration.filled()
        configuration.image = UIImage(systemName: systemName)
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        configuration.baseBackgroundColor = AppTheme.cardMuted
        configuration.baseForegroundColor = tintColor
        configuration.cornerStyle = .capsule
        self.configuration = configuration
        enablePressAnimation()
        addAction(UIAction { _ in Haptics.tap() }, for: .touchUpInside)

        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: size).isActive = true
        heightAnchor.constraint(equalToConstant: size).isActive = true
    }
}
