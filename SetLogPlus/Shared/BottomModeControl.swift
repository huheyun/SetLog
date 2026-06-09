import UIKit

final class BottomModeControl: UIView {
    var onCameraTapped: (() -> Void)?
    var onLogTapped: (() -> Void)?

    init(leftTitle: String = "카메라", rightTitle: String = "로그", selectedIndex: Int = 1) {
        super.init(frame: .zero)
        setup(leftTitle: leftTitle, rightTitle: rightTitle, selectedIndex: selectedIndex)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup(leftTitle: String, rightTitle: String, selectedIndex: Int) {
        backgroundColor = AppTheme.card
        layer.cornerRadius = 24

        let leftButton = makeButton(text: leftTitle, isSelected: selectedIndex == 0, action: #selector(cameraTapped))
        let rightButton = makeButton(text: rightTitle, isSelected: selectedIndex == 1, action: #selector(logTapped))

        let stackView = UIStackView(arrangedSubviews: [leftButton, rightButton])
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            heightAnchor.constraint(equalToConstant: 52),
            widthAnchor.constraint(equalToConstant: 150)
        ])
    }

    private func makeButton(text: String, isSelected: Bool, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(text, for: .normal)
        button.setTitleColor(AppTheme.text, for: .normal)
        button.titleLabel?.font = .preferredFont(forTextStyle: .subheadline)
        button.backgroundColor = isSelected ? AppTheme.cardMuted : .clear
        button.layer.cornerRadius = 22
        button.clipsToBounds = true
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    @objc private func cameraTapped() {
        onCameraTapped?()
    }

    @objc private func logTapped() {
        onLogTapped?()
    }
}
