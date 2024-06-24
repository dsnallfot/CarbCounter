//
//  MealHistory+CoreDataProperties.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-06-24.
//
//

import Foundation
import CoreData


extension MealHistory {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<MealHistory> {
        return NSFetchRequest<MealHistory>(entityName: "MealHistory")
    }

    @NSManaged public var mealDate: Date?
    @NSManaged public var totalNetCarbs: Double
    @NSManaged public var totalNetFat: Double
    @NSManaged public var totalNetProtein: Double
    @NSManaged public var id: UUID?
    @NSManaged public var foodEntries: NSSet?

}

// MARK: Generated accessors for foodEntries
extension MealHistory {

    @objc(addFoodEntriesObject:)
    @NSManaged public func addToFoodEntries(_ value: FoodItemEntry)

    @objc(removeFoodEntriesObject:)
    @NSManaged public func removeFromFoodEntries(_ value: FoodItemEntry)

    @objc(addFoodEntries:)
    @NSManaged public func addToFoodEntries(_ values: NSSet)

    @objc(removeFoodEntries:)
    @NSManaged public func removeFromFoodEntries(_ values: NSSet)

}
