import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                Section("主功能") {
                    Label("仪表盘", systemImage: "gauge.high")
                        .tag(0)
                    Label("饮食分析", systemImage: "fork.knife")
                        .tag(1)
                    Label("减脂分析", systemImage: "chart.line.uptrend.xyaxis")
                        .tag(2)
                    Label("做菜记录", systemImage: "frying.pan")
                        .tag(3)
                    Label("计划配置", systemImage: "calendar.badge.clock")
                        .tag(4)
                    Label("设置", systemImage: "gearshape")
                        .tag(5)
                }
            }
            .navigationTitle("减脂助手")
        } detail: {
            Group {
                switch selectedTab {
                case 1:
                    FoodAnalysisView()
                case 2:
                    FatLossAnalysisView()
                case 3:
                    CookingView()
                case 4:
                    PlanView()
                case 5:
                    SettingsView()
                default:
                    DashboardView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        appState.showAnalysisSheet = true
                    } label: {
                        Label("新增饮食", systemImage: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $appState.showAnalysisSheet) {
            AnalysisSheetView()
        }
        .overlay(alignment: .top) {
            if let msg = appState.toastMessage {
                HStack(spacing: 8) {
                    Image(systemName: appState.toastIsError ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(appState.toastIsError ? .red : .green)
                    Text(msg)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: Capsule())
                .shadow(radius: 8)
                .padding(.top, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(response: 0.4), value: appState.toastMessage != nil)
            }
        }
    }
}

struct DashboardView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("今日计划摘要")
                        .font(.title2).bold()
                    HStack {
                        Text("今天是 \(appState.todayType().rawValue)，目标热量 \(fmt(appState.todayTarget().calories)) kcal")
                            .foregroundStyle(.secondary)
                        Button {
                            appState.toggleDayType()
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible())], spacing: 16) {
                    SummaryCard(title: "缺口", value: "\(fmt(appState.calorieGap())) kcal", subtitle: appState.calorieGap() > 0 ? "高于目标" : "低于目标")
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("实际摄入 vs 计划")
                        .font(.headline)
                    ProgressRow(title: "热量", current: appState.todayIntake().calories, target: appState.todayTarget().calories)
                    ProgressRow(title: "蛋白", current: appState.todayIntake().protein, target: appState.todayTarget().protein)
                    ProgressRow(title: "脂肪", current: appState.todayIntake().fat, target: appState.todayTarget().fat)
                    ProgressRow(title: "碳水", current: appState.todayIntake().carbs, target: appState.todayTarget().carbs)
                }
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 12) {
                    Text("今日食物")
                        .font(.headline)
                    if appState.meals.isEmpty {
                        Text("今天还没记录饮食")
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(appState.meals, id: \.id) { meal in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(meal.mealType)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.15), in: Capsule())
                                    Spacer()
                                    Text("\(fmt(meal.calories)) kcal")
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                    Button(role: .destructive) {
                                        appState.deleteMeal(meal)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.plain)
                                }
                                if let items = meal.foodItems.allObjects as? [FoodItemEntity], !items.isEmpty {
                                    ForEach(items, id: \.id) { item in
                                        HStack {
                                            Circle()
                                                .fill(Color.green.opacity(0.5))
                                                .frame(width: 6, height: 6)
                                            Text(item.name)
                                            Text(item.amount)
                                                .foregroundStyle(.secondary)
                                                .font(.caption)
                                            Spacer()
                                            Text("\(fmt(item.calories))kcal")
                                                .font(.caption)
                                            Text("蛋白\(fmt(item.protein))g")
                                                .font(.caption)
                                                .foregroundStyle(.blue)
                                            Text("脂肪\(fmt(item.fat))g")
                                                .font(.caption)
                                                .foregroundStyle(.orange)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                            if meal.id != appState.meals.last?.id {
                                Divider()
                            }
                        }
                    }
                }
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

                // 热量历史
                VStack(alignment: .leading, spacing: 10) {
                    Text("近14天热量波动")
                        .font(.headline)
                    let history = appState.recentDailyCalories(days: 14)
                    let maxCal = history.map(\.calories).max() ?? 1
                    ForEach(history, id: \.date) { item in
                        HStack(spacing: 8) {
                            Text(DateFormatter.shortDate.string(from: item.date))
                                .font(.caption)
                                .frame(width: 70, alignment: .leading)
                            GeometryReader { geo in
                                Rectangle()
                                    .fill(item.calories > 0 ? Color.blue.opacity(0.6) : Color.gray.opacity(0.2))
                                    .frame(width: max(4, geo.size.width * (item.calories / max(maxCal, 1))))
                            }
                            .frame(height: 14)
                            .background(Color.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
                            Text(item.calories > 0 ? "\(fmt(item.calories))" : "-")
                                .font(.caption)
                                .frame(width: 50, alignment: .trailing)
                                .foregroundStyle(item.calories > 0 ? .primary : .secondary)
                        }
                    }
                }
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding()
        }
        .navigationTitle("仪表盘")
    }
}

