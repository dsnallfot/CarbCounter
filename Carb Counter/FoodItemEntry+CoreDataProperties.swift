//
//  FoodItemEntry+CoreDataProperties.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-06-24.
//
//

import Foundation
import CoreData


extension FoodItemEntry {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<FoodItemEntry> {
        return NSFetchRequest<FoodItemEntry>(entityName: "FoodItemEntry")
    }

    @NSManaged public var foodItem: String?
    @NSManaged public var portionServed: Double
    @NSManaged public var notEaten: Double
    @NSManaged public var name: String?
    @NSManaged public var carbohydrates: Double
    @NSManaged public var fat: Double
    @NSManaged public var protein: Double
    @NSManaged public var fatPP: Double
    @NSManaged public var carbsPP: Double
    @NSManaged public var proteinPP: Double
    @NSManaged public var perPiece: Bool
    @NSManaged public var mealHistory: MealHistory?

}
