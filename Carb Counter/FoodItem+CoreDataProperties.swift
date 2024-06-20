//
//  FoodItem+CoreDataProperties.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-06-20.
//
//

import Foundation
import CoreData


extension FoodItem {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<FoodItem> {
        return NSFetchRequest<FoodItem>(entityName: "FoodItem")
    }

    @NSManaged public var carbohydrates: Double
    @NSManaged public var fat: Double
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var netCarbs: Double
    @NSManaged public var protein: Double
    @NSManaged public var carbsPP: Double
    @NSManaged public var fatPP: Double
    @NSManaged public var proteinPP: NSObject?
    @NSManaged public var netFat: Double
    @NSManaged public var netProtein: Double

}
