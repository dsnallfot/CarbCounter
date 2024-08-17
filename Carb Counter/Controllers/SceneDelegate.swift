import AVFoundation
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private var backgroundEnterTime: Date?
    private var shouldOpenScanner = false

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        window = UIWindow(windowScene: windowScene)
        
        // Check if the app was launched from a quick action
        if let shortcutItem = connectionOptions.shortcutItem {
            handleShortcutItem(shortcutItem)
        }
        
        // Set the LoadingViewController as the initial view controller
        let loadingVC = LoadingViewController()
        window?.rootViewController = loadingVC
        window?.makeKeyAndVisible()
        
        // Simulate some delay to show the loading screen
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.showMainViewController()
        }
    }

    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        handleShortcutItem(shortcutItem)
        completionHandler(true)
    }

    private func handleShortcutItem(_ shortcutItem: UIApplicationShortcutItem) {
        if shortcutItem.type == "com.dsnallfot.CarbsCounter.scanBarcode" {
            shouldOpenScanner = true
        }
    }

    private func showMainViewController() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let mainVC = storyboard.instantiateInitialViewController()
    
        // Ensure that ComposeMealViewController is accessible globally
        if let tabBarController = mainVC as? UITabBarController {
            if let composeMealVC = tabBarController.viewControllers?.compactMap({ $0 as? ComposeMealViewController }).first {
                ComposeMealViewController.shared = composeMealVC
            }
        }
        
        // Add a transition animation
        let transition = CATransition()
        transition.type = .fade
        transition.duration = 0.5
        window?.layer.add(transition, forKey: kCATransition)
        
        window?.rootViewController = mainVC

        // If the quick action was triggered, open the ScannerViewController
        if shouldOpenScanner {
            openScannerViewController()
            shouldOpenScanner = false
        }
    }

    private func openScannerViewController() {
        let scannerVC = ScannerViewController()
        let navigationController = UINavigationController(rootViewController: scannerVC)
        navigationController.modalPresentationStyle = .pageSheet

        if let tabBarController = window?.rootViewController as? UITabBarController,
           let selectedVC = tabBarController.selectedViewController {
            selectedVC.present(navigationController, animated: true, completion: nil)
        }
    }

    // ... (other methods)

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
        
        // Check if we should open the scanner when returning from background
        if shouldOpenScanner {
            openScannerViewController()
            shouldOpenScanner = false
        }
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.

        // Save the time when the app enters the background
        backgroundEnterTime = Date()

        // Save changes in the application's managed object context when the application transitions to the background.
        (UIApplication.shared.delegate as? CoreDataStack)?.saveContext()
    }

    // ... (other methods)
}
