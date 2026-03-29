import SwiftUI

struct QuickAddView: View {
    @Bindable var viewModel: FoodLogViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var mode: AddMode = .favorites
    @State private var selectedMealType: MealType = .lunch

    enum AddMode: String, CaseIterable {
        case favorites = "Favorites"
        case recipe = "Recipe"
        case ingredient = "Ingredient"
        case manual = "Manual"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Mode", selection: $mode) {
                    ForEach(AddMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 4)

                switch mode {
                case .favorites: FavoritesTab(viewModel: viewModel, mealType: $selectedMealType, dismiss: dismiss)
                case .recipe: RecipeTab(viewModel: viewModel, mealType: $selectedMealType, dismiss: dismiss)
                case .ingredient: IngredientTab(viewModel: viewModel, mealType: $selectedMealType, dismiss: dismiss)
                case .manual: ManualTab(viewModel: viewModel, mealType: $selectedMealType, dismiss: dismiss)
                }
            }
            .background(Theme.background)
            .navigationTitle("Quick Add").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }
}

// MARK: - Favorites Tab

private struct FavoritesTab: View {
    @Bindable var viewModel: FoodLogViewModel
    @Binding var mealType: MealType
    let dismiss: DismissAction
    @State private var favorites: [FavoriteFood] = []
    @State private var showingAdd = false
    private let database = AppDatabase.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Picker("", selection: $mealType) {
                    ForEach(MealType.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }.pickerStyle(.segmented).padding(.horizontal, 12)

                if favorites.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "star").font(.system(size: 36)).foregroundStyle(Theme.accent.opacity(0.5))
                        Text("No favorites yet").font(.subheadline).foregroundStyle(.secondary)
                        Text("Add foods you eat daily for one-tap logging").font(.caption).foregroundStyle(.tertiary)
                    }.padding(.top, 30)
                } else {
                    ForEach(favorites) { fav in
                        Button {
                            viewModel.quickAdd(name: fav.name, calories: fav.calories * fav.defaultServings,
                                               proteinG: fav.proteinG * fav.defaultServings, carbsG: fav.carbsG * fav.defaultServings,
                                               fatG: fav.fatG * fav.defaultServings, fiberG: fav.fiberG * fav.defaultServings,
                                               mealType: mealType)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(fav.name).font(.subheadline.weight(.medium))
                                        if fav.isRecipe {
                                            Text("RECIPE").font(.system(size: 8).weight(.bold))
                                                .padding(.horizontal, 4).padding(.vertical, 1)
                                                .background(Theme.accent.opacity(0.2), in: RoundedRectangle(cornerRadius: 3))
                                                .foregroundStyle(Theme.accent)
                                        }
                                    }
                                    Text(fav.macroSummary).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "plus.circle.fill").foregroundStyle(Theme.accent)
                            }
                            .padding(.vertical, 8).padding(.horizontal, 14)
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            if let id = fav.id {
                                Button(role: .destructive) { try? database.deleteFavorite(id: id); loadFavorites() } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }

                Button { showingAdd = true } label: {
                    Label("Add Favorite", systemImage: "star.fill").frame(maxWidth: .infinity)
                }.buttonStyle(.bordered).padding(.horizontal, 12).padding(.top, 8)
            }.padding(.top, 8)
        }
        .onAppear { loadFavorites() }
        .sheet(isPresented: $showingAdd) { AddFavoriteView { loadFavorites() } }
    }

    private func loadFavorites() { favorites = (try? database.fetchFavorites()) ?? [] }
}

// MARK: - Add Favorite Sheet