struct SummaryCard: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2).bold()
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct ProgressRow: View {
    let title: String
    let current: Double
    let target: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text("\(fmt(current))/\(fmt(target))")
            }
            ProgressView(value: min(current / max(target, 1), 1.0))
        }
    }
}

struct FoodAnalysisView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
        VStack(spacing: 24) {
            // 日期翻页
            DateStepper(date: $appState.selectedDate, onDateChanged: { appState.refreshMeals() })

            // 顶部说明
            VStack(spacing: 6) {
                Image(systemName: "fork.knife.circle")
                    .font(.system(size: 36))
                    .foregroundStyle(.blue)
                Text("今天吃了什么？")
                    .font(.title2).bold()
                Text("用自然语言描述，AI 帮你分析营养")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // 餐次选择
            VStack(spacing: 8) {
                Picker("", selection: $appState.selectedMealType) {
                    ForEach(MealType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 380)
                .onChange(of: appState.selectedMealType) { _, newType in
                    if newType == .snack {
                        appState.snackTime = Date()
                    }
                }

                if appState.selectedMealType == .snack {
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        DatePicker("", selection: $appState.snackTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .controlSize(.small)
                    }
                }
            }

            // AI / 手动 切换
            HStack {
                Toggle(isOn: $appState.isManualMode) {
                    Text("手动录入热量")
                        .font(.subheadline)
                }
                .toggleStyle(.switch)
            }

            if appState.isManualMode {
                ManualInputView()
            } else {
                AIInputView()
            }

            if let error = appState.analysisError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            Spacer()

            TodayMealList()
            FoodDatabaseView()
        }
        .padding(.vertical, 24)
        }
        .navigationTitle("饮食分析")
    }
}

struct TodayMealList: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        if !appState.meals.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("今日已记录")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(appState.meals, id: \.id) { meal in
                    HStack {
                        Text(meal.mealType)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Color.blue.opacity(0.1), in: Capsule())
                        Text("\(fmt(meal.calories))kcal")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(role: .destructive) {
                            appState.deleteMeal(meal)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption2)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 40)
        }
    }
}

