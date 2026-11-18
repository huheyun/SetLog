import UIKit

/// Design tokens and small styling helpers shared by every screen.
///
/// Surfaces go from `background` → `card` → `cardMuted` (each a step lighter).
/// Use `neonPink` as the single primary accent; `butter` is reserved for the brand wordmark
/// and small highlights, `mint` for success/positive states.
enum AppTheme {
    // MARK: - Colors

    static let background = UIColor(red: 0.04, green: 0.04, blue: 0.05, alpha: 1)
    static let card = UIColor(red: 0.09, green: 0.09, blue: 0.11, alpha: 1)
    static let cardMuted = UIColor(red: 0.14, green: 0.14, blue: 0.17, alpha: 1)
    static let separator = UIColor(white: 1, alpha: 0.08)

    static let neonPink = UIColor(red: 0.95, green: 0.38, blue: 0.96, alpha: 1)
    static let mint = UIColor(red: 1.0, green: 0.86, blue: 0.38, alpha: 1)
    static let success = UIColor(red: 0.40, green: 0.88, blue: 0.62, alpha: 1)
    static let danger = UIColor(red: 1.0, green: 0.42, blue: 0.45, alpha: 1)
    static let purple = UIColor(red: 0.70, green: 0.55, blue: 0.96, alpha: 1)
    static let lavender = UIColor(red: 0.82, green: 0.72, blue: 1.0, alpha: 1)
    static let butter = UIColor(red: 1.0, green: 0.91, blue: 0.54, alpha: 1)

    static let text = UIColor.white
    static let secondaryText = UIColor(white: 1, alpha: 0.64)
    static let tertiaryText = UIColor(white: 1, alpha: 0.40)

    /// Distinct, readable colors for member avatars. Pick with `avatarColor(for:)`.
    static let avatarPalette: [UIColor] = [
        UIColor(red: 0.95, green: 0.38, blue: 0.96, alpha: 1),
        UIColor(red: 0.55, green: 0.48, blue: 0.98, alpha: 1),
        UIColor(red: 0.30, green: 0.70, blue: 0.98, alpha: 1),
        UIColor(red: 0.25, green: 0.80, blue: 0.62, alpha: 1),
        UIColor(red: 0.98, green: 0.62, blue: 0.30, alpha: 1),
        UIColor(red: 0.98, green: 0.45, blue: 0.55, alpha: 1)
    ]

    /// Stable color for an identifier (same user → same color everywhere).
    static func avatarColor(for id: String) -> UIColor {
        let hash = id.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7fffffff }
        return avatarPalette[hash % avatarPalette.count]
    }

    // MARK: - Layout

    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        /// Horizontal screen margin.
        static let screen: CGFloat = 20
    }

    enum Radius {
        static let small: CGFloat = 12
        static let medium: CGFloat = 18
        static let large: CGFloat = 24
    }

    // MARK: - Typography

    /// Rounded system font that scales with Dynamic Type.
    static func roundedFont(_ style: UIFont.TextStyle, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.preferredFont(forTextStyle: style)
        let font = UIFont.systemFont(ofSize: base.pointSize, weight: weight)
        let descriptor = font.fontDescriptor.withDesign(.rounded) ?? font.fontDescriptor
        return UIFontMetrics(forTextStyle: style).scaledFont(for: UIFont(descriptor: descriptor, size: base.pointSize))
    }

    /// Large screen title, e.g. "프로필".
    static var titleFont: UIFont { roundedFont(.title1, weight: .bold) }
    /// Section header inside a screen.
    static var sectionFont: UIFont { roundedFont(.headline, weight: .semibold) }

    static func makeSectionHeader(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: .footnote).withWeight(.semibold)
        label.textColor = tertiaryText
        label.adjustsFontForContentSizeCategory = true
        return label
    }

    // MARK: - Styling helpers

    static func applyDarkNavigation(to navigationController: UINavigationController?) {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = background
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [
            .foregroundColor: text,
            .font: roundedFont(.headline, weight: .semibold)
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: text,
            .font: roundedFont(.largeTitle, weight: .bold)
        ]

        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance
        navigationController?.navigationBar.tintColor = text
    }

    static func roundCard(_ view: UIView, radius: CGFloat = Radius.medium) {
        view.backgroundColor = card
        view.layer.cornerRadius = radius
        view.layer.cornerCurve = .continuous
        view.layer.borderWidth = 1
        view.layer.borderColor = separator.cgColor
        view.clipsToBounds = true
    }

    static func styleTextField(_ textField: UITextField, placeholder: String) {
        textField.borderStyle = .none
        textField.backgroundColor = card
        textField.textColor = text
        textField.tintColor = neonPink
        textField.font = .preferredFont(forTextStyle: .body)
        textField.adjustsFontForContentSizeCategory = true
        textField.layer.cornerRadius = Radius.small + 2
        textField.layer.cornerCurve = .continuous
        textField.layer.borderWidth = 1
        textField.layer.borderColor = separator.cgColor
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 1))
        textField.leftViewMode = .always
        textField.clearButtonMode = .whileEditing
        textField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: tertiaryText]
        )
        textField.autocorrectionType = .no
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.heightAnchor.constraint(greaterThanOrEqualToConstant: 52).isActive = true

        // Accent border while focused.
        textField.addAction(UIAction { [weak textField] _ in
            textField?.layer.borderColor = neonPink.withAlphaComponent(0.8).cgColor
        }, for: .editingDidBegin)
        textField.addAction(UIAction { [weak textField] _ in
            textField?.layer.borderColor = separator.cgColor
        }, for: .editingDidEnd)
    }

    /// Circular initial badge used for member avatars.
    static func makeAvatarLabel(text: String, size: CGFloat, fontSize: CGFloat, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: fontSize, weight: .bold).rounded
        label.textColor = .white
        label.textAlignment = .center
        label.backgroundColor = color
        label.layer.cornerRadius = size / 2
        label.clipsToBounds = true
        label.isAccessibilityElement = false
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.widthAnchor.constraint(equalToConstant: size),
            label.heightAnchor.constraint(equalToConstant: size)
        ])
        return label
    }

    static func applyTextShadow(to label: UILabel, opacity: Float, radius: CGFloat = 4) {
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOpacity = opacity
        label.layer.shadowRadius = radius
        label.layer.shadowOffset = CGSize(width: 0, height: 1)
    }
}

extension UIFont {
    func withWeight(_ weight: UIFont.Weight) -> UIFont {
        let descriptor = fontDescriptor.addingAttributes([
            .traits: [UIFontDescriptor.TraitKey.weight: weight]
        ])
        return UIFont(descriptor: descriptor, size: pointSize)
    }

    var rounded: UIFont {
        guard let descriptor = fontDescriptor.withDesign(.rounded) else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}

/// Lightweight haptic feedback helpers.
enum Haptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
