//
//  FoodItemEntry+CoreDataProperties.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-06-25.
//
//

import Foundation
import CoreData


extension FoodItemEntry {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<FoodItemEntry> {
        return NSFetchRequest<FoodItemEntry>(entityName: "FoodItemEntry")
    }

    @NSManaged public var entryCarbohydrates: Double
    @NSManaged public var entryCarbsPP: Double
    @NSManaged public var entryFat: Double
    @NSManaged public var entryFatPP: Double
    @NSManaged public var entryFoodItem: String?
    @NSManaged public var entryEmoji: String?
    @NSManaged public var entryName: String?
    @NSManaged public var entryNotEaten: Double
    @NSManaged public var entryPerPiece: Bool
    @NSManaged public var entryPortionServed: Double
    @NSManaged public var entryProtein: Double
    @NSManaged public var entryProteinPP: Double
    @NSManaged public var entryId: UUID?
    @NSManaged public var mealHistory: MealHistory?

}
