import UIKit
import BackgroundTasks

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    var dataSharingVC: DataSharingViewController?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {    // Override point for customization after application launch.
        setupAppearance()
        
        dataSharingVC = DataSharingViewController()
        
        // Register for remote notifications if needed
        application.registerForRemoteNotifications()
        
        // Register background task
            BGTaskScheduler.shared.register(
                forTaskWithIdentifier: backgroundTaskIdentifier,
                using: nil
            ) { task in
                self.handleBackgroundTask(task as! BGProcessingTask)
            }
        
        // Register background task for updating registered amount
           BGTaskScheduler.shared.register(
               forTaskWithIdentifier: updateAmountBackgroundTaskIdentifier,
               using: nil
           ) { task in
               self.handleUpdateAmountBackgroundTask(task as! BGProcessingTask)
           }
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
               if granted {
                   print("Notification permission granted")
               } else if let error = error {
                   print("Error requesting notification permission: \(error)")
               }
           }
        
        return true
    }
    
    func handleBackgroundTask(_ task: BGProcessingTask) {
        // Schedule the next background task
        scheduleBackgroundTask()
        
        task.expirationHandler = {
            // Handle task expiration
            task.setTaskCompleted(success: false)
        }
        
        // Perform your background work here
        // When done, call:
        task.setTaskCompleted(success: true)
    }
    
    func handleUpdateAmountBackgroundTask(_ task: BGProcessingTask) {
        scheduleUpdateAmountBackgroundTask()
        
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        // Perform background work
        task.setTaskCompleted(success: true)
    }
    
    func scheduleBackgroundTask() {
        let request = BGProcessingTaskRequest(identifier: backgroundTaskIdentifier)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule background task: \(error)")
        }
    }
    
    func scheduleUpdateAmountBackgroundTask() {
        let request = BGProcessingTaskRequest(identifier: updateAmountBackgroundTaskIdentifier)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule update amount background task: \(error)")
        }
    }

    // MARK: - Background Task Handling
    
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // This is where you would perform any background data fetching
        // For example, syncing data with a server, fetching updates, etc.
        // Call completionHandler(.newData) if new data is available, otherwise .noData or .failed
        
        completionHandler(.newData) // Assuming new data is fetched successfully
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // Handle remote notifications for background fetch
        // This could include fetching data related to the notification
        completionHandler(.newData)
    }
    
    // MARK: - UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
    }

    // MARK: - Appearance Setup

    private func setupAppearance() {
        if #available(iOS 13.0, *) {
            let appearance = UITabBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundColor = UIColor.clear

            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        } else {
            UITabBar.appearance().barTintColor = UIColor.clear
            UITabBar.appearance().isTranslucent = true
        }
    }

    // MARK: - Application Lifecycle

    func applicationWillTerminate(_ application: UIApplication) {
        // Save changes in the application's managed object context when the application terminates.
        CoreDataStack.shared.saveContext()
    }
    
    struct AppUtility {
            static func lockOrientation(_ orientation: UIInterfaceOrientationMask) {
                if let delegate = UIApplication.shared.delegate as? AppDelegate {
                    delegate.orientationLock = orientation
                }
            }
        }

        var orientationLock = UIInterfaceOrientationMask.portrait

        func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
            return orientationLock
        }
}
