import Foundation

struct NutritionSummary: Codable, Equatable {
    var calories: Double
    var protein: Double
    var fat: Double
    var carbs: Double
}

struct FoodDraft: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var amount: String
    var calories: Double
    var protein: Double
    var fat: Double
    var carbs: Double

    init(
        id: UUID = UUID(),
        name: String,
        amount: String,
        calories: Double,
        protein: Double,
        fat: Double,
        carbs: Double
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.calories = calories
        self.protein = protein
        self.fat = fat
        self.carbs = carbs
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, amount, calories, protein, fat, carbs
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try values.decode(String.self, forKey: .name)
        amount = try values.decode(String.self, forKey: .amount)
        calories = try values.decode(Double.self, forKey: .calories)
        protein = try values.decode(Double.self, forKey: .protein)
        fat = try values.decode(Double.self, forKey: .fat)
        carbs = try values.decode(Double.self, forKey: .carbs)
    }
}

struct MealTemplate: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var foods: [FoodDraft]
}

struct DietPlan: Codable, Equatable {
    var trainingDays: [Int]
    var trainingTarget: NutritionSummary
    var restTarget: NutritionSummary
    var trainingExpenditure: Double
    var restExpenditure: Double
    var templates: [MealTemplate]
}

enum MealType: String, CaseIterable, Codable {
    case breakfast = "早餐"
    case lunch = "午餐"
    case dinner = "晚餐"
    case snack = "加餐"
    case other = "正餐"
}

enum DayType: String, CaseIterable, Codable {
    case training = "训练日"
    case rest = "休息日"
}

struct StoredFood: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var amount: String
    var calories: Double
    var protein: Double
    var fat: Double
    var carbs: Double
}

struct WeightPoint: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var date: Date
    var weight: Double
    var bodyFatPercentage: Double? = nil
}

struct PersonalInfo {
    var height: Double = 170
    var bodyFatPercentage: Double = 20

    func bmi(weight: Double) -> Double {
        let h = height / 100
        return weight / (h * h)
    }
}