struct FoodDatabaseView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("我的食物库")
                .font(.caption)
                .foregroundStyle(.secondary)
            if appState.foodDatabase.isEmpty {
                Text("添加常吃食物，AI 会优先参考")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(appState.foodDatabase) { food in
                    HStack(spacing: 4) {
                        Text(food.name).font(.caption)
                        Text(food.amount).font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        Text("\(fmt(food.calories))kcal").font(.caption2)
                        Text("蛋白\(fmt(food.protein))g").font(.caption2).foregroundStyle(.blue)
                        Text("脂肪\(fmt(food.fat))g").font(.caption2).foregroundStyle(.orange)
                        Text("碳水\(fmt(food.carbs))g").font(.caption2).foregroundStyle(.green)
                        Button(role: .destructive) {
                            appState.deleteFoodFromDatabase(food)
                        } label: {
                            Image(systemName: "xmark").font(.caption2)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            HStack(spacing: 4) {
                TextField("食物名", text: $appState.newFoodName).textFieldStyle(.roundedBorder).frame(width: 70)
                TextField("份量", text: $appState.newFoodAmount).textFieldStyle(.roundedBorder).frame(width: 50)
                TextField("kcal", text: $appState.newFoodCalories).textFieldStyle(.roundedBorder).frame(width: 45)
                TextField("蛋白", text: $appState.newFoodProtein).textFieldStyle(.roundedBorder).frame(width: 40)
                TextField("脂肪", text: $appState.newFoodFat).textFieldStyle(.roundedBorder).frame(width: 40)
                TextField("碳水", text: $appState.newFoodCarbs).textFieldStyle(.roundedBorder).frame(width: 40)
                Button("添加") {
                    guard !appState.newFoodName.isEmpty, let cal = Double(appState.newFoodCalories) else { return }
                    appState.addFoodToDatabase(StoredFood(
                        name: appState.newFoodName, amount: appState.newFoodAmount.isEmpty ? "1份" : appState.newFoodAmount,
                        calories: cal, protein: Double(appState.newFoodProtein) ?? 0,
                        fat: Double(appState.newFoodFat) ?? 0, carbs: Double(appState.newFoodCarbs) ?? 0
                    ))
                    appState.newFoodName = ""; appState.newFoodAmount = ""; appState.newFoodCalories = ""
                    appState.newFoodProtein = ""; appState.newFoodFat = ""; appState.newFoodCarbs = ""
                }
                .buttonStyle(.borderedProminent).controlSize(.small)
            }
        }
        .padding(.horizontal, 40)
    }
}

struct PlanView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 目标概览
                VStack(alignment: .leading, spacing: 8) {
                    Text("目标设定")
                        .font(.headline)
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("训练日（一三五）").font(.subheadline).fontWeight(.medium)
                            Text("消耗 \(fmt(appState.plan.trainingExpenditure)) kcal")
                                .font(.caption).foregroundStyle(.secondary)
                            Text("摄入 \(fmt(appState.plan.trainingTarget.calories)) kcal")
                                .font(.caption).foregroundStyle(.secondary)
                            Text("缺口 \(Int(appState.plan.trainingTarget.calories - appState.plan.trainingExpenditure)) kcal")
                                .font(.caption).foregroundStyle(.red)
                            Text("蛋白 \(fmt(appState.plan.trainingTarget.protein))g  碳水 \(fmt(appState.plan.trainingTarget.carbs))g")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("休息日（二四六日）").font(.subheadline).fontWeight(.medium)
                            Text("消耗 \(fmt(appState.plan.restExpenditure)) kcal")
                                .font(.caption).foregroundStyle(.secondary)
                            Text("摄入 \(fmt(appState.plan.restTarget.calories)) kcal")
                                .font(.caption).foregroundStyle(.secondary)
                            Text("缺口 \(Int(appState.plan.restTarget.calories - appState.plan.restExpenditure)) kcal")
                                .font(.caption).foregroundStyle(.red)
                            Text("蛋白 \(fmt(appState.plan.restTarget.protein))g  碳水 \(fmt(appState.plan.restTarget.carbs))g")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

                // 训练日餐食
                MealPlanTable(
                    title: "训练日餐食（\(fmt(appState.plan.trainingTarget.calories))kcal）",
                    templates: DietPlan.trainingTemplates
                )

                // 休息日餐食
                MealPlanTable(
                    title: "休息日餐食（\(fmt(appState.plan.restTarget.calories))kcal）",
                    templates: DietPlan.restTemplates
                )
            }
            .padding()
        }
        .navigationTitle("计划配置")
    }
}

