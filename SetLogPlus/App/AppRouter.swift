import UIKit

enum AppRouter {
    static func makeLoginNavigationController() -> UINavigationController {
        UINavigationController(rootViewController: LoginViewController())
    }

    static func makeMainNavigationController() -> UINavigationController {
        UINavigationController(rootViewController: FeedViewController())
    }

    static func showMainApp(from viewController: UIViewController) {
        replaceRoot(from: viewController, with: makeMainNavigationController())
    }

    static func showLog(from viewController: UIViewController) {
        replaceRoot(from: viewController, with: UINavigationController(rootViewController: FeedViewController()))
    }

    static func showGroupFeed(from viewController: UIViewController, group: Group) {
        let feedViewController = FeedViewController()
        let groupFeedViewController = GroupFeedViewController(group: group)
        let navigationController = UINavigationController(rootViewController: feedViewController)
        navigationController.setViewControllers([feedViewController, groupFeedViewController], animated: false)
        replaceRoot(from: viewController, with: navigationController)
    }

    static func showCamera(from viewController: UIViewController) {
        replaceRoot(from: viewController, with: UINavigationController(rootViewController: UploadViewController()))
    }

    static func showLogin(from viewController: UIViewController) {
        replaceRoot(from: viewController, with: makeLoginNavigationController())
    }

    private static func replaceRoot(from viewController: UIViewController, with rootViewController: UIViewController) {
        guard let window = viewController.view.window else { return }

        UIView.transition(with: window, duration: 0.25, options: .transitionCrossDissolve) {
            window.rootViewController = rootViewController
        }
    }
}
