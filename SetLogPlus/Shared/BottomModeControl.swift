import UIKit

/// Floating "카메라 | 로그" switcher shown at the bottom of the main screens.
final class BottomModeControl: UIView {
    var onCameraTapped: (() -> Void)?
    var onLogTapped: (() -> Void)?

    private let selectedIndex: Int
    private let indicatorView = UIView()
    private var buttons: [UIButton] = []

    init(leftTitle: String = "카메라", rightTitle: String = "로그", selectedIndex: Int = 1) {
        self.selectedIndex = selectedIndex
        super.init(frame: .zero)
        setup(leftTitle: leftTitle, rightTitle: rightTitle)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup(leftTitle: String, rightTitle: String) {
        backgroundColor = AppTheme.card.withAlphaComponent(0.92)
        layer.cornerRadius = 30
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = AppTheme.separator.cgColor
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.5
        layer.shadowRadius = 16
        layer.shadowOffset = CGSize(width: 0, height: 6)

        indicatorView.backgroundColor = AppTheme.cardMuted
        indicatorView.layer.cornerRadius = 25
        indicatorView.layer.cornerCurve = .continuous
        indicatorView.isUserInteractionEnabled = false
        indicatorView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(indicatorView)

        let leftButton = makeButton(title: leftTitle, systemName: "camera.fill", index: 0)
        let rightButton = makeButton(title: rightTitle, systemName: "square.grid.2x2.fill", index: 1)
        buttons = [leftButton, rightButton]

        let stackView = UIStackView(arrangedSubviews: buttons)
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        let selectedButton = buttons[min(max(selectedIndex, 0), buttons.count - 1)]

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 5),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -5),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 5),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5),
            heightAnchor.constraint(equalToConstant: 60),
            widthAnchor.constraint(equalToConstant: 200),

            indicatorView.topAnchor.constraint(equalTo: selectedButton.topAnchor),
            indicatorView.bottomAnchor.constraint(equalTo: selectedButton.bottomAnchor),
            indicatorView.leadingAnchor.constraint(equalTo: selectedButton.leadingAnchor),
            indicatorView.trailingAnchor.constraint(equalTo: selectedButton.trailingAnchor)
        ])

        accessibilityElements = buttons
    }

    private func makeButton(title: String, systemName: String, index: Int) -> UIButton {
        let isSelected = index == selectedIndex

        var configuration = UIButton.Configuration.plain()
        configuration.title = title
        configuration.image = UIImage(systemName: systemName)
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        configuration.imagePadding = 6
        configuration.baseForegroundColor = isSelected ? AppTheme.text : AppTheme.tertiaryText
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = AppTheme.roundedFont(.subheadline, weight: isSelected ? .bold : .semibold)
            return attributes
        }

        let button = UIButton(configuration: configuration)
        button.accessibilityTraits = isSelected ? [.button, .selected] : .button
        button.enablePressAnimation()
        button.addAction(UIAction { [weak self] _ in
            self?.handleTap(index: index)
        }, for: .touchUpInside)
        return button
    }

    private func handleTap(index: Int) {
        guard index != selectedIndex else { return }
        Haptics.selection()

        // Slide the indicator toward the tapped side before the screen switches.
        let target = buttons[index]
        UIView.animate(withDuration: 0.18, delay: 0, options: .curveEaseOut) {
            self.indicatorView.frame = target.convert(target.bounds, to: self)
        }

        if index == 0 {
            onCameraTapped?()
        } else {
            onLogTapped?()
        }
    }
}
