import AVFoundation
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    //private var backgroundEnterTime: Date?
    private var shouldOpenScanner = false
    private var shouldOpenAddFood = false

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        window = UIWindow(windowScene: windowScene)
        
        // Set up localized shortcuts
           setupLocalizedShortcuts()
        
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
        if shortcutItem.type == "com.dsnallfot.CarbsCounter.addFood" {
            shouldOpenAddFood = true
        }
    }
    
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let urlContext = URLContexts.first else { return }
        
        let url = urlContext.url
        print("Received URL in SceneDelegate: \(url.absoluteString)")
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.host else {
            print("Invalid URL or missing host")
            return
        }

        print("URL Host: \(host)")

        switch host {
        case "success":
            NotificationCenter.default.post(name: NSNotification.Name("ShortcutSuccess"), object: nil)
            print("Posted success notification")
        case "error":
            NotificationCenter.default.post(name: NSNotification.Name("ShortcutError"), object: nil)
            print("Posted error notification")
        case "cancel":
            NotificationCenter.default.post(name: NSNotification.Name("ShortcutCancel"), object: nil)
            print("Posted cancel notification")
        case "passcode":
            NotificationCenter.default.post(name: NSNotification.Name("ShortcutPasscode"), object: nil)
            print("Posted passcode notification")
        default:
            print("Unhandled URL scheme host: \(host)")
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
        if shouldOpenAddFood {
            openAddFoodItemViewController()
            shouldOpenScanner = false
        }
    }
    
    private func setupLocalizedShortcuts() {
        let scanBarcodeShortcut = UIApplicationShortcutItem(
            type: "com.dsnallfot.CarbsCounter.scanBarcode",
            localizedTitle: NSLocalizedString("SCAN_BARCODE_KEY", comment: "Scan barcode shortcut"),
            localizedSubtitle: nil,
            icon: UIApplicationShortcutIcon(systemImageName: "barcode.viewfinder"),
            userInfo: nil
        )
        
        let addFoodShortcut = UIApplicationShortcutItem(
            type: "com.dsnallfot.CarbsCounter.addFood",
            localizedTitle: NSLocalizedString("ADD_FOOD_KEY", comment: "Add food shortcut"),
            localizedSubtitle: nil,
            icon: UIApplicationShortcutIcon(systemImageName: "plus.circle"),
            userInfo: nil
        )
        
        UIApplication.shared.shortcutItems = [scanBarcodeShortcut, addFoodShortcut]
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
    
    private func openAddFoodItemViewController() {
        // Assuming the storyboard is named "Main" and the identifier for the AddFoodItemViewController is "AddFoodItemViewController"
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let addFoodVC = storyboard.instantiateViewController(withIdentifier: "AddFoodItemViewController") as! AddFoodItemViewController
        let navigationController = UINavigationController(rootViewController: addFoodVC)
        navigationController.modalPresentationStyle = .pageSheet

        if let tabBarController = window?.rootViewController as? UITabBarController,
           let selectedVC = tabBarController.selectedViewController {
            selectedVC.present(navigationController, animated: true, completion: nil)
        }
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
        /*if let backgroundEnterTime = backgroundEnterTime {
            let timeInterval = Date().timeIntervalSince(backgroundEnterTime)
            if timeInterval > 900 { // Check if app was in background for more than 15 minutes (900 seconds)
                resetToHomeViewController()
            }
            self.backgroundEnterTime = nil
        }*/
    }
    

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
        
        // Check if we should open the scanner when returning from background
        if shouldOpenScanner {
            openScannerViewController()
            shouldOpenScanner = false
        }
        
        if shouldOpenAddFood {
            openAddFoodItemViewController()
            shouldOpenAddFood = false
        }
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.

        // Save the time when the app enters the background
        //backgroundEnterTime = Date()

        // Save changes in the application's managed object context when the application transitions to the background.
        (UIApplication.shared.delegate as? CoreDataStack)?.saveContext()
    }

    /*private func resetToHomeViewController() {
        if let tabBarController = window?.rootViewController as? UITabBarController {
            
            // Add a transition animation
            let transition = CATransition()
            transition.type = .fade
            transition.duration = 0.5
            window?.layer.add(transition, forKey: kCATransition)
            
            // Reset to the first tab (home)
            tabBarController.selectedIndex = 0
        }
    }*/
}
