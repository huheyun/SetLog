import UIKit

extension UIViewController {
    func showAlert(title: String?, message: String?, completion: (() -> Void)? = nil) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "확인", style: .default) { _ in
            completion?()
        })
        present(alertController, animated: true)
    }

    /// Presents an action sheet anchored to `sourceView` so it doesn't crash on iPad.
    func presentActionSheet(_ alertController: UIAlertController, from sourceView: UIView?) {
        if let popover = alertController.popoverPresentationController {
            let anchorView = sourceView ?? view
            popover.sourceView = anchorView
            popover.sourceRect = anchorView?.bounds ?? .zero
        }
        present(alertController, animated: true)
    }

    func presentReactionPicker(
        currentEmoji: String?,
        from sourceView: UIView?,
        onSelect: @escaping (String) -> Void
    ) {
        let alertController = UIAlertController(title: "반응 남기기", message: nil, preferredStyle: .actionSheet)

        ReactionRepository.availableEmojis.forEach { emoji in
            let title = emoji == currentEmoji ? "\(emoji) 취소" : emoji
            alertController.addAction(UIAlertAction(title: title, style: .default) { _ in
                onSelect(emoji)
            })
        }

        alertController.addAction(UIAlertAction(title: "닫기", style: .cancel))
        presentActionSheet(alertController, from: sourceView)
    }
}
