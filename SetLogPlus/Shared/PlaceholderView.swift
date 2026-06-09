import UIKit

final class PlaceholderView: UIView {
    init(title: String, message: String, systemImageName: String? = nil) {
        super.init(frame: .zero)
        setup(title: title, message: message, systemImageName: systemImageName)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup(title: String, message: String, systemImageName: String?) {
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 8

        let imageView = UIImageView()
        imageView.image = systemImageName.flatMap { UIImage(systemName: $0) }
        imageView.tintColor = .secondaryLabel
        imageView.contentMode = .scaleAspectFit
        imageView.heightAnchor.constraint(equalToConstant: systemImageName == nil ? 0 : 36).isActive = true

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.font = .preferredFont(forTextStyle: .subheadline)
        messageLabel.textColor = .secondaryLabel
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        let stackView = UIStackView(arrangedSubviews: [imageView, titleLabel, messageLabel])
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}
