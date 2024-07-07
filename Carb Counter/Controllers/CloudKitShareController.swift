import CloudKit
import UIKit
/*
class CloudKitShareController {
    static let shared = CloudKitShareController()
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let sharedDatabase: CKDatabase
    let customZone: CKRecordZone

    private init() {
        self.container = CKContainer(identifier: "iCloud.com.dsnallfot.CarbsCounter")
        self.privateDatabase = container.privateCloudDatabase
        self.sharedDatabase = container.sharedCloudDatabase
        self.customZone = CKRecordZone(zoneName: "CustomZone")
        createCustomZone()
    }

    private func createCustomZone() {
        let modifyZonesOperation = CKModifyRecordZonesOperation(recordZonesToSave: [customZone], recordZoneIDsToDelete: nil)
        modifyZonesOperation.modifyRecordZonesCompletionBlock = { (savedZones, deletedZoneIDs, error) in
            if let error = error {
                print("Error creating custom zone: \(error)")
            } else {
                print("Custom zone created successfully!")
            }
        }
        privateDatabase.add(modifyZonesOperation)
    }*/
/*
    func shareMealHistoryRecord(mealHistory: MealHistory, from viewController: UIViewController, completion: @escaping (CKShare?, URL?, Error?) -> Void) {
        let mealHistoryRecordID = CKRecord.ID(recordName: mealHistory.id!.uuidString, zoneID: customZone.zoneID)
        let mealHistoryRecord = CKRecord(recordType: "MealHistory", recordID: mealHistoryRecordID)
        mealHistoryRecord["id"] = mealHistory.id!.uuidString as CKRecordValue
        mealHistoryRecord["mealDate"] = mealHistory.mealDate! as NSDate
        mealHistoryRecord["totalNetCarbs"] = mealHistory.totalNetCarbs as NSNumber
        mealHistoryRecord["totalNetFat"] = mealHistory.totalNetFat as NSNumber
        mealHistoryRecord["totalNetProtein"] = mealHistory.totalNetProtein as NSNumber

        var foodItemEntryRecords: [CKRecord] = []
        if let foodEntries = mealHistory.foodEntries?.allObjects as? [FoodItemEntry] {
            for foodEntry in foodEntries {
                let foodEntryRecordID = CKRecord.ID(recordName: foodEntry.entryId!.uuidString, zoneID: customZone.zoneID)
                let foodEntryRecord = CKRecord(recordType: "FoodItemEntry", recordID: foodEntryRecordID)
                foodEntryRecord["id"] = foodEntry.entryId!.uuidString as CKRecordValue
                foodEntryRecord["name"] = foodEntry.entryName! as CKRecordValue
                foodEntryRecord["emoji"] = foodEntry.entryEmoji! as CKRecordValue
                foodEntryRecord["carbohydrates"] = foodEntry.entryCarbohydrates as NSNumber
                foodEntryRecord["fat"] = foodEntry.entryFat as NSNumber
                foodEntryRecord["protein"] = foodEntry.entryProtein as NSNumber
                foodEntryRecord["portionServed"] = foodEntry.entryPortionServed as NSNumber
                foodEntryRecord["notEaten"] = foodEntry.entryNotEaten as NSNumber
                foodEntryRecord["carbsPP"] = foodEntry.entryCarbsPP as NSNumber
                foodEntryRecord["fatPP"] = foodEntry.entryFatPP as NSNumber
                foodEntryRecord["proteinPP"] = foodEntry.entryProteinPP as NSNumber
                foodEntryRecord["perPiece"] = foodEntry.entryPerPiece as NSNumber
                foodEntryRecord["mealHistory"] = CKRecord.Reference(recordID: mealHistoryRecordID, action: .deleteSelf)

                foodItemEntryRecords.append(foodEntryRecord)
            }
        }

        let share = CKShare(rootRecord: mealHistoryRecord)
        share[CKShare.SystemFieldKey.title] = "Shared Meal" as CKRecordValue

        let modifyRecordsOperation = CKModifyRecordsOperation(recordsToSave: [mealHistoryRecord, share] + foodItemEntryRecords)
        modifyRecordsOperation.modifyRecordsCompletionBlock = { (savedRecords, deletedRecordIDs, error) in
            completion(share, share.url, error)
        }

        privateDatabase.add(modifyRecordsOperation)
    }
    
    func shareFoodItemRecord(foodItem: FoodItem, from viewController: UIViewController, completion: @escaping (CKShare?, Error?) -> Void) {
        let foodItemRecordID = CKRecord.ID(recordName: foodItem.id!.uuidString, zoneID: customZone.zoneID)
        let foodItemRecord = CKRecord(recordType: "FoodItem", recordID: foodItemRecordID)
        foodItemRecord["id"] = foodItem.id!.uuidString as CKRecordValue
        foodItemRecord["name"] = foodItem.name! as CKRecordValue
        foodItemRecord["emoji"] = foodItem.emoji! as CKRecordValue
        foodItemRecord["notes"] = foodItem.notes! as CKRecordValue
        foodItemRecord["carbohydrates"] = foodItem.carbohydrates as NSNumber
        foodItemRecord["fat"] = foodItem.fat as NSNumber
        foodItemRecord["protein"] = foodItem.protein as NSNumber
        foodItemRecord["carbsPP"] = foodItem.carbsPP as NSNumber
        foodItemRecord["fatPP"] = foodItem.fatPP as NSNumber
        foodItemRecord["proteinPP"] = foodItem.proteinPP as NSNumber
        foodItemRecord["perPiece"] = foodItem.perPiece as NSNumber
        foodItemRecord["count"] = foodItem.count as NSNumber

        let share = CKShare(rootRecord: foodItemRecord)
        share[CKShare.SystemFieldKey.title] = "Shared Food Item" as CKRecordValue

        let modifyRecordsOperation = CKModifyRecordsOperation(recordsToSave: [foodItemRecord, share])
        modifyRecordsOperation.modifyRecordsCompletionBlock = { (savedRecords, deletedRecordIDs, error) in
        }

        privateDatabase.add(modifyRecordsOperation)
    }
    
    func shareFavoriteMealsRecord(favoriteMeals: FavoriteMeals, completion: @escaping (CKShare?, Error?) -> Void) {
            let favoriteMealsRecordID = CKRecord.ID(recordName: favoriteMeals.id!.uuidString, zoneID: customZone.zoneID)
            let favoriteMealsRecord = CKRecord(recordType: "FavoriteMeals", recordID: favoriteMealsRecordID)
            favoriteMealsRecord["id"] = favoriteMeals.id!.uuidString as CKRecordValue
            favoriteMealsRecord["name"] = favoriteMeals.name! as CKRecordValue
            favoriteMealsRecord["items"] = favoriteMeals.items! as! CKRecordValue

            let share = CKShare(rootRecord: favoriteMealsRecord)
            share[CKShare.SystemFieldKey.title] = "Shared Favorite Meals" as CKRecordValue

            let modifyRecordsOperation = CKModifyRecordsOperation(recordsToSave: [favoriteMealsRecord, share])
            modifyRecordsOperation.modifyRecordsCompletionBlock = { (savedRecords, deletedRecordIDs, error) in
                completion(share, error)
        }
        
        privateDatabase.add(modifyRecordsOperation)
    }
    
    func shareCarbRatioScheduleRecord(carbRatioSchedule: CarbRatioSchedule, completion: @escaping (CKShare?, Error?) -> Void) {
        guard let carbRatioScheduleID = carbRatioSchedule.id else {
            completion(nil, NSError(domain: "CloudKitShareController", code: 1, userInfo: [NSLocalizedDescriptionKey: "Carb Ratio Schedule ID is nil"]))
            return
        }

        let carbRatioScheduleRecordID = CKRecord.ID(recordName: carbRatioScheduleID.uuidString, zoneID: customZone.zoneID)
        let carbRatioScheduleRecord = CKRecord(recordType: "CarbRatioSchedule", recordID: carbRatioScheduleRecordID)
        carbRatioScheduleRecord["id"] = carbRatioScheduleID.uuidString as CKRecordValue
        carbRatioScheduleRecord["carbRatio"] = carbRatioSchedule.carbRatio as NSNumber
        carbRatioScheduleRecord["hour"] = carbRatioSchedule.hour as NSNumber

        let share = CKShare(rootRecord: carbRatioScheduleRecord)
        share[CKShare.SystemFieldKey.title] = "Shared Carb Ratio Schedule" as CKRecordValue

        let modifyRecordsOperation = CKModifyRecordsOperation(recordsToSave: [carbRatioScheduleRecord, share])
        modifyRecordsOperation.modifyRecordsCompletionBlock = { (savedRecords, deletedRecordIDs, error) in
            completion(share, error)
        }

        privateDatabase.add(modifyRecordsOperation)
    }

    func shareStartDoseScheduleRecord(startDoseSchedule: StartDoseSchedule, completion: @escaping (CKShare?, Error?) -> Void) {
        guard let startDoseScheduleID = startDoseSchedule.id else {
            completion(nil, NSError(domain: "CloudKitShareController", code: 1, userInfo: [NSLocalizedDescriptionKey: "Start Dose Schedule ID is nil"]))
            return
        }

        let startDoseScheduleRecordID = CKRecord.ID(recordName: startDoseScheduleID.uuidString, zoneID: customZone.zoneID)
        let startDoseScheduleRecord = CKRecord(recordType: "StartDoseSchedule", recordID: startDoseScheduleRecordID)
        startDoseScheduleRecord["id"] = startDoseScheduleID.uuidString as CKRecordValue
        startDoseScheduleRecord["startDose"] = startDoseSchedule.startDose as NSNumber
        startDoseScheduleRecord["hour"] = startDoseSchedule.hour as NSNumber
        let share = CKShare(rootRecord: startDoseScheduleRecord)
        share[CKShare.SystemFieldKey.title] = "Shared Start Dose Schedule" as CKRecordValue

        let modifyRecordsOperation = CKModifyRecordsOperation(recordsToSave: [startDoseScheduleRecord, share])
        modifyRecordsOperation.modifyRecordsCompletionBlock = { (savedRecords, deletedRecordIDs, error) in
            completion(share, error)
        }

        privateDatabase.add(modifyRecordsOperation)
    }

    func acceptShare(from shareURL: URL, completion: @escaping (Error?) -> Void) {
        container.fetchShareMetadata(with: shareURL) { metadata, error in
            guard let metadata = metadata, error == nil else {
                completion(error)
                return
            }

            let acceptShareOperation = CKAcceptSharesOperation(shareMetadatas: [metadata])
            acceptShareOperation.perShareCompletionBlock = { metadata, share, error in
                if let error = error {
                    print("Error accepting share: \(error)")
                }
            }
            acceptShareOperation.acceptSharesCompletionBlock = { error in
                DispatchQueue.main.async {
                    completion(error)
                }
            }
            self.container.add(acceptShareOperation)
        }
    }*/
//}
