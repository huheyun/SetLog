//
//  SceneDelegate.swift
//  SetLogPlus
//
//  Created by hyeon on 6/7/26.
//

import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        window.overrideUserInterfaceStyle = .dark
        window.rootViewController = AppRouter.makeInitialViewController()
        self.window = window
        window.makeKeyAndVisible()
    }
}