private struct AddFavoriteView: View {
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var fiber = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Food") { TextField("Name (e.g., Morning Oats)", text: $name) }
                Section("Per Serving") {
                    field("Calories", value: $calories, unit: "kcal")
                    field("Protein", value: $protein, unit: "g")
                    field("Carbs", value: $carbs, unit: "g")
                    field("Fat", value: $fat, unit: "g")
                    field("Fiber", value: $fiber, unit: "g")
                }
            }
            .navigationTitle("Add Favorite").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var fav = FavoriteFood(name: name, calories: Double(calories) ?? 0,
                                               proteinG: Double(protein) ?? 0, carbsG: Double(carbs) ?? 0,
                                               fatG: Double(fat) ?? 0, fiberG: Double(fiber) ?? 0)
                        try? AppDatabase.shared.saveFavorite(&fav)
                        onSave(); dismiss()
                    }.disabled(name.isEmpty || calories.isEmpty)
                }
            }
        }
    }

    private func field(_ label: String, value: Binding<String>, unit: String) -> some View {
        HStack {
            Text(label); Spacer()
            TextField("0", text: value).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 80)
            Text(unit).font(.caption).foregroundStyle(.secondary).frame(width: 35)
        }
    }
}

// MARK: - Recipe Tab (combine multiple items)

private struct RecipeTab: View {
    @Bindable var viewModel: FoodLogViewModel
    @Binding var mealType: MealType
    let dismiss: DismissAction
    @State private var recipeName = ""
    @State private var items: [(name: String, cal: Double, p: Double, c: Double, f: Double, fb: Double)] = []
    @State private var showingAddItem = false

    var totalCal: Double { items.reduce(0) { $0 + $1.cal } }
    var totalP: Double { items.reduce(0) { $0 + $1.p } }
    var totalC: Double { items.reduce(0) { $0 + $1.c } }
    var totalF: Double { items.reduce(0) { $0 + $1.f } }
    var totalFb: Double { items.reduce(0) { $0 + $1.fb } }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                TextField("Recipe name (e.g., Post-workout meal)", text: $recipeName)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 12)

                // Items list
                ForEach(items.indices, id: \.self) { i in
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(items[i].name).font(.subheadline)
                            Text("\(Int(items[i].cal))cal \(Int(items[i].p))P \(Int(items[i].c))C \(Int(items[i].f))F")
                                .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { items.remove(at: i) } label: {
                            Image(systemName: "xmark.circle.fill").font(.caption).foregroundStyle(.tertiary)
                        }.buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 4)
                }

                Button { showingAddItem = true } label: {
                    Label("Add Item", systemImage: "plus.circle").frame(maxWidth: .infinity)
                }.buttonStyle(.bordered).padding(.horizontal, 12)

                if !items.isEmpty {
                    // Total
                    VStack(spacing: 4) {
                        Text("\(Int(totalCal)) cal total").font(.headline.monospacedDigit())
                        Text("\(Int(totalP))P \(Int(totalC))C \(Int(totalF))F \(Int(totalFb))fiber")
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }.card().padding(.horizontal, 12)

                    Picker("", selection: $mealType) {
                        ForEach(MealType.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }.pickerStyle(.segmented).padding(.horizontal, 12)

                    HStack(spacing: 8) {
                        Button {
                            viewModel.quickAdd(name: recipeName.isEmpty ? "Recipe" : recipeName,
                                               calories: totalCal, proteinG: totalP, carbsG: totalC, fatG: totalF, fiberG: totalFb,
                                               mealType: mealType)
                            dismiss()
                        } label: {
                            Label("Log Recipe", systemImage: "plus.circle.fill").frame(maxWidth: .infinity)
                        }.buttonStyle(.borderedProminent).tint(Theme.accent)

                        Button {
                            var fav = FavoriteFood(name: recipeName.isEmpty ? "Recipe" : recipeName,
                                                   calories: totalCal, proteinG: totalP, carbsG: totalC, fatG: totalF, fiberG: totalFb, isRecipe: true)
                            try? AppDatabase.shared.saveFavorite(&fav)
                            viewModel.quickAdd(name: fav.name, calories: totalCal, proteinG: totalP, carbsG: totalC, fatG: totalF, fiberG: totalFb, mealType: mealType)
                            dismiss()
                        } label: {
                            Label("Log + Save", systemImage: "star.fill").frame(maxWidth: .infinity)
                        }.buttonStyle(.bordered)
                    }.padding(.horizontal, 12)
                }
            }.padding(.top, 8)
        }
        .sheet(isPresented: $showingAddItem) {
            RecipeItemPicker { name, cal, p, c, f, fb in
                items.append((name, cal, p, c, f, fb))
            }
        }
    }
}

