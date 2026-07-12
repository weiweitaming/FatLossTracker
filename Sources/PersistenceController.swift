import CoreData
import Foundation

final class PersistenceController: ObservableObject, @unchecked Sendable {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init() {
        let model = NSManagedObjectModel()

        let mealEntity = NSEntityDescription()
        mealEntity.name = "MealEntryEntity"
        mealEntity.managedObjectClassName = "MealEntryEntity"

        let mealId = NSAttributeDescription()
        mealId.name = "id"
        mealId.attributeType = .stringAttributeType
        mealId.isOptional = false

        let mealDate = NSAttributeDescription()
        mealDate.name = "date"
        mealDate.attributeType = .dateAttributeType
        mealDate.isOptional = false

        let mealType = NSAttributeDescription()
        mealType.name = "mealType"
        mealType.attributeType = .stringAttributeType
        mealType.isOptional = false

        let note = NSAttributeDescription()
        note.name = "note"
        note.attributeType = .stringAttributeType
        note.isOptional = true

        let calories = NSAttributeDescription()
        calories.name = "calories"
        calories.attributeType = .doubleAttributeType
        calories.isOptional = false

        let protein = NSAttributeDescription()
        protein.name = "protein"
        protein.attributeType = .doubleAttributeType
        protein.isOptional = false

        let fat = NSAttributeDescription()
        fat.name = "fat"
        fat.attributeType = .doubleAttributeType
        fat.isOptional = false

        let carbs = NSAttributeDescription()
        carbs.name = "carbs"
        carbs.attributeType = .doubleAttributeType
        carbs.isOptional = false

        let createdAt = NSAttributeDescription()
        createdAt.name = "createdAt"
        createdAt.attributeType = .dateAttributeType
        createdAt.isOptional = false

        let foodItemsRel = NSRelationshipDescription()
        foodItemsRel.name = "foodItems"
        foodItemsRel.isOptional = true
        foodItemsRel.minCount = 0
        foodItemsRel.maxCount = 0
        foodItemsRel.deleteRule = .cascadeDeleteRule

        let foodEntity = NSEntityDescription()
        foodEntity.name = "FoodItemEntity"
        foodEntity.managedObjectClassName = "FoodItemEntity"

        let foodId = NSAttributeDescription()
        foodId.name = "id"
        foodId.attributeType = .stringAttributeType
        foodId.isOptional = false

        let foodName = NSAttributeDescription()
        foodName.name = "name"
        foodName.attributeType = .stringAttributeType
        foodName.isOptional = false

        let foodAmount = NSAttributeDescription()
        foodAmount.name = "amount"
        foodAmount.attributeType = .stringAttributeType
        foodAmount.isOptional = false

        let foodCalories = NSAttributeDescription()
        foodCalories.name = "calories"
        foodCalories.attributeType = .doubleAttributeType
        foodCalories.isOptional = false

        let foodProtein = NSAttributeDescription()
        foodProtein.name = "protein"
        foodProtein.attributeType = .doubleAttributeType
        foodProtein.isOptional = false

        let foodFat = NSAttributeDescription()
        foodFat.name = "fat"
        foodFat.attributeType = .doubleAttributeType
        foodFat.isOptional = false

        let foodCarbs = NSAttributeDescription()
        foodCarbs.name = "carbs"
        foodCarbs.attributeType = .doubleAttributeType
        foodCarbs.isOptional = false

        let mealRel = NSRelationshipDescription()
        mealRel.name = "mealEntry"
        mealRel.destinationEntity = mealEntity
        mealRel.inverseRelationship = foodItemsRel
        mealRel.isOptional = true
        mealRel.maxCount = 1
        mealRel.deleteRule = .nullifyDeleteRule

        foodItemsRel.destinationEntity = foodEntity
        foodItemsRel.inverseRelationship = mealRel

        mealEntity.properties = [mealId, mealDate, mealType, note, calories, protein, fat, carbs, createdAt, foodItemsRel]
        foodEntity.properties = [foodId, foodName, foodAmount, foodCalories, foodProtein, foodFat, foodCarbs, mealRel]

