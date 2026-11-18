import UIKit

/// A tappable container that shrinks slightly while pressed. Use for cards and rows.
class PressableControl: UIControl {
    var pressedScale: CGFloat = 0.97

    override var isHighlighted: Bool {
        didSet {
            guard isHighlighted != oldValue else { return }
            UIView.animate(
                withDuration: isHighlighted ? 0.12 : 0.28,
                delay: 0,
                usingSpringWithDamping: 0.7,
                initialSpringVelocity: 0,
                options: [.allowUserInteraction, .beginFromCurrentState]
            ) {
                self.transform = self.isHighlighted
                    ? CGAffineTransform(scaleX: self.pressedScale, y: self.pressedScale)
                    : .identity
                self.alpha = self.isHighlighted ? 0.85 : 1
            }
        }
    }
}

extension UIButton {
    /// Adds the same shrink-on-press feedback used by `PressableControl`.
    func enablePressAnimation(scale: CGFloat = 0.94) {
        configurationUpdateHandler = { button in
            let pressed = button.isHighlighted
            UIView.animate(
                withDuration: pressed ? 0.12 : 0.28,
                delay: 0,
                usingSpringWithDamping: 0.7,
                initialSpringVelocity: 0,
                options: [.allowUserInteraction, .beginFromCurrentState]
            ) {
                button.transform = pressed ? CGAffineTransform(scaleX: scale, y: scale) : .identity
            }
        }
    }
}
