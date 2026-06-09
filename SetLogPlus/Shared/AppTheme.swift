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
}
