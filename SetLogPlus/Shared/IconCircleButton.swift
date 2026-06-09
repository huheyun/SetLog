import UIKit

final class IconCircleButton: UIButton {
    init(systemName: String, tintColor: UIColor = AppTheme.text) {
        super.init(frame: .zero)
        setup(systemName: systemName, tintColor: tintColor)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup(systemName: String, tintColor: UIColor) {
        var configuration = UIButton.Configuration.filled()
        configuration.image = UIImage(systemName: systemName)
        configuration.baseBackgroundColor = AppTheme.cardMuted
        configuration.baseForegroundColor = tintColor
        configuration.cornerStyle = .capsule
        self.configuration = configuration
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 44).isActive = true
        heightAnchor.constraint(equalToConstant: 44).isActive = true
    }
}
