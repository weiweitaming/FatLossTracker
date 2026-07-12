import CoreData
import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    private let persistence = PersistenceController.shared

    @Published var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @Published var meals: [MealEntryEntity] = []
    @Published var plan: DietPlan = DietPlan.default
    @Published var analysisText: String = ""
    @Published var draftFoods: [FoodDraft] = []
    @Published var isAnalyzing: Bool = false
    @Published var analysisError: String?
    @Published var showAnalysisSheet: Bool = false
    @Published var selectedMealType: MealType = .other
    @Published var snackTime: Date = Date()
    @Published var isManualMode: Bool = false
    @Published var manualCalories: String = ""
    @Published var manualProtein: String = ""
    @Published var manualFat: String = ""
    @Published var manualCarbs: String = ""
    @Published var trainingTasks: [Int: String] = [:]
    @Published var foodDatabase: [StoredFood] = []
    @Published var newFoodName: String = ""
    @Published var newFoodAmount: String = ""
    @Published var newFoodCalories: String = ""
    @Published var newFoodProtein: String = ""
    @Published var newFoodFat: String = ""
    @Published var newFoodCarbs: String = ""
    @Published var toastMessage: String?
    @Published var toastIsError: Bool = false
    @Published var latestWeight: Double? = nil
    @Published var manualWeightText: String = ""
    @Published var manualBodyFatText: String = ""
    @Published var apiBaseURL: String = "https://api.openai.com/v1"
    @Published var apiKey: String = ""
    @Published var modelName: String = "gpt-4o-mini"
    @Published var weightTrend: [WeightPoint] = []
    @Published var personalInfo = PersonalInfo()
    @Published var recipes: [RecipeEntity] = []
    @Published var newRecipeName: String = ""
    @Published var recipeIngredients: String = ""
    @Published var recipeSteps: String = ""
    @Published var recipeNote: String = ""
    @Published var isGeneratingRecipe: Bool = false
    @Published var recipeGenerationPrompt: String = ""
    @Published var showRecipeSheet: Bool = false
    @Published var fatLossAnalysisResult: String = ""
    @Published var isAnalyzingFatLoss: Bool = false

    var bmi: Double {
        let w = weightForDate(selectedDate) ?? latestWeight
        guard let w, w > 0 else { return 0 }
        return personalInfo.bmi(weight: w)
    }

    func weightForDate(_ date: Date) -> Double? {
        let day = Calendar.current.startOfDay(for: date)
        return weightTrend.first(where: { Calendar.current.isDate($0.date, inSameDayAs: day) })?.weight
    }

    private func foodDatabaseText() -> String {
        guard !foodDatabase.isEmpty else { return "（空）" }
        return foodDatabase.map { food in
            "\(food.name) \(food.amount): \(String(format: "%.1f", food.calories))kcal 蛋白\(String(format: "%.1f", food.protein))g 脂肪\(String(format: "%.1f", food.fat))g 碳水\(String(format: "%.1f", food.carbs))g"
        }.joined(separator: "\n")
    }

    func bodyFatForDate(_ date: Date) -> Double? {
        let day = Calendar.current.startOfDay(for: date)
        return weightTrend.first(where: { Calendar.current.isDate($0.date, inSameDayAs: day) })?.bodyFatPercentage
    }

    init() {
        loadPersonalInfo()
        loadAIConfig()
        refreshMeals()
        refreshRecipes()
        selectedMealType = Self.mealTypeForCurrentTime()
        loadTrainingTasks()
        loadDayTypeOverrides()
        loadFoodDatabase()
        loadWeightTrend()
    }

    static func mealTypeForCurrentTime() -> MealType {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<10:  return .breakfast
        case 10..<14: return .lunch
        case 14..<17: return .snack
        case 17..<22: return .dinner
        default:      return .snack
        }
    }

    func refreshMeals() {
        let context = persistence.container.viewContext
        let request: NSFetchRequest<MealEntryEntity> = MealEntryEntity.fetchRequest()
        let start = Calendar.current.startOfDay(for: selectedDate)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@", start as NSDate, end as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \MealEntryEntity.createdAt, ascending: true)]

        do {
            meals = try context.fetch(request)
        } catch {
            analysisError = "读取饮食记录失败: \(error.localizedDescription)"
        }
    }

    func todayType() -> DayType {
        let key = DateFormatter.shortDate.string(from: selectedDate)
        if let override = dayTypeOverride[key] {
            return override == "training" ? .training : .rest
        }
        let weekday = Calendar.current.component(.weekday, from: selectedDate)
        return plan.trainingDays.contains(weekday) ? .training : .rest
    }

    func recentDailyCalories(days: Int = 14) -> [(date: Date, calories: Double)] {
        let context = persistence.container.viewContext
        let request: NSFetchRequest<MealEntryEntity> = MealEntryEntity.fetchRequest()
        let start = Calendar.current.date(byAdding: .day, value: -(days - 1), to: Calendar.current.startOfDay(for: Date()))!
        let end = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))!
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@", start as NSDate, end as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \MealEntryEntity.date, ascending: true)]
        do {
            let meals = try context.fetch(request)
            var grouped: [Date: Double] = [:]
            for meal in meals {
                let day = Calendar.current.startOfDay(for: meal.date)
                grouped[day, default: 0] += meal.calories
            }
            var result: [(Date, Double)] = []
            for d in 0..<days {
                let day = Calendar.current.date(byAdding: .day, value: -d, to: Calendar.current.startOfDay(for: Date()))!
                result.append((day, grouped[day] ?? 0))
            }
            return result.reversed()
        } catch { return [] }
    }

    func recentNutritionAverages(days: Int = 14) -> (summary: NutritionSummary, recordedDays: Int) {
        let context = persistence.container.viewContext
        let request: NSFetchRequest<MealEntryEntity> = MealEntryEntity.fetchRequest()
        let today = Calendar.current.startOfDay(for: Date())
        let start = Calendar.current.date(byAdding: .day, value: -(days - 1), to: today)!
        let end = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@", start as NSDate, end as NSDate)

        do {
            let recentMeals = try context.fetch(request)
            let recordedDays = Set(recentMeals.map { Calendar.current.startOfDay(for: $0.date) }).count
            guard recordedDays > 0 else { return (.zero, 0) }
            let total = recentMeals.reduce(NutritionSummary.zero) { partial, meal in
                NutritionSummary(
                    calories: partial.calories + meal.calories,
                    protein: partial.protein + meal.protein,
                    fat: partial.fat + meal.fat,
                    carbs: partial.carbs + meal.carbs
                )
            }
            let divisor = Double(recordedDays)
            return (
                NutritionSummary(
                    calories: total.calories / divisor,
                    protein: total.protein / divisor,
                    fat: total.fat / divisor,
                    carbs: total.carbs / divisor
                ),
                recordedDays
            )
        } catch {
            analysisError = "读取近期饮食数据失败: \(error.localizedDescription)"
            return (.zero, 0)
        }
    }

    func toggleDayType() {
        let key = DateFormatter.shortDate.string(from: selectedDate)
        let current = todayType()
        dayTypeOverride[key] = current == .training ? "rest" : "training"
        saveDayTypeOverrides()
    }

    func todayTarget() -> NutritionSummary {
        todayType() == .training ? plan.trainingTarget : plan.restTarget
    }

    func todayIntake() -> NutritionSummary {
        meals.reduce(NutritionSummary.zero) { partial, meal in
            NutritionSummary(
                calories: partial.calories + meal.calories,
                protein: partial.protein + meal.protein,
                fat: partial.fat + meal.fat,
                carbs: partial.carbs + meal.carbs
            )
        }
    }

    func todayExpenditure() -> Double {
        todayType() == .training ? plan.trainingExpenditure : plan.restExpenditure
    }

    func calorieGap() -> Double {
        todayIntake().calories - todayTarget().calories
    }

    func progress(for value: Double, target: Double) -> Double {
        guard target > 0 else { return 0 }
        return min(1.0, value / target)
    }

    func showToast(_ message: String, isError: Bool = false) {
        toastMessage = message
        toastIsError = isError
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            self?.toastMessage = nil
        }
    }

    @Published var analysisMode: Int = 0  // 0=记录, 1=建议分量
    @Published var dayTypeOverride: [String: String] = [:]

    func applyTemplate(_ template: MealTemplate) {
        draftFoods = template.foods
        analysisText = template.name
        showAnalysisSheet = true
    }

    func deleteMeal(_ meal: MealEntryEntity) {
        let context = persistence.container.viewContext
        context.delete(meal)
        do {
            try context.save()
            refreshMeals()
            showToast("已删除")
        } catch {
            analysisError = "删除失败: \(error.localizedDescription)"
        }
    }

    func quickSave() {
        guard let cal = Double(manualCalories), cal > 0 else {
            analysisError = "请输入热量"
            return
        }
        let pro = Double(manualProtein) ?? 0
        let fat = Double(manualFat) ?? 0
        let carb = Double(manualCarbs) ?? 0

        let context = persistence.container.viewContext
        let entry = MealEntryEntity(context: context)
        entry.id = UUID().uuidString
        entry.date = selectedDate
        entry.mealType = selectedMealType.rawValue
        entry.note = "手动录入"
        entry.calories = cal
        entry.protein = pro
        entry.fat = fat
        entry.carbs = carb
        entry.createdAt = selectedMealType == .snack ? snackTime : Date()

        let item = FoodItemEntity(context: context)
        item.id = UUID().uuidString
        item.name = "手动录入"
        item.amount = "1份"
        item.calories = cal
        item.protein = pro
        item.fat = fat
        item.carbs = carb
        item.mealEntry = entry

        do {
            try context.save()
            manualCalories = ""
            manualProtein = ""
            manualFat = ""
            manualCarbs = ""
            analysisError = nil
            refreshMeals()
            var parts: [String] = ["已记录 \(String(format: "%.1f", cal)) kcal"]
            if pro > 0 { parts.append("蛋白质 \(String(format: "%.1f", pro))g") }
            if fat > 0 { parts.append("脂肪 \(String(format: "%.1f", fat))g") }
            if carb > 0 { parts.append("碳水 \(String(format: "%.1f", carb))g") }
            showToast(parts.joined(separator: "，"))
        } catch {
            analysisError = "保存失败: \(error.localizedDescription)"
        }
    }

    func loadWeightTrend() {
        if let data = UserDefaults.standard.data(forKey: "weightTrend"),
           let points = try? JSONDecoder().decode([WeightPoint].self, from: data) {
            weightTrend = points.sorted { $0.date < $1.date }
            latestWeight = weightTrend.last?.weight
        }
    }

    func saveWeightTrend() {
        if let data = try? JSONEncoder().encode(weightTrend) {
            UserDefaults.standard.set(data, forKey: "weightTrend")
        }
    }

    func saveManualWeight() {
        guard let weight = Double(manualWeightText), weight > 0 else { return }
        let existingIndex = weightTrend.lastIndex {
            Calendar.current.isDate($0.date, inSameDayAs: selectedDate)
        }
        let enteredBodyFat = Double(manualBodyFatText).flatMap { $0 > 0 ? $0 : nil }
        let bodyFat = enteredBodyFat ?? existingIndex.flatMap { weightTrend[$0].bodyFatPercentage }
        if let existingIndex {
            weightTrend[existingIndex].date = selectedDate
            weightTrend[existingIndex].weight = weight
            weightTrend[existingIndex].bodyFatPercentage = bodyFat
        } else {
            weightTrend.append(WeightPoint(date: selectedDate, weight: weight, bodyFatPercentage: bodyFat))
        }
        weightTrend.sort { $0.date < $1.date }
        latestWeight = weightTrend.last?.weight
        saveWeightTrend()
        if let bodyFat {
            personalInfo.bodyFatPercentage = bodyFat
            savePersonalInfo()
        }
        manualWeightText = ""
        manualBodyFatText = ""
        showToast("体重 \(String(format: "%.1f", weight))kg 已记录")
    }

    func analyzeText() {
        let text = analysisText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            analysisError = "请先输入饮食描述"
            return
        }
        guard !apiKey.isEmpty else {
            analysisError = "请在设置中填写 API Key"
            return
        }
        guard let url = Self.aiEndpointURL(from: apiBaseURL) else {
            analysisError = "API 地址无效；远程服务必须使用 HTTPS"
            return
        }

        isAnalyzing = true
        analysisError = nil

        let systemPrompt = """
        你是一个专业的营养分析助手。用户会用中文描述他们吃了什么，你需要解析并返回结构化的食物营养数据。

        规则：
        1. 识别每种食物，估算分量和营养成分
        2. 热量单位是千卡(kcal)，蛋白质/脂肪/碳水单位是克(g)
        3. 优先参考用户自定义的食物数据库中的营养数据
        4. 如果数据库中有的食物，必须使用数据库中的数值
        5. 数据库中没的食物，使用你对中国常见食物的知识估算
        6. 如果用户没有明确分量，按常规一人份估算
        7. 返回严格的 JSON 格式

        用户自定义食物数据库：
        \(foodDatabaseText())

        返回格式示例：
        {"foods": [{"name": "米饭", "amount": "1碗(约200g)", "calories": 232, "protein": 5.2, "fat": 0.6, "carbs": 51.6}]}
        """

        let requestBody = ChatCompletionRequest(
            model: modelName.trimmingCharacters(in: .whitespaces).isEmpty ? "gpt-4o-mini" : modelName,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: text)
            ],
            responseFormat: nil
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 120

        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            analysisError = "请求编码失败: \(error.localizedDescription)"
            isAnalyzing = false
            return
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    self.analysisError = "网络请求失败"
                    self.isAnalyzing = false
                    return
                }

                if httpResponse.statusCode == 401 {
                    self.analysisError = "API Key 无效，请检查设置"
                    self.isAnalyzing = false
                    return
                }
                if httpResponse.statusCode == 404 {
                    self.analysisError = "API 地址不存在，请检查 Base URL"
                    self.isAnalyzing = false
                    return
                }
                if httpResponse.statusCode != 200 {
                    let body = String(data: data, encoding: .utf8) ?? ""
                    self.analysisError = "API 错误 (\(httpResponse.statusCode)): \(body.prefix(200))"
                    self.isAnalyzing = false
                    return
                }

                let completion = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
                guard let content = completion.choices.first?.message.content else {
                    self.analysisError = "AI 返回为空"
                    self.isAnalyzing = false
                    return
                }

                // 尝试解析 JSON 响应（兼容 markdown 代码块包裹）
                let foods = Self.extractFoods(from: content)
                if let foods, !foods.isEmpty {
                    self.draftFoods = foods
                    self.isAnalyzing = false
                    self.showAnalysisSheet = true
                } else {
                    self.analysisError = "AI 返回格式异常\n原始返回: \(content.prefix(300))"
                    self.isAnalyzing = false
                }
            } catch let error as URLError {
                self.analysisError = "网络错误: \(error.localizedDescription)"
                self.isAnalyzing = false
            } catch {
                self.analysisError = "请求失败: \(error.localizedDescription)"
                self.isAnalyzing = false
            }
        }
    }

    func saveDraftMeal() {
        let total = draftFoods.reduce(NutritionSummary.zero) { partial, food in
            NutritionSummary(
                calories: partial.calories + food.calories,
                protein: partial.protein + food.protein,
                fat: partial.fat + food.fat,
                carbs: partial.carbs + food.carbs
            )
        }

        let context = persistence.container.viewContext
        let entry = MealEntryEntity(context: context)
        entry.id = UUID().uuidString
        entry.date = selectedDate
        entry.mealType = selectedMealType.rawValue
        entry.note = analysisText
        entry.calories = total.calories
        entry.protein = total.protein
        entry.fat = total.fat
        entry.carbs = total.carbs
        entry.createdAt = selectedMealType == .snack ? snackTime : Date()

        for food in draftFoods {
            let item = FoodItemEntity(context: context)
            item.id = UUID().uuidString
            item.name = food.name
            item.amount = food.amount
            item.calories = food.calories
            item.protein = food.protein
            item.fat = food.fat
            item.carbs = food.carbs
            item.mealEntry = entry
        }

        do {
            try context.save()
            draftFoods = []
            analysisText = ""
            showAnalysisSheet = false
            refreshMeals()
            var parts: [String] = ["已记录 \(String(format: "%.1f", total.calories)) kcal"]
            if total.protein > 0 { parts.append("蛋白质 \(String(format: "%.1f", total.protein))g") }
            if total.fat > 0 { parts.append("脂肪 \(String(format: "%.1f", total.fat))g") }
            if total.carbs > 0 { parts.append("碳水 \(String(format: "%.1f", total.carbs))g") }
            showToast(parts.joined(separator: "，"))
        } catch {
            analysisError = "保存失败: \(error.localizedDescription)"
        }
    }

    func exportCSV() -> URL? {
        let rows = ["日期,餐次,热量,蛋白质,脂肪,碳水,备注"] + meals.map { meal in
            [
                DateFormatter.shortDate.string(from: meal.date), meal.mealType,
                String(meal.calories), String(meal.protein), String(meal.fat),
                String(meal.carbs), meal.note
            ].map(Self.csvField).joined(separator: ",")
        }
        let content = "\u{FEFF}" + rows.joined(separator: "\n")
        let date = DateFormatter.shortDate.string(from: selectedDate)
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("fat_loss_\(date).csv")
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            analysisError = "导出失败: \(error.localizedDescription)"
            return nil
        }
    }

    nonisolated static func csvField(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") else {
            return value
        }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    nonisolated static func aiEndpointURL(from baseURL: String) -> URL? {
        let value = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: value), let scheme = url.scheme?.lowercased(), let host = url.host else {
            return nil
        }
        let isLocal = ["localhost", "127.0.0.1", "::1"].contains(host.lowercased())
        guard scheme == "https" || (scheme == "http" && isLocal) else { return nil }
        return url.appendingPathComponent("chat/completions")
    }

    /// 从 AI 返回文本中提取 JSON，兼容 markdown 代码块包裹
    nonisolated static func extractJSON(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // 尝试匹配 ```json ... ``` 或 ``` ... ```
        let patterns = ["```json", "```"]
        for pattern in patterns {
            if trimmed.hasPrefix(pattern) {
                let withoutStart = String(trimmed.dropFirst(pattern.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if let endRange = withoutStart.range(of: "```") {
                    return String(withoutStart[..<endRange.lowerBound])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        return trimmed
    }

    /// 从文本中解析食物列表
    nonisolated static func extractFoods(from text: String) -> [FoodDraft]? {
        let json = extractJSON(from: text)
        guard let data = json.data(using: .utf8) else { return nil }

        // 尝试标准格式: {"foods": [...]}
        if let result = try? JSONDecoder().decode(AnalysisResult.self, from: data) {
            return result.foods
        }
        // 尝试直接数组格式: [...]
        if let foods = try? JSONDecoder().decode([FoodDraft].self, from: data) {
            return foods
        }
        // 尝试宽松解析：手动提取
        if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let foodsArray = dict["foods"] as? [[String: Any]] {
            return foodsArray.compactMap { item in
                guard let name = item["name"] as? String else { return nil }
                return FoodDraft(
                    name: name,
                    amount: item["amount"] as? String ?? "1份",
                    calories: item["calories"] as? Double ?? 0,
                    protein: item["protein"] as? Double ?? 0,
                    fat: item["fat"] as? Double ?? 0,
                    carbs: item["carbs"] as? Double ?? 0
                )
            }
        }
        return nil
    }

    /// 从文本中解析菜谱
    nonisolated static func extractRecipe(from text: String) -> RecipeGenerationResult? {
        let json = extractJSON(from: text)
        guard let data = json.data(using: .utf8) else { return nil }

        if let result = try? JSONDecoder().decode(RecipeGenerationResult.self, from: data) {
            return result
        }
        // 宽松解析
        if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return RecipeGenerationResult(
                name: dict["name"] as? String ?? "",
                ingredients: dict["ingredients"] as? String ?? "",
                steps: dict["steps"] as? String ?? "",
                note: dict["note"] as? String ?? ""
            )
        }
        return nil
    }

    // MARK: - Personal Info

    func loadPersonalInfo() {
        let defaults = UserDefaults.standard
        let h = defaults.double(forKey: "personalHeight")
        let bf = defaults.double(forKey: "personalBodyFat")
        personalInfo = PersonalInfo(
            height: h > 0 ? h : 170,
            bodyFatPercentage: bf > 0 ? bf : 20
        )
    }

    func savePersonalInfo() {
        let defaults = UserDefaults.standard
        defaults.set(personalInfo.height, forKey: "personalHeight")
        defaults.set(personalInfo.bodyFatPercentage, forKey: "personalBodyFat")
        showToast("个人信息已保存")
    }

    func loadAIConfig() {
        let defaults = UserDefaults.standard
        apiBaseURL = defaults.string(forKey: "aiBaseURL") ?? "https://api.openai.com/v1"
        modelName = defaults.string(forKey: "aiModelName") ?? "gpt-4o-mini"

        do {
            if let storedKey = try KeychainAPIKeyStore.read() {
                apiKey = storedKey
                defaults.removeObject(forKey: "aiApiKey")
            } else if let legacyKey = defaults.string(forKey: "aiApiKey"), !legacyKey.isEmpty {
                // One-time migration from the old plaintext UserDefaults storage.
                try KeychainAPIKeyStore.save(legacyKey)
                apiKey = legacyKey
                defaults.removeObject(forKey: "aiApiKey")
            }
        } catch {
            analysisError = "读取 API Key 失败: \(error.localizedDescription)"
        }
    }

    func loadTrainingTasks() {
        if let data = UserDefaults.standard.data(forKey: "trainingTasks"),
           let dict = try? JSONDecoder().decode([Int: String].self, from: data) {
            trainingTasks = dict
        } else {
            trainingTasks = [
                2: "胸+三头+肩中束\n练后有氧20-30min",
                4: "背+二头+后束\n练后有氧20-30min",
                6: "腿\n练后有氧20-30min"
            ]
        }
    }

    func loadDayTypeOverrides() {
        if let data = UserDefaults.standard.data(forKey: "dayTypeOverrides"),
           let overrides = try? JSONDecoder().decode([String: String].self, from: data) {
            dayTypeOverride = overrides
        }
    }

    func saveDayTypeOverrides() {
        if let data = try? JSONEncoder().encode(dayTypeOverride) {
            UserDefaults.standard.set(data, forKey: "dayTypeOverrides")
        }
    }

    func loadFoodDatabase() {
        if let data = UserDefaults.standard.data(forKey: "foodDatabase"),
           let foods = try? JSONDecoder().decode([StoredFood].self, from: data) {
            foodDatabase = foods
        }
    }

    func saveFoodDatabase() {
        if let data = try? JSONEncoder().encode(foodDatabase) {
            UserDefaults.standard.set(data, forKey: "foodDatabase")
        }
    }

    func addFoodToDatabase(_ food: StoredFood) {
        foodDatabase.append(food)
        saveFoodDatabase()
    }

    func deleteFoodFromDatabase(_ food: StoredFood) {
        foodDatabase.removeAll { $0.id == food.id }
        saveFoodDatabase()
    }

    func saveTrainingTasks() {
        if let data = try? JSONEncoder().encode(trainingTasks) {
            UserDefaults.standard.set(data, forKey: "trainingTasks")
        }
    }

    func saveAIConfig() {
        let defaults = UserDefaults.standard
        defaults.set(apiBaseURL, forKey: "aiBaseURL")
        defaults.set(modelName, forKey: "aiModelName")
        let normalizedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try KeychainAPIKeyStore.save(normalizedKey)
            apiKey = normalizedKey
            defaults.removeObject(forKey: "aiApiKey")
            analysisError = nil
            showToast("AI 配置已保存，API Key 已存入钥匙串")
        } catch {
            analysisError = "保存 API Key 失败: \(error.localizedDescription)"
            showToast("API Key 保存失败", isError: true)
        }
    }

    // MARK: - Recipes

    func refreshRecipes() {
        let context = persistence.container.viewContext
        let request: NSFetchRequest<RecipeEntity> = RecipeEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \RecipeEntity.createdAt, ascending: false)]
        do {
            recipes = try context.fetch(request)
        } catch {
            analysisError = "读取菜谱失败: \(error.localizedDescription)"
        }
    }

    func saveRecipe(name: String, ingredients: String, steps: String, note: String) {
        let context = persistence.container.viewContext
        let recipe = RecipeEntity(context: context)
        recipe.id = UUID().uuidString
        recipe.name = name
        recipe.ingredients = ingredients
        recipe.steps = steps
        recipe.note = note
        recipe.createdAt = Date()
        do {
            try context.save()
            refreshRecipes()
            showToast("菜谱「\(name)」已保存")
        } catch {
            analysisError = "保存菜谱失败: \(error.localizedDescription)"
        }
    }

    func deleteRecipe(_ recipe: RecipeEntity) {
        let context = persistence.container.viewContext
        let name = recipe.name
        context.delete(recipe)
        do {
            try context.save()
            refreshRecipes()
            showToast("菜谱「\(name)」已删除")
        } catch {
            analysisError = "删除菜谱失败: \(error.localizedDescription)"
        }
    }

    func generateRecipe() {
        let prompt = recipeGenerationPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else {
            analysisError = "请输入菜名或描述"
            return
        }
        guard !apiKey.isEmpty else {
            analysisError = "请在设置中填写 API Key"
            return
        }
        guard let url = Self.aiEndpointURL(from: apiBaseURL) else {
            analysisError = "API 地址无效；远程服务必须使用 HTTPS"
            return
        }

        isGeneratingRecipe = true
        analysisError = nil

        let systemPrompt = """
        你是一个专业的中餐厨师。用户会告诉你一个菜名，你需要生成详细的做菜步骤。

        返回严格的 JSON 格式：
        {"name": "菜名", "ingredients": "食材清单（每行一个）", "steps": "做菜步骤（编号，每行一步）", "note": "小贴士或备注"}

        规则：
        1. 食材清单要具体，包含用量
        2. 步骤清晰易懂，适合家庭厨房
        3. 如果有烹饪技巧，写在 note 里
        """

        let requestBody = ChatCompletionRequest(
            model: modelName.trimmingCharacters(in: .whitespaces).isEmpty ? "gpt-4o-mini" : modelName,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: prompt)
            ],
            responseFormat: nil
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 120

        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            analysisError = "请求编码失败"
            isGeneratingRecipe = false
            return
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    self.analysisError = "AI 请求失败"
                    self.isGeneratingRecipe = false
                    return
                }
                let completion = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
                guard let content = completion.choices.first?.message.content,
                      let result = Self.extractRecipe(from: content) else {
                    self.analysisError = "AI 返回格式异常，请重试"
                    self.isGeneratingRecipe = false
                    return
                }

                self.newRecipeName = result.name
                self.recipeIngredients = result.ingredients
                self.recipeSteps = result.steps
                self.recipeNote = result.note
                self.isGeneratingRecipe = false
                self.showRecipeSheet = true
                self.showToast("菜谱「\(result.name)」已生成")
            } catch {
                self.analysisError = "请求失败: \(error.localizedDescription)"
                self.isGeneratingRecipe = false
            }
        }
    }

    // MARK: - Fat Loss Analysis

    func suggestPortions() {
        let text = analysisText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { analysisError = "请输入菜名"; return }
        guard !apiKey.isEmpty else { analysisError = "请在设置中填写 API Key"; return }
        guard let url = Self.aiEndpointURL(from: apiBaseURL) else {
            analysisError = "API 地址无效；远程服务必须使用 HTTPS"; return
        }

        isAnalyzing = true
        analysisError = nil

        let target = todayTarget()
        let intake = todayIntake()
        let remaining = NutritionSummary(
            calories: max(0, target.calories - intake.calories),
            protein: max(0, target.protein - intake.protein),
            fat: max(0, target.fat - intake.fat),
            carbs: max(0, target.carbs - intake.carbs)
        )

        let systemPrompt = """
        你是专业营养师。用户列出几道菜，你需要建议每道菜吃多少克，使其总营养接近剩余目标。

        剩余目标：\(String(format: "%.1f", remaining.calories))kcal 蛋白质\(String(format: "%.1f", remaining.protein))g 脂肪\(String(format: "%.1f", remaining.fat))g 碳水\(String(format: "%.1f", remaining.carbs))g
        今天是\(todayType().rawValue)

        规则：
        1. 每道菜给出建议克数
        2. 总热量尽量接近剩余目标
        3. 优先参考用户食物数据库中的营养数据
        4. 返回严格JSON格式

        用户食物数据库：
        \(foodDatabaseText())

        返回格式：{"foods":[{"name":"炒青菜","amount":"200g","calories":80,"protein":3,"fat":4,"carbs":6}]}
        """

        let requestBody = ChatCompletionRequest(
            model: modelName.trimmingCharacters(in: .whitespaces).isEmpty ? "gpt-4o-mini" : modelName,
            messages: [.init(role: "system", content: systemPrompt), .init(role: "user", content: text)],
            responseFormat: nil
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 120

        do { request.httpBody = try JSONEncoder().encode(requestBody) }
        catch { analysisError = "请求编码失败"; isAnalyzing = false; return }

        Task { [weak self] in
            guard let self else { return }
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    self.analysisError = "AI 请求失败"; self.isAnalyzing = false; return
                }
                let completion = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
                guard let content = completion.choices.first?.message.content else {
                    self.analysisError = "AI 返回为空"; self.isAnalyzing = false; return
                }
                let foods = Self.extractFoods(from: content)
                if let foods, !foods.isEmpty {
                    self.draftFoods = foods
                    self.isAnalyzing = false
                    self.showAnalysisSheet = true
                } else {
                    self.analysisError = "AI 返回格式异常\n原始返回: \(content.prefix(300))"
                    self.isAnalyzing = false
                }
            } catch {
                self.analysisError = "请求失败: \(error.localizedDescription)"
                self.isAnalyzing = false
            }
        }
    }

    func analyzeFatLoss() {
        guard !apiKey.isEmpty else {
            analysisError = "请在设置中填写 API Key"
            return
        }
        guard let url = Self.aiEndpointURL(from: apiBaseURL) else {
            analysisError = "API 地址无效；远程服务必须使用 HTTPS"
            return
        }

        isAnalyzingFatLoss = true
        analysisError = nil
        fatLossAnalysisResult = ""

        // 准备数据
        let weightData = weightTrend.suffix(7).map { pt in
            "\(DateFormatter.shortDate.string(from: pt.date)): \(String(format: "%.1f", pt.weight))kg"
        }.joined(separator: "\n")

        let recentAverages = recentNutritionAverages(days: 14)
        guard analysisError == nil else {
            isAnalyzingFatLoss = false
            return
        }

        let userPrompt = """
        请分析以下减脂数据并给出建议：

        【个人信息】
        身高：\(String(format: "%.0f", personalInfo.height))cm
        当前体重：\(latestWeight.map { String(format: "%.1f", $0) } ?? "未知")kg
        BMI：\(String(format: "%.1f", bmi))
        体脂率：\(String(format: "%.1f", personalInfo.bodyFatPercentage))%

        【体重趋势（最近7天）】
        \(weightData)

        【饮食数据】
        最近14天内有效记录：\(recentAverages.recordedDays)天
        有记录日的日均摄入热量：\(String(format: "%.0f", recentAverages.summary.calories)) kcal
        有记录日的日均摄入蛋白：\(String(format: "%.0f", recentAverages.summary.protein))g
        训练日目标：\(String(format: "%.0f", plan.trainingTarget.calories)) kcal / \(String(format: "%.0f", plan.trainingTarget.protein))g 蛋白
        休息日目标：\(String(format: "%.0f", plan.restTarget.calories)) kcal / \(String(format: "%.0f", plan.restTarget.protein))g 蛋白

        请分析：
        1. 当前减脂进度评估
        2. 饮食结构是否合理
        3. 具体改进建议
        4. 预计达到目标体重的周期

        用中文回答，简洁实用，控制在 300 字以内。
        """

        let requestBody = ChatCompletionRequest(
            model: modelName.trimmingCharacters(in: .whitespaces).isEmpty ? "gpt-4o-mini" : modelName,
            messages: [
                .init(role: "system", content: "你是一个专业的减脂教练，擅长分析营养和体重数据，给出实用的减脂建议。"),
                .init(role: "user", content: userPrompt)
            ],
            responseFormat: nil
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 45

        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            analysisError = "请求编码失败"
            isAnalyzingFatLoss = false
            return
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    self.analysisError = "AI 请求失败"
                    self.isAnalyzingFatLoss = false
                    return
                }
                let completion = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
                self.fatLossAnalysisResult = completion.choices.first?.message.content ?? "无分析结果"
                self.isAnalyzingFatLoss = false
                self.showToast("减脂分析完成")
            } catch {
                self.analysisError = "请求失败: \(error.localizedDescription)"
                self.isAnalyzingFatLoss = false
            }
        }
    }
}

extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

extension NutritionSummary {
    static let zero = NutritionSummary(calories: 0, protein: 0, fat: 0, carbs: 0)
}

extension MealType {
    var label: String { rawValue }
}

extension DietPlan {
    static let `default` = DietPlan(
        trainingDays: [2, 4, 6],
        trainingTarget: NutritionSummary(calories: 1610, protein: 148, fat: 58, carbs: 195),
        restTarget: NutritionSummary(calories: 1250, protein: 120, fat: 42, carbs: 130),
        trainingExpenditure: 1900,
        restExpenditure: 1500,
        templates: trainingTemplates + restTemplates
    )

    static let trainingTemplates: [MealTemplate] = [
        MealTemplate(name: "早餐", foods: [
            FoodDraft(name: "牛奶泡燕麦", amount: "250ml牛奶+50g燕麦", calories: 375, protein: 14.5, fat: 10, carbs: 40),
            FoodDraft(name: "煮鸡蛋", amount: "2个", calories: 140, protein: 12, fat: 10, carbs: 2)
        ]),
        MealTemplate(name: "练前", foods: [
            FoodDraft(name: "黑咖啡", amount: "1杯", calories: 5, protein: 0, fat: 0, carbs: 0)
        ]),
        MealTemplate(name: "力量后有氧前", foods: [
            FoodDraft(name: "蛋白粉+香蕉", amount: "1勺+1根", calories: 230, protein: 25, fat: 2, carbs: 30)
        ]),
        MealTemplate(name: "午餐", foods: [
            FoodDraft(name: "菜+米饭+维生素", amount: "菜+饭80g", calories: 600, protein: 40, fat: 15, carbs: 60)
        ]),
        MealTemplate(name: "晚餐", foods: [
            FoodDraft(name: "鸡胸肉+虾仁+生菜+红薯", amount: "100g+100g+300g+100g", calories: 405, protein: 49, fat: 10, carbs: 35)
        ]),
        MealTemplate(name: "睡前", foods: [
            FoodDraft(name: "蛋白粉", amount: "半勺", calories: 60, protein: 12, fat: 0, carbs: 0)
        ])
    ]

