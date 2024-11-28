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
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleProductFoundNotification(_:)), name: NSNotification.Name("ProductFound"), object: nil)
    }

    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        handleShortcutItem(shortcutItem)
        completionHandler(true)
    }

    func windowScene(_ windowScene: UIWindowScene,
                         supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
            if let navigationController = window?.rootViewController as? UINavigationController,
               navigationController.visibleViewController is NightscoutWebViewController {
                return .landscape
            }
            return .portrait
        }


    private func handleShortcutItem(_ shortcutItem: UIApplicationShortcutItem) {
        if shortcutItem.type == "com.dsnallfot.CarbsCounter.scanBarcode" {
            shouldOpenScanner = true
        }
        if shortcutItem.type == "com.dsnallfot.CarbsCounter.addFood" {
            shouldOpenAddFood = true
        }
    }
    
    @objc private func handleProductFoundNotification(_ notification: Notification) {
            guard let userInfo = notification.userInfo,
                  let productInfo = userInfo["productInfo"] as? ProductInfo else { return }

            // Dismiss any presented view controller (ScannerViewController)
            if let rootVC = window?.rootViewController {
                rootVC.dismiss(animated: true) {
                    // After dismissing, navigate to AddFoodItemViewController
                    self.navigateToAddFoodItemViewController(with: productInfo)
                }
            } else {
                // If nothing is presented, just navigate
                navigateToAddFoodItemViewController(with: productInfo)
            }
        }
    
    private func navigateToAddFoodItemViewController(with productInfo: ProductInfo) {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            guard let addFoodVC = storyboard.instantiateViewController(withIdentifier: "AddFoodItemViewController") as? AddFoodItemViewController else { return }

            // Populate AddFoodItemViewController with product information
            addFoodVC.prePopulatedData = (
                productInfo.productName,
                productInfo.carbohydrates,
                productInfo.fat,
                productInfo.proteins,
                "", // emoji
                productInfo.isPerPiece ? String(format: NSLocalizedString("Vikt per styck: %.1f g", comment: "Weight info"), productInfo.weightPerPiece) : "",
                productInfo.isPerPiece,
                productInfo.isPerPiece ? productInfo.carbohydrates : 0.0,
                productInfo.isPerPiece ? productInfo.fat : 0.0,
                productInfo.isPerPiece ? productInfo.proteins : 0.0
            )
            addFoodVC.isPerPiece = productInfo.isPerPiece

            // Present AddFoodItemViewController
            let navigationController = UINavigationController(rootViewController: addFoodVC)
            navigationController.modalPresentationStyle = .pageSheet

            if let tabBarController = window?.rootViewController as? UITabBarController,
               let selectedVC = tabBarController.selectedViewController {
                selectedVC.present(navigationController, animated: true, completion: nil)
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
        print("sceneWillEnterForeground triggered")
        
        if shouldOpenScanner {
            openScannerViewController()
            shouldOpenScanner = false
        }
        
        if shouldOpenAddFood {
            openAddFoodItemViewController()
            shouldOpenAddFood = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { // Add slight delay to ensure resources are ready
                guard let window = self.window,
                      let rootViewController = window.rootViewController else {
                    print("Root view controller not found")
                    return
                }

                if let composeMealVC = self.findComposeMealViewController(in: rootViewController) {
                    print("ComposeMealViewController detected, reinitializing view...")
                    composeMealVC.initializeView()
                } else {
                    print("ComposeMealViewController not found in the current view hierarchy.")
                }
            }
    }
    
    private func findComposeMealViewController(in rootViewController: UIViewController) -> ComposeMealViewController? {
        //print("Checking rootViewController: \(type(of: rootViewController))") // Log root type

        if let composeMealVC = rootViewController as? ComposeMealViewController {
            //print("ComposeMealViewController found directly as root.")
            return composeMealVC
        }

        if let navController = rootViewController as? UINavigationController {
            //print("Found UINavigationController, checking its viewControllers.")
            for vc in navController.viewControllers {
                //print("Contained viewController: \(type(of: vc))")
                if let composeMealVC = vc as? ComposeMealViewController {
                    //print("ComposeMealViewController found in UINavigationController.")
                    return composeMealVC
                }
            }
        }

        if let tabBarController = rootViewController as? UITabBarController {
            //print("Found UITabBarController, checking its viewControllers.")
            for vc in tabBarController.viewControllers ?? [] {
                //print("Contained viewController: \(type(of: vc))")
                // Recursively search within the view controllers of each UINavigationController
                if let composeMealVC = findComposeMealViewController(in: vc) {
                    return composeMealVC
                }
            }
        }

        if let presentedVC = rootViewController.presentedViewController {
            //print("Found presented viewController: \(type(of: presentedVC))")
            return findComposeMealViewController(in: presentedVC)
        }

        print("ComposeMealViewController not found in the current hierarchy.")
        return nil
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        print("sceneDidEnterBackground triggered")

        // Save Core Data context
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
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
