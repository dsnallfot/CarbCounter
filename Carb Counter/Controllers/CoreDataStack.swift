import CoreData
import CloudKit

class CoreDataStack {
    static let shared = CoreDataStack()
    let persistentContainer: NSPersistentCloudKitContainer

    init() {
        // Register CKShareTransformer
        CKShareTransformer.register()

        // Initialize the persistent container with your Core Data model name
        persistentContainer = NSPersistentCloudKitContainer(name: "CarbsCounter")

        // Get the private store description
        guard let privateStoreDescription = persistentContainer.persistentStoreDescriptions.first else {
            fatalError("No persistent store descriptions found")
        }

        // Configure the private store
        let privateOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.dsnallfot.CarbContainer")
        privateOptions.databaseScope = .private
        privateStoreDescription.cloudKitContainerOptions = privateOptions
        privateStoreDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        privateStoreDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        privateStoreDescription.configuration = "PrivateCloudkit"

        // Create a shared store description
        let sharedStoreURL = NSPersistentContainer.defaultDirectoryURL().appendingPathComponent("Shared.sqlite")
        let sharedStoreDescription = NSPersistentStoreDescription(url: sharedStoreURL)
        let sharedOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.dsnallfot.CarbContainer")
        sharedOptions.databaseScope = .shared
        sharedStoreDescription.cloudKitContainerOptions = sharedOptions
        sharedStoreDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        sharedStoreDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        sharedStoreDescription.configuration = "SharedCloudkit"

        // Add the shared store description to the persistent container
        persistentContainer.persistentStoreDescriptions.append(sharedStoreDescription)

        // Load both stores
        persistentContainer.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            } else {
                storeDescription.shouldAddStoreAsynchronously = false
                storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
                storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            }
        }

        // Set merge policies
        persistentContainer.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        persistentContainer.viewContext.automaticallyMergesChangesFromParent = true

        // Observe remote change notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(processRemoteStoreChange),
            name: .NSPersistentStoreRemoteChange,
            object: persistentContainer.persistentStoreCoordinator
        )
    }

    // Access the main context
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }

    func saveContext() {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
                print("Context saved successfully.")
            } catch {
                let nserror = error as NSError
                // Handle the error appropriately
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }

    @objc
    func processRemoteStoreChange(notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        let context = persistentContainer.viewContext
        context.perform {
            // Merge changes into the context
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: userInfo, into: [context])

            // Post notification to update UI or fetch data
            NotificationCenter.default.post(name: .dataDidChangeRemotely, object: nil)
        }
    }
}
/*
import CoreData
import CloudKit

class CoreDataStack {
    static let shared = CoreDataStack()

    private init() {
        // Register the CKShare value transformer before initializing the persistent container
        ValueTransformer.setValueTransformer(CKShareTransformer(), forName: NSValueTransformerName("CKShareTransformer"))

        // Initialize the persistent container
        _ = self.persistentContainer
    }

    lazy var persistentContainer: NSPersistentCloudKitContainer = {
        let container = NSPersistentCloudKitContainer(name: "CarbsCounter")

        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("No descriptions found")
        }

        // Set up CloudKit container options
        let options = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.dsnallfot.CarbContainer")
        description.cloudKitContainerOptions = options

        // Enable Persistent History Tracking
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)

        // Set up other persistent store options
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true

        // Load the persistent stores
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                // Handle the error appropriately
                fatalError("Unresolved error \(error), \(error.userInfo)")
            } else {
                // You can print the store description for debugging
                print("Persistent store loaded: \(storeDescription)")
            }
        }

        // Enable automatic merging of changes
        container.viewContext.automaticallyMergesChangesFromParent = true

        // Set the merge policy to handle conflicts
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        return container
    }()

    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }

    func saveContext() {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
                print("Context saved successfully.")
            } catch {
                let nserror = error as NSError
                // Handle the error appropriately
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
    func fetchOrCreateSharedRoot() -> SharedRoot {
            let fetchRequest: NSFetchRequest<SharedRoot> = SharedRoot.fetchRequest()
            do {
                let results = try context.fetch(fetchRequest)
                if let sharedRoot = results.first {
                    return sharedRoot
                } else {
                    let newSharedRoot = SharedRoot(context: context)
                    try context.save()
                    return newSharedRoot
                }
            } catch {
                fatalError("Failed to fetch or create SharedRoot: \(error)")
            }
        }
    }
*/