struct MealPlanTable: View {
    let title: String
    let templates: [MealTemplate]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            ForEach(templates) { t in
                VStack(alignment: .leading, spacing: 2) {
                    Text(t.name).font(.subheadline).fontWeight(.medium)
                    ForEach(t.foods) { f in
                        HStack {
                            Text(f.name).font(.caption)
                            Text(f.amount).font(.caption2).foregroundStyle(.secondary)
                            Spacer()
                            Text("\(fmt(f.calories))kcal").font(.caption2)
                            Text("蛋白\(fmt(f.protein))g").font(.caption2).foregroundStyle(.blue)
                            Text("碳水\(fmt(f.carbs))g").font(.caption2).foregroundStyle(.green)
                        }
                    }
                }
                .padding(.vertical, 4)
                if t.id != templates.last?.id { Divider() }
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section("AI 配置") {
                TextField("Base URL", text: $appState.apiBaseURL)
                SecureField("API Key", text: $appState.apiKey)
                TextField("模型名称", text: $appState.modelName)
                Text("API Key 仅保存在本机 macOS 钥匙串中，不会写入项目文件。远程 Base URL 必须使用 HTTPS；Key 会发送到你填写的服务。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("保存 AI 配置") {
                    appState.saveAIConfig()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            Section("个人信息") {
                HStack {
                    Text("身高")
                    TextField("cm", value: $appState.personalInfo.height, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    Text("cm")
                        .foregroundStyle(.secondary)
                }
                Button("保存") {
                    appState.savePersonalInfo()
                }
            }
            Section("数据管理") {
                Button("导出今日 CSV") {
                    if let url = appState.exportCSV() {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
        .padding()
        .navigationTitle("设置")
    }
}

struct AnalysisSheetView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("确认饮食记录")
                .font(.title2).bold()
            List {
                ForEach($appState.draftFoods) { $food in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            TextField("食物名", text: $food.name)
                                .font(.headline)
                            TextField("份量", text: $food.amount)
                                .frame(width: 120)
                        }
                        HStack(spacing: 8) {
                            HStack(spacing: 0) {
                                TextField("0", value: $food.calories, format: .number)
                                    .frame(width: 40)
                                Text("kcal")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            HStack(spacing: 0) {
                                TextField("0", value: $food.protein, format: .number)
                                    .frame(width: 32)
                                Text("蛋白质")
                                    .font(.caption2)
                                    .foregroundStyle(.blue)
                            }
                            HStack(spacing: 0) {
                                TextField("0", value: $food.fat, format: .number)
                                    .frame(width: 32)
                                Text("脂肪")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                            HStack(spacing: 0) {
                                TextField("0", value: $food.carbs, format: .number)
                                    .frame(width: 32)
                                Text("碳水")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .frame(minHeight: 300)
            HStack {
                Button("取消") {
                    appState.showAnalysisSheet = false
                    appState.draftFoods = []
                }
                Spacer()
                Button("确认保存") {
                    appState.saveDraftMeal()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}

// MARK: - 减脂分析

struct FatLossAnalysisView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("减脂数据分析")
                    .font(.title2).bold()

                DateStepper(date: $appState.selectedDate, onDateChanged: { appState.refreshMeals() })

                // 数据概览卡片
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    SummaryCard(
                        title: "体重",
                        value: appState.weightForDate(appState.selectedDate).map { String(format: "%.1f kg", $0) } ?? "--",
                        subtitle: appState.latestWeight.map { "最新 \(String(format: "%.1f", $0)) kg" } ?? "无记录"
                    )
                    SummaryCard(
                        title: "BMI",
                        value: String(format: "%.1f", appState.bmi),
                        subtitle: bmiCategory(appState.bmi)
                    )
                    SummaryCard(
                        title: "体脂率",
                        value: appState.bodyFatForDate(appState.selectedDate).map { String(format: "%.1f%%", $0) } ?? "--",
                        subtitle: "身高 \(String(format: "%.0f", appState.personalInfo.height))cm"
                    )
                    SummaryCard(
                        title: "今日热量缺口",
                        value: "\(fmt(abs(appState.calorieGap()))) kcal",
                        subtitle: appState.calorieGap() > 0 ? "高于目标" : "低于目标"
                    )
                }

                // 记录体重体脂
                VStack(spacing: 10) {
                    Text("记录今日数据")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            TextField("体重", text: $appState.manualWeightText)
                                .textFieldStyle(.plain)
                                .frame(width: 50)
                                .multilineTextAlignment(.center)
                            Text("kg")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                        HStack(spacing: 4) {
                            TextField("体脂", text: $appState.manualBodyFatText)
                                .textFieldStyle(.plain)
                                .frame(width: 40)
                                .multilineTextAlignment(.center)
                            Text("%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                        Button("保存") {
                            appState.saveManualWeight()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

                // AI 分析按钮
                Button(action: appState.analyzeFatLoss) {
                    if appState.isAnalyzingFatLoss {
                        Label("AI 分析中...", systemImage: "hourglass")
                    } else {
                        Label("AI 分析减脂进度", systemImage: "brain.head.profile")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(appState.isAnalyzingFatLoss)

                if let error = appState.analysisError {
                    Text(error).foregroundStyle(.red).font(.caption)
                }

                // 分析结果
                if !appState.fatLossAnalysisResult.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("AI 分析结果")
                            .font(.headline)
                        Text(appState.fatLossAnalysisResult)
                            .lineSpacing(4)
                    }
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }

            }
            .padding()
        }
        .navigationTitle("减脂分析")
    }
}

// MARK: - 做菜记录

struct CookingView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // AI 生成菜谱
            HStack {
                TextField("输入菜名让 AI 生成菜谱...", text: $appState.recipeGenerationPrompt)
                    .textFieldStyle(.roundedBorder)
                Button(action: appState.generateRecipe) {
                    if appState.isGeneratingRecipe {
                        Label("生成中", systemImage: "hourglass")
                    } else {
                        Label("AI 生成", systemImage: "sparkles")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(appState.isGeneratingRecipe)
            }

            Button {
                appState.newRecipeName = ""
                appState.recipeIngredients = ""
                appState.recipeSteps = ""
                appState.recipeNote = ""
                appState.showRecipeSheet = true
            } label: {
                Label("手动新增菜谱", systemImage: "plus")
            }

            if let error = appState.analysisError {
                Text(error).foregroundStyle(.red).font(.caption)
            }

            Divider()

            // 菜谱列表
            if appState.recipes.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "frying.pan")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("还没有菜谱记录")
                        .foregroundStyle(.secondary)
                    Text("手动新增或让 AI 帮你生成")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 40)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(appState.recipes, id: \.id) { recipe in
                            RecipeCardView(recipe: recipe)
                        }
                    }
                }
            }
        }
        .padding()
        .navigationTitle("做菜记录")
        .sheet(isPresented: $appState.showRecipeSheet) {
            RecipeEditSheet()
        }
    }
}

struct RecipeCardView: View {
    let recipe: RecipeEntity
    @EnvironmentObject var appState: AppState
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(recipe.name)
                    .font(.headline)
                Spacer()
                Text(DateFormatter.shortDate.string(from: recipe.createdAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(role: .destructive) {
                    appState.deleteRecipe(recipe)
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }

            Button(isExpanded ? "收起" : "展开查看详情") {
                withAnimation { isExpanded.toggle() }
            }
            .font(.caption)
            .foregroundStyle(.blue)

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    if !recipe.ingredients.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("🥬 食材").font(.subheadline).bold()
                            Text(recipe.ingredients)
                                .font(.body)
                        }
                    }
                    if !recipe.steps.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("📝 步骤").font(.subheadline).bold()
                            Text(recipe.steps)
                                .font(.body)
                        }
                    }
                    if !recipe.note.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("💡 小贴士").font(.subheadline).bold()
                            Text(recipe.note)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct RecipeEditSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(appState.newRecipeName.isEmpty ? "新增菜谱" : "编辑菜谱")
                .font(.title2).bold()

            TextField("菜名", text: $appState.newRecipeName)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading) {
                Text("食材清单").font(.subheadline)
                TextEditor(text: $appState.recipeIngredients)
                    .frame(minHeight: 80)
                    .padding(4)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
            }

            VStack(alignment: .leading) {
                Text("做菜步骤").font(.subheadline)
                TextEditor(text: $appState.recipeSteps)
                    .frame(minHeight: 120)
                    .padding(4)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
            }

            VStack(alignment: .leading) {
                Text("小贴士").font(.subheadline)
                TextEditor(text: $appState.recipeNote)
                    .frame(minHeight: 60)
                    .padding(4)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
            }

            HStack {
                Button("取消") {
                    appState.showRecipeSheet = false
                }
                Spacer()
                Button("保存菜谱") {
                    appState.saveRecipe(
                        name: appState.newRecipeName.isEmpty ? "未命名菜谱" : appState.newRecipeName,
                        ingredients: appState.recipeIngredients,
                        steps: appState.recipeSteps,
                        note: appState.recipeNote
                    )
                    appState.showRecipeSheet = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(appState.newRecipeName.isEmpty && appState.recipeSteps.isEmpty)
            }
        }
        .padding()
        .frame(minWidth: 500, minHeight: 500)
    }
}

