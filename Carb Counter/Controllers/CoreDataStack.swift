import CoreData
import CloudKit

class CoreDataStack {
    static let shared = CoreDataStack()
    let persistentContainer: NSPersistentCloudKitContainer

    init() {
        // Register CKShareTransformer
        CKShareTransformer.register()
        
        // Use your Core Data model name
        persistentContainer = NSPersistentCloudKitContainer(name: "CarbsCounter")

        // Configure the persistent store description
        guard let description = persistentContainer.persistentStoreDescriptions.first else {
            fatalError("No Descriptions Found")
        }

        // Set the CloudKit container options
        let options = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.dsnallfot.CarbContainer")
        options.databaseScope = .private // or .shared if needed
        description.cloudKitContainerOptions = options

        // Enable persistent history tracking
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)

        // Enable remote change notifications
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(processRemoteStoreChange),
            name: .NSPersistentStoreRemoteChange,
            object: persistentContainer.persistentStoreCoordinator
        )

        // Load the persistent stores
        persistentContainer.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                // Handle error appropriately
                fatalError("Unresolved error \(error), \(error.userInfo)")
            } else {
                // Successfully loaded the store
                self.persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
            }
        }
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
        let context = persistentContainer.viewContext
        context.perform {
            // Merge changes into the context
            context.mergeChanges(fromContextDidSave: notification)
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