// MARK: - Recipe Item Picker (search DB + ingredients)

private struct RecipeItemPicker: View {
    let onAdd: (String, Double, Double, Double, Double, Double) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var dbResults: [Food] = []
    @State private var amount = "1"
    @State private var selectedUnit: ServingUnit = .grams

    private var ingredientResults: [RawIngredient] {
        if query.isEmpty { return [] }
        return RawIngredient.allCases.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search food or ingredient", text: $query)
                        .textFieldStyle(.plain).autocorrectionDisabled()
                        .onChange(of: query) { _, _ in
                            dbResults = (try? AppDatabase.shared.searchFoods(query: query)) ?? []
                        }
                }.padding().background(.ultraThinMaterial)

                List {
                    // Database foods
                    ForEach(dbResults) { food in
                        Button {
                            onAdd(food.name, food.calories, food.proteinG, food.carbsG, food.fatG, food.fiberG)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(food.name).font(.subheadline)
                                Text("\(food.macroSummary) · \(Int(food.servingSize))\(food.servingUnit)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }.tint(.primary)
                    }

                    // Raw ingredients
                    ForEach(ingredientResults) { ing in
                        Button {
                            onAdd(ing.name, ing.caloriesPer100g, ing.proteinPer100g, ing.carbsPer100g, ing.fatPer100g, ing.fiberPer100g)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ing.name).font(.subheadline)
                                Text("\(Int(ing.caloriesPer100g))cal per 100g").font(.caption).foregroundStyle(.secondary)
                            }
                        }.tint(.primary)
                    }
                }.listStyle(.plain)
            }
            .navigationTitle("Add Item").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

// MARK: - Ingredient Tab

private struct IngredientTab: View {
    @Bindable var viewModel: FoodLogViewModel
    @Binding var mealType: MealType
    let dismiss: DismissAction
    @State private var search = ""
    @State private var selected: RawIngredient?
    @State private var amount = ""
    @State private var unit: ServingUnit = .grams

