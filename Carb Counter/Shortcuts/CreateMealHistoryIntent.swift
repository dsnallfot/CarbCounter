import AppIntents
import CoreData

struct CreateMealHistoryIntent: AppIntent {
    static var title: LocalizedStringResource = "Create Meal History Entry"
    static var description = IntentDescription("Create a new MealHistory entry using a selected FoodItem.")

    @Parameter(title: "Select Food Item", optionsProvider: FoodItemOptionsProvider())
    var foodItem: FoodItemEntity

    @Parameter(title: "Mängd")
    var portionServed: Double

    @Parameter(title: "Bolus")
    var bolus: Double

    @Parameter(title: "Meal Date")
    var mealDate: Date

    func perform() async throws -> some IntentResult {
        saveMealHistory(
            foodItem: foodItem.foodItem,
            portionServed: portionServed,
            bolus: bolus,
            mealDate: mealDate
        )

        return .result()
    }

    private func saveMealHistory(foodItem: FoodItem, portionServed: Double, bolus: Double, mealDate: Date) {
        let context = CoreDataStack.shared.context
        let mealHistory = MealHistory(context: context)
        
        mealHistory.id = UUID()
        mealHistory.mealDate = mealDate
        mealHistory.delete = false
        
        mealHistory.totalNetCarbs = foodItem.perPiece
            ? foodItem.carbsPP * portionServed
            : foodItem.carbohydrates * portionServed / 100

        mealHistory.totalNetFat = foodItem.perPiece
            ? foodItem.fatPP * portionServed
            : foodItem.fat * portionServed / 100

        mealHistory.totalNetProtein = foodItem.perPiece
            ? foodItem.proteinPP * portionServed
            : foodItem.protein * portionServed / 100

        mealHistory.totalNetBolus = bolus

        let foodEntry = FoodItemEntry(context: context)
        foodEntry.entryId = foodItem.id
        foodEntry.entryName = foodItem.name
        foodEntry.entryCarbohydrates = foodItem.carbohydrates
        foodEntry.entryFat = foodItem.fat
        foodEntry.entryProtein = foodItem.protein
        foodEntry.entryEmoji = foodItem.emoji
        foodEntry.entryPortionServed = portionServed
        foodEntry.entryCarbsPP = foodItem.carbsPP
        foodEntry.entryFatPP = foodItem.fatPP
        foodEntry.entryProteinPP = foodItem.proteinPP
        foodEntry.entryPerPiece = foodItem.perPiece

        mealHistory.addToFoodEntries(foodEntry)

        do {
            try context.save()
            print("MealHistory saved successfully through shortcut!")
        } catch {
            print("Failed to save MealHistory: \(error)")
        }
    }
}

enum FoodItemSortOption: String, AppEnum {
    case name
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = .init(name: "Sort Option")
    static var caseDisplayRepresentations: [FoodItemSortOption: DisplayRepresentation] = [
        .name: DisplayRepresentation(title: "Name")
    ]
}

struct FoodItemEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = .init(name: "Food Item")
    
    var id: UUID
    var name: String
    var emoji: String
    var foodItem: FoodItem
    
    var displayRepresentation: DisplayRepresentation {
        return DisplayRepresentation(
            title: "\(emoji) \(name)"
        )
    }
    
    static var defaultQuery = FoodItemQuery()
    
    static func suggestedEntities() async throws -> [FoodItemEntity] {
        return try await defaultQuery.entities()
    }
}

struct FoodItemQuery: EntityQuery {
    typealias Entity = FoodItemEntity
    
    func entities() async throws -> [FoodItemEntity] {
        let context = CoreDataStack.shared.context
        let fetchRequest: NSFetchRequest<FoodItem> = FoodItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "delete == NO OR delete == nil")
        
        let foodItems = try context.fetch(fetchRequest)
        return foodItems.map { foodItem in
            FoodItemEntity(
                id: foodItem.id ?? UUID(),
                name: foodItem.name ?? "",
                emoji: foodItem.emoji ?? "🍽",
                foodItem: foodItem
            )
        }
    }
    
    func suggestedEntities() async throws -> [FoodItemEntity] {
        return try await entities()
    }
    
    func entities(for identifiers: [UUID]) async throws -> [FoodItemEntity] {
        let context = CoreDataStack.shared.context
        let fetchRequest: NSFetchRequest<FoodItem> = FoodItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "(delete == NO OR delete == nil) AND id IN %@", identifiers)
        
        let foodItems = try context.fetch(fetchRequest)
        return foodItems.map { foodItem in
            FoodItemEntity(
                id: foodItem.id ?? UUID(),
                name: foodItem.name ?? "",
                emoji: foodItem.emoji ?? "🍽",
                foodItem: foodItem
            )
        }
    }
}

struct FoodItemOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [FoodItemEntity] {
        let context = CoreDataStack.shared.context
        let fetchRequest: NSFetchRequest<FoodItem> = FoodItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "delete == NO OR delete == nil")
        
        let foodItems = try context.fetch(fetchRequest)
        return foodItems.map { foodItem in
            FoodItemEntity(
                id: foodItem.id ?? UUID(),
                name: foodItem.name ?? "",
                emoji: foodItem.emoji ?? "🍽",
                foodItem: foodItem
            )
        }
    }
    
    func defaultResult() async -> FoodItemEntity? {
        return try? await results().first
    }
}