// MARK: - BMI 辅助

struct TemplateBar: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        let dayType = appState.todayType()
        let templates: [MealTemplate] = dayType == .training
            ? DietPlan.trainingTemplates
            : DietPlan.restTemplates
        VStack(alignment: .leading, spacing: 6) {
            Text("快捷模板（\(dayType.rawValue)）").font(.caption).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(templates) { template in
                        Button {
                            appState.selectedMealType = mealTypeForTemplate(template.name)
                            appState.applyTemplate(template)
                        } label: {
                            VStack(spacing: 2) {
                                Text(template.name).font(.subheadline).fontWeight(.medium)
                                Text("\(fmt(template.foods.reduce(0) { $0 + $1.calories })) kcal")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct ManualInputView: View {
    @EnvironmentObject var appState: AppState
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    TextField("热量", text: $appState.manualCalories).textFieldStyle(.plain).font(.title3)
                        .multilineTextAlignment(.center).padding(10)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    Text("kcal").font(.caption2).foregroundStyle(.secondary)
                }
                VStack(spacing: 4) {
                    TextField("蛋白质", text: $appState.manualProtein).textFieldStyle(.plain).font(.title3)
                        .multilineTextAlignment(.center).padding(10)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    Text("蛋白质 g").font(.caption2).foregroundStyle(.blue)
                }
            }
            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    TextField("脂肪", text: $appState.manualFat).textFieldStyle(.plain).font(.title3)
                        .multilineTextAlignment(.center).padding(10)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    Text("脂肪 g").font(.caption2).foregroundStyle(.orange)
                }
                VStack(spacing: 4) {
                    TextField("碳水", text: $appState.manualCarbs).textFieldStyle(.plain).font(.title3)
                        .multilineTextAlignment(.center).padding(10)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    Text("碳水 g").font(.caption2).foregroundStyle(.green)
                }
            }
        }
        Button(action: appState.quickSave) {
            Label("记录", systemImage: "plus.circle").frame(maxWidth: 200)
        }
        .buttonStyle(.borderedProminent).controlSize(.large)
    }
}

