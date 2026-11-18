import UIKit

/// Compact floating emoji bar (like a message "tapback") shown next to the button that opened it.
/// Tapping outside dismisses it; tapping the current reaction again removes it.
final class ReactionPickerViewController: UIViewController {
    private let emojis: [String]
    private let currentEmoji: String?
    private weak var sourceView: UIView?
    private let onSelect: (String) -> Void

    private let barView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThickMaterialDark))
    private let stackView = UIStackView()

    init(emojis: [String], currentEmoji: String?, sourceView: UIView?, onSelect: @escaping (String) -> Void) {
        self.emojis = emojis
        self.currentEmoji = currentEmoji
        self.sourceView = sourceView
        self.onSelect = onSelect
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.15)

        let dismissTap = UITapGestureRecognizer(target: self, action: #selector(dismissTapped))
        dismissTap.cancelsTouchesInView = false
        view.addGestureRecognizer(dismissTap)

        barView.layer.cornerRadius = 30
        barView.layer.cornerCurve = .continuous
        barView.layer.borderWidth = 1
        barView.layer.borderColor = AppTheme.separator.cgColor
        barView.clipsToBounds = true
        view.addSubview(barView)

        stackView.axis = .horizontal
        stackView.spacing = 4
        stackView.translatesAutoresizingMaskIntoConstraints = false
        barView.contentView.addSubview(stackView)

        emojis.forEach { stackView.addArrangedSubview(makeEmojiButton($0)) }

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: barView.contentView.topAnchor, constant: 6),
            stackView.bottomAnchor.constraint(equalTo: barView.contentView.bottomAnchor, constant: -6),
            stackView.leadingAnchor.constraint(equalTo: barView.contentView.leadingAnchor, constant: 8),
            stackView.trailingAnchor.constraint(equalTo: barView.contentView.trailingAnchor, constant: -8)
        ])

        view.accessibilityViewIsModal = true
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        positionBar()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Haptics.tap()
        // Pop the emojis in one after another.
        for (index, button) in stackView.arrangedSubviews.enumerated() {
            button.transform = CGAffineTransform(scaleX: 0.4, y: 0.4)
            button.alpha = 0
            UIView.animate(
                withDuration: 0.35,
                delay: Double(index) * 0.03,
                usingSpringWithDamping: 0.6,
                initialSpringVelocity: 0.5
            ) {
                button.transform = .identity
                button.alpha = 1
            }
        }
    }

    /// Places the bar above the source view (or below if there's no room), kept inside the safe area.
    private func positionBar() {
        let size = barView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        let safeFrame = view.bounds.inset(by: view.safeAreaInsets).insetBy(dx: 12, dy: 8)

        var anchorRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        if let sourceView, sourceView.window != nil {
            anchorRect = sourceView.convert(sourceView.bounds, to: view)
        }

        var x = anchorRect.midX - size.width / 2
        x = min(max(x, safeFrame.minX), safeFrame.maxX - size.width)

        var y = anchorRect.minY - size.height - 10
        if y < safeFrame.minY {
            y = anchorRect.maxY + 10
        }
        barView.frame = CGRect(x: x, y: y, width: size.width, height: size.height)
    }

    private func makeEmojiButton(_ emoji: String) -> UIButton {
        let isCurrent = emoji == currentEmoji

        var configuration = UIButton.Configuration.plain()
        configuration.title = emoji
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6)
        configuration.background.cornerRadius = 24
        configuration.background.backgroundColor = isCurrent ? AppTheme.neonPink.withAlphaComponent(0.3) : .clear
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = .systemFont(ofSize: 28)
            return attributes
        }

        let button = UIButton(configuration: configuration)
        button.accessibilityLabel = isCurrent ? "\(emoji) 반응 취소" : "\(emoji) 반응 남기기"
        button.enablePressAnimation(scale: 1.25)
        button.addAction(UIAction { [weak self] _ in
            self?.select(emoji, button: button)
        }, for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 48),
            button.heightAnchor.constraint(equalToConstant: 48)
        ])
        return button
    }

    private func select(_ emoji: String, button: UIButton) {
        Haptics.selection()
        let onSelect = onSelect
        UIView.animate(withDuration: 0.15, animations: {
            button.transform = CGAffineTransform(scaleX: 1.4, y: 1.4).translatedBy(x: 0, y: -4)
        }, completion: { _ in
            self.dismiss(animated: true) {
                onSelect(emoji)
            }
        })
    }

    @objc private func dismissTapped(_ gesture: UITapGestureRecognizer) {
        guard !barView.frame.contains(gesture.location(in: view)) else { return }
        dismiss(animated: true)
    }
}
