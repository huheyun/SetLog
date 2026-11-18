import UIKit

enum AppRouter {
    static func makeInitialViewController() -> UIViewController {
        AuthService.shared.isSignedIn ? makeLogNavigationController() : makeLoginNavigationController()
    }

    static func showLog(from viewController: UIViewController) {
        replaceRoot(from: viewController, with: makeLogNavigationController())
    }

    static func showGroupFeed(from viewController: UIViewController, group: Group) {
        let navigationController = makeLogNavigationController()
        navigationController.pushViewController(GroupFeedViewController(group: group), animated: false)
        replaceRoot(from: viewController, with: navigationController)
    }

    static func showCamera(from viewController: UIViewController) {
        replaceRoot(from: viewController, with: UINavigationController(rootViewController: UploadViewController()))
    }

    static func showLogin(from viewController: UIViewController) {
        replaceRoot(from: viewController, with: makeLoginNavigationController())
    }

    private static func makeLoginNavigationController() -> UINavigationController {
        UINavigationController(rootViewController: LoginViewController())
    }

    private static func makeLogNavigationController() -> UINavigationController {
        UINavigationController(rootViewController: FeedViewController())
    }

    private static func replaceRoot(from viewController: UIViewController, with rootViewController: UIViewController) {
        guard let window = viewController.view.window else { return }

        UIView.transition(with: window, duration: 0.25, options: .transitionCrossDissolve) {
            window.rootViewController = rootViewController
        }
    }
}
