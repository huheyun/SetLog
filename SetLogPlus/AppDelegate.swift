//
//  AppDelegate.swift
//  SetLogPlus
//
//  Created by hyeon on 6/7/26.
//

import FirebaseCore
import UIKit
import UserNotifications

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        FirebaseApp.configure()
        // Must be set before launch finishes so taps that launched the app are delivered.
        UNUserNotificationCenter.current().delegate = self
        ReminderService.reschedule()
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    // MARK: Reminder routing

    private var sceneActivationObserver: NSObjectProtocol?

    fileprivate func routeToCamera() {
        guard AuthService.shared.isSignedIn else { return }

        guard let rootViewController = Self.activeRootViewController() else {
            // Cold launch: the scene may not have a window yet. Retry once it becomes active.
            guard sceneActivationObserver == nil else { return }
            sceneActivationObserver = NotificationCenter.default.addObserver(
                forName: UIScene.didActivateNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    if let observer = self.sceneActivationObserver {
                        NotificationCenter.default.removeObserver(observer)
                    }
                    self.sceneActivationObserver = nil
                    if let rootViewController = Self.activeRootViewController() {
                        Self.showCamera(from: rootViewController)
                    }
                }
            }
            return
        }

        Self.showCamera(from: rootViewController)
    }

    private static func showCamera(from rootViewController: UIViewController) {
        // Already on the camera screen — nothing to do.
        if let navigationController = rootViewController as? UINavigationController,
           navigationController.viewControllers.first is UploadViewController {
            return
        }
        AppRouter.showCamera(from: rootViewController)
    }

    private static func activeRootViewController() -> UIViewController? {
        let windowScenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = windowScenes.first { $0.activationState == .foregroundActive } ?? windowScenes.first
        let window = scene?.keyWindow ?? scene?.windows.first
        guard let rootViewController = window?.rootViewController, rootViewController.view.window != nil else {
            return nil
        }
        return rootViewController
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let identifier = response.notification.request.identifier
        guard ReminderService.isReminderIdentifier(identifier),
              response.actionIdentifier == UNNotificationDefaultActionIdentifier else {
            return
        }
        await routeToCamera()
    }
}
