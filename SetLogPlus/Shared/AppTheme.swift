import UIKit

enum AppTheme {
    static let background = UIColor.black
    static let card = UIColor(white: 0.08, alpha: 1)
    static let cardMuted = UIColor(white: 0.13, alpha: 1)
    static let neonPink = UIColor(red: 0.94, green: 0.35, blue: 0.98, alpha: 1)
    static let mint = UIColor(red: 1.0, green: 0.86, blue: 0.38, alpha: 1)
    static let purple = UIColor(red: 0.70, green: 0.55, blue: 0.96, alpha: 1)
    static let lavender = UIColor(red: 0.82, green: 0.72, blue: 1.0, alpha: 1)
    static let butter = UIColor(red: 1.0, green: 0.91, blue: 0.54, alpha: 1)
    static let text = UIColor.white
    static let secondaryText = UIColor(white: 0.72, alpha: 1)

    static func applyDarkNavigation(to navigationController: UINavigationController?) {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = background
        appearance.titleTextAttributes = [.foregroundColor: text]
        appearance.largeTitleTextAttributes = [.foregroundColor: text]

        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.tintColor = text
    }

    static func roundCard(_ view: UIView, radius: CGFloat = 18) {
        view.backgroundColor = card
        view.layer.cornerRadius = radius
        view.clipsToBounds = true
    }

    static func styleTextField(_ textField: UITextField, placeholder: String) {
        textField.borderStyle = .none
        textField.backgroundColor = card
        textField.textColor = text
        textField.tintColor = neonPink
        textField.layer.cornerRadius = 14
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        textField.leftViewMode = .always
        textField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.45)]
        )
        textField.autocorrectionType = .no
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.heightAnchor.constraint(equalToConstant: 48).isActive = true
    }

    /// Circular initial badge used for member avatars.
    static func makeAvatarLabel(text: String, size: CGFloat, fontSize: CGFloat, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: fontSize, weight: .black)
        label.textColor = .white
        label.textAlignment = .center
        label.backgroundColor = color
        label.layer.cornerRadius = size / 2
        label.clipsToBounds = true
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
