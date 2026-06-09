import UIKit

enum ToastView {
    static func show(message: String, in view: UIView) {
        let label = PaddedLabel()
        label.contentInsets = UIEdgeInsets(top: 10, left: 18, bottom: 10, right: 18)
        label.text = message
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.backgroundColor = UIColor(white: 0.12, alpha: 0.94)
        label.layer.cornerRadius = 16
        label.clipsToBounds = true
        label.alpha = 0
        label.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -28),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 28),
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -28),
            label.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])

        UIView.animate(withDuration: 0.2) {
            label.alpha = 1
            label.transform = CGAffineTransform(translationX: 0, y: -6)
        } completion: { _ in
            UIView.animate(withDuration: 0.2, delay: 1.15) {
                label.alpha = 0
                label.transform = .identity
            } completion: { _ in
                label.removeFromSuperview()
            }
        }
    }
}

private final class PaddedLabel: UILabel {
    var contentInsets = UIEdgeInsets.zero {
        didSet {
            invalidateIntrinsicContentSize()
        }
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: contentInsets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + contentInsets.left + contentInsets.right,
            height: size.height + contentInsets.top + contentInsets.bottom
        )
    }
}