    static let restTemplates: [MealTemplate] = [
        MealTemplate(name: "早餐", foods: [
            FoodDraft(name: "拿铁+水煮蛋+蓝莓", amount: "1杯+2个+125g", calories: 360, protein: 23, fat: 16, carbs: 27)
        ]),
        MealTemplate(name: "午餐", foods: [
            FoodDraft(name: "菜+维生素", amount: "无饭", calories: 500, protein: 40, fat: 20, carbs: 0)
        ]),
        MealTemplate(name: "晚餐", foods: [
            FoodDraft(name: "鸡胸肉+虾仁+生菜", amount: "100g+150g+300g", calories: 390, protein: 57, fat: 10, carbs: 15)
        ])
    ]
}

// MARK: - AI API Models

struct ChatCompletionRequest: Codable {
    let model: String
    let messages: [Message]
    let responseFormat: ResponseFormat?

    struct Message: Codable {
        let role: String
        let content: String
    }

    struct ResponseFormat: Codable {
        let type: String
    }

    enum CodingKeys: String, CodingKey {
        case model, messages
        case responseFormat = "response_format"
    }
}

struct ChatCompletionResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message
    }

    struct Message: Decodable {
        let content: String
    }
}

struct AnalysisResult: Decodable {
    let foods: [FoodDraft]
}

struct RecipeGenerationResult: Decodable {
    let name: String
    let ingredients: String
    let steps: String
    let note: String
}