    private var filtered: [RawIngredient] {
        if search.isEmpty { return RawIngredient.allCases.map { $0 } }
        return RawIngredient.allCases.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        if selected == nil {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search ingredient", text: $search).textFieldStyle(.plain).autocorrectionDisabled()
                }.padding().background(.ultraThinMaterial)

                List {
                    ForEach(filtered) { ing in
                        Button {
                            selected = ing; unit = ing.typicalUnit; amount = ""
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ing.name).font(.subheadline)
                                Text("\(Int(ing.caloriesPer100g))cal \(Int(ing.proteinPer100g))P \(Int(ing.carbsPer100g))C \(Int(ing.fatPer100g))F /100g")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }.tint(.primary)
                    }
                }.listStyle(.plain)
            }
        } else {
            ingredientAmountView
        }
    }

    private var ingredientAmountView: some View {
        let ing = selected!
        let grams = unit.toGrams(Double(amount) ?? 0, ingredient: ing)
        let cal = ing.caloriesPer100g * grams / 100

        return ScrollView {
            VStack(spacing: 14) {
                HStack {
                    Text(ing.name).font(.headline)
                    Spacer()
                    Button("Change") { selected = nil }.font(.caption).foregroundStyle(Theme.accent)
                }.card().padding(.horizontal, 12)

                VStack(spacing: 8) {
                    HStack {
                        TextField("Amount", text: $amount).keyboardType(.decimalPad).font(.title2.monospacedDigit())
                        Picker("", selection: $unit) {
                            ForEach(ServingUnit.allCases, id: \.self) { Text($0.label).tag($0) }
                        }.pickerStyle(.menu)
                    }

                    HStack(spacing: 6) {
                        ForEach(quickAmounts(ing), id: \.0) { qa in
                            Button(qa.0) { amount = qa.1; unit = qa.2 }.font(.caption).buttonStyle(.bordered)
                        }
                    }
                }.card().padding(.horizontal, 12)

                if (Double(amount) ?? 0) > 0 {
                    VStack(spacing: 4) {
                        Text("\(Int(cal)) cal").font(.title2.weight(.bold).monospacedDigit())
                        Text("\(Int(ing.proteinPer100g*grams/100))P \(Int(ing.carbsPer100g*grams/100))C \(Int(ing.fatPer100g*grams/100))F")
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }.card().padding(.horizontal, 12)
                }

                Picker("", selection: $mealType) {
                    ForEach(MealType.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }.pickerStyle(.segmented).padding(.horizontal, 12)

                Button {
                    viewModel.quickAdd(name: "\(ing.name) (\(amount)\(unit.label))",
                                       calories: cal, proteinG: ing.proteinPer100g*grams/100,
                                       carbsG: ing.carbsPer100g*grams/100, fatG: ing.fatPer100g*grams/100,
                                       fiberG: ing.fiberPer100g*grams/100, mealType: mealType)
                    dismiss()
                } label: {
                    Label("Log", systemImage: "plus.circle.fill").frame(maxWidth: .infinity)
                }.buttonStyle(.borderedProminent).tint(Theme.accent).disabled((Double(amount) ?? 0) == 0)
                .padding(.horizontal, 12)
            }.padding(.top, 8)
        }
    }

    private func quickAmounts(_ ing: RawIngredient) -> [(String, String, ServingUnit)] {
        switch ing.typicalUnit {
        case .grams: return [("50g","50",.grams),("100g","100",.grams),("200g","200",.grams)]
        case .cups: return [("½cup","0.5",.cups),("1cup","1",.cups),("2cups","2",.cups)]
        case .tablespoons: return [("1tbsp","1",.tablespoons),("2tbsp","2",.tablespoons)]
        case .pieces: return [("1","1",.pieces),("2","2",.pieces),("3","3",.pieces)]
        case .ml: return [("100ml","100",.ml),("200ml","200",.ml),("1cup","1",.cups)]
        default: return [("50g","50",.grams),("100g","100",.grams)]
        }
    }
}

// MARK: - Manual Tab

private struct ManualTab: View {
    @Bindable var viewModel: FoodLogViewModel
    @Binding var mealType: MealType
    let dismiss: DismissAction
    @State private var name = ""
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var fiber = ""

    var body: some View {
        Form {
            Section("Food") { TextField("Name", text: $name) }
            Section("Macros") {
                field("Calories", value: $calories, unit: "kcal")
                field("Protein", value: $protein, unit: "g")
                field("Carbs", value: $carbs, unit: "g")
                field("Fat", value: $fat, unit: "g")
                field("Fiber", value: $fiber, unit: "g")
            }
            Section("Meal") {
                Picker("", selection: $mealType) {
                    ForEach(MealType.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }.pickerStyle(.segmented)
            }
            Section {
                Button {
                    viewModel.quickAdd(name: name.isEmpty ? "Quick Add" : name,
                                       calories: Double(calories) ?? 0, proteinG: Double(protein) ?? 0,
                                       carbsG: Double(carbs) ?? 0, fatG: Double(fat) ?? 0, fiberG: Double(fiber) ?? 0,
                                       mealType: mealType)
                    dismiss()
                } label: {
                    Label("Log Food", systemImage: "plus.circle.fill").frame(maxWidth: .infinity)
                }.buttonStyle(.borderedProminent).tint(Theme.accent).disabled(calories.isEmpty)
            }
        }
    }

    private func field(_ label: String, value: Binding<String>, unit: String) -> some View {
        HStack {
            Text(label); Spacer()
            TextField("0", text: value).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 80)
            Text(unit).font(.caption).foregroundStyle(.secondary).frame(width: 35)
        }
    }
}
