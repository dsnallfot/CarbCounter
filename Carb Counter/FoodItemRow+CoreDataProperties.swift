//
//  FoodItemRow+CoreDataProperties.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-07-06.
//
//

import Foundation
import CoreData


extension FoodItemRow {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<FoodItemRow> {
        return NSFetchRequest<FoodItemRow>(entityName: "FoodItemRow")
    }

    @NSManaged public var foodItemID: UUID?
    @NSManaged public var portionServed: Double
    @NSManaged public var notEaten: Double
    @NSManaged public var netCarbs: Double
    @NSManaged public var netFat: Double
    @NSManaged public var netProtein: Double

}