struct AIInputView: View {
    @EnvironmentObject var appState: AppState

    private var isSuggest: Bool { appState.analysisMode == 1 }

    var body: some View {
        Picker("", selection: $appState.analysisMode) {
            Text("记录").tag(0)
            Text("建议分量").tag(1)
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 260)

        if appState.analysisMode == 0 { TemplateBar() }

        TextField(
            isSuggest ? "列出菜名，AI建议每样吃多少…" : "例如：中午吃了红烧肉、炒青菜、紫菜汤",
            text: $appState.analysisText
        )
        .textFieldStyle(.plain)
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

        Button(action: { isSuggest ? appState.suggestPortions() : appState.analyzeText() }) {
            if appState.isAnalyzing {
                Label("分析中...", systemImage: "hourglass").frame(maxWidth: 200)
            } else if isSuggest {
                Label("建议分量", systemImage: "lightbulb").frame(maxWidth: 200)
            } else {
                Label("记录", systemImage: "sparkles").frame(maxWidth: 200)
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(appState.isAnalyzing)
    }
}

func bmiCategory(_ bmi: Double) -> String {
    switch bmi {
    case ..<18.5: return "偏瘦"
    case 18.5..<24: return "正常"
    case 24..<28: return "偏胖"
    default: return "肥胖"
    }
}

struct DateStepper: View {
    @Binding var date: Date
    var onDateChanged: () -> Void

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "M月d日 EEEE"
        f.locale = Locale(identifier: "zh_CN")
        return f.string(from: date)
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var body: some View {
        HStack(spacing: 0) {
            Button {
                date = Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
                onDateChanged()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .padding(10)
            }
            .buttonStyle(.plain)

            Button {
                date = Calendar.current.startOfDay(for: Date())
                onDateChanged()
            } label: {
                Text(dateString)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(minWidth: 160)
            }
            .buttonStyle(.plain)

            Button {
                date = Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date
                onDateChanged()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .padding(10)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(.thinMaterial, in: Capsule())
    }
}

func fmt(_ d: Double) -> String { String(format: "%.1f", d) }

func mealTypeForTemplate(_ name: String) -> MealType {
    switch name {
    case "早餐": return .breakfast
    case "午餐": return .lunch
    case "晚餐": return .dinner
    default: return .snack
    }
}

func bmiColor(_ bmi: Double) -> Color {
    switch bmi {
    case ..<18.5: return .orange
    case 18.5..<24: return .green
    case 24..<28: return .orange
    default: return .red
    }
}