        // Recipe entity
        let recipeEntity = NSEntityDescription()
        recipeEntity.name = "RecipeEntity"
        recipeEntity.managedObjectClassName = "RecipeEntity"

        let recipeId = NSAttributeDescription()
        recipeId.name = "id"
        recipeId.attributeType = .stringAttributeType
        recipeId.isOptional = false

        let recipeName = NSAttributeDescription()
        recipeName.name = "name"
        recipeName.attributeType = .stringAttributeType
        recipeName.isOptional = false

        let recipeIngredients = NSAttributeDescription()
        recipeIngredients.name = "ingredients"
        recipeIngredients.attributeType = .stringAttributeType
        recipeIngredients.isOptional = true

        let recipeSteps = NSAttributeDescription()
        recipeSteps.name = "steps"
        recipeSteps.attributeType = .stringAttributeType
        recipeSteps.isOptional = true

        let recipeNote = NSAttributeDescription()
        recipeNote.name = "note"
        recipeNote.attributeType = .stringAttributeType
        recipeNote.isOptional = true

        let recipeCreatedAt = NSAttributeDescription()
        recipeCreatedAt.name = "createdAt"
        recipeCreatedAt.attributeType = .dateAttributeType
        recipeCreatedAt.isOptional = false

        recipeEntity.properties = [recipeId, recipeName, recipeIngredients, recipeSteps, recipeNote, recipeCreatedAt]

        model.entities = [mealEntity, foodEntity, recipeEntity]

        container = NSPersistentContainer(name: "FatLossTracker", managedObjectModel: model)
        let description = NSPersistentStoreDescription(url: Self.storeURL)
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        container.persistentStoreDescriptions = [description]

        container.loadPersistentStores { _, error in
            if let error {
                fatalError("无法加载 Core Data 存储: \(error.localizedDescription)")
            }
        }
    }

    static var storeURL: URL {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("FatLossTracker")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url.appendingPathComponent("FatLossTracker.sqlite")
    }

    func saveContext() {
        let context = container.viewContext
        if context.hasChanges {
            try? context.save()
        }
    }
}

@objc(MealEntryEntity)
public class MealEntryEntity: NSManagedObject {
    @NSManaged public var id: String
    @NSManaged public var date: Date
    @NSManaged public var mealType: String
    @NSManaged public var note: String
    @NSManaged public var calories: Double
    @NSManaged public var protein: Double
    @NSManaged public var fat: Double
    @NSManaged public var carbs: Double
    @NSManaged public var createdAt: Date
    @NSManaged public var foodItems: NSSet

    @nonobjc public class func fetchRequest() -> NSFetchRequest<MealEntryEntity> {
        NSFetchRequest<MealEntryEntity>(entityName: "MealEntryEntity")
    }
}

@objc(FoodItemEntity)
public class FoodItemEntity: NSManagedObject {
    @NSManaged public var id: String
    @NSManaged public var name: String
    @NSManaged public var amount: String
    @NSManaged public var calories: Double
    @NSManaged public var protein: Double
    @NSManaged public var fat: Double
    @NSManaged public var carbs: Double
    @NSManaged public var mealEntry: MealEntryEntity?

    @nonobjc public class func fetchRequest() -> NSFetchRequest<FoodItemEntity> {
        NSFetchRequest<FoodItemEntity>(entityName: "FoodItemEntity")
    }
}

@objc(RecipeEntity)
public class RecipeEntity: NSManagedObject {
    @NSManaged public var id: String
    @NSManaged public var name: String
    @NSManaged public var ingredients: String
    @NSManaged public var steps: String
    @NSManaged public var note: String
    @NSManaged public var createdAt: Date

    @nonobjc public class func fetchRequest() -> NSFetchRequest<RecipeEntity> {
        NSFetchRequest<RecipeEntity>(entityName: "RecipeEntity")
    }
}
