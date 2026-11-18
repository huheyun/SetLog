import UIKit

/// Non-interactive vertical black gradient used to keep text legible over video.
/// Used by the group feed clip cards and the video detail screen.
final class VideoGradientView: UIView {
    enum Direction {
        /// Transparent at the top, dark at the bottom.
        case bottomUp
        /// Dark at the top, transparent at the bottom.
        case topDown
    }

    init(direction: Direction, maxAlpha: CGFloat = 0.72) {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        translatesAutoresizingMaskIntoConstraints = false

        let dark = UIColor.black.withAlphaComponent(maxAlpha).cgColor
        let mid = UIColor.black.withAlphaComponent(maxAlpha * 0.45).cgColor
        let clear = UIColor.black.withAlphaComponent(0).cgColor
        switch direction {
        case .bottomUp:
            gradientLayer.colors = [clear, mid, dark]
        case .topDown:
            gradientLayer.colors = [dark, mid, clear]
        }
        gradientLayer.locations = [0, 0.5, 1]
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override class var layerClass: AnyClass {
        CAGradientLayer.self
    }

    private var gradientLayer: CAGradientLayer {
        layer as! CAGradientLayer
    }
}
