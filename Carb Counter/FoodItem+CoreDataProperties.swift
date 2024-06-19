//
//  FoodItem+CoreDataProperties.swift
//  Carb Counter
//
//  Created by Daniel Snällfot on 2024-06-19.
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
    @NSManaged public var name: String?
    @NSManaged public var protein: Double
    @NSManaged public var id: UUID?

}
