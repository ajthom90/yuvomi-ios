import Foundation

// MARK: - Recipes

struct Recipe: Identifiable, Equatable, Sendable {
    let id: Int
    var title: String
    var notes: String?
    var recipeURL: String?
    var mealTypes: [String]
    var ingredients: [RecipeIngredient]
    var source: String?
    var creatorName: String?
}

struct RecipeIngredient: Identifiable, Equatable, Sendable, Codable {
    let id: Int
    var name: String
    var quantity: String?
    var category: String?

    enum CodingKeys: String, CodingKey {
        case id, name, quantity, category
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id) ?? (try c.decodeIfPresent(String.self, forKey: .name) ?? "").hashValue
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        quantity = try c.decodeIfPresent(String.self, forKey: .quantity)
        category = try c.decodeIfPresent(String.self, forKey: .category)
    }
}

extension Recipe: Codable {
    enum CodingKeys: String, CodingKey {
        case id, title, notes, ingredients, source
        case recipeURL = "recipe_url"
        case mealTypes = "meal_types"
        case creatorName = "creator_name"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        recipeURL = try c.decodeIfPresent(String.self, forKey: .recipeURL)
        mealTypes = try c.decodeIfPresent([String].self, forKey: .mealTypes) ?? []
        ingredients = try c.decodeIfPresent([RecipeIngredient].self, forKey: .ingredients) ?? []
        source = try c.decodeIfPresent(String.self, forKey: .source)
        creatorName = try c.decodeIfPresent(String.self, forKey: .creatorName)
    }
}

// MARK: - Meals

struct MealPlanEntry: Identifiable, Equatable, Sendable {
    let id: Int
    var date: String
    var mealType: String
    var title: String
    var notes: String?
    var recipeId: Int?
    var recipeURL: String?
    var ingredients: [MealIngredient]
    var recipeIngredientCount: Int
}

struct MealIngredient: Identifiable, Equatable, Sendable, Codable {
    let id: Int
    var name: String
    var quantity: String?
    var category: String?
    var onShoppingList: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, quantity, category
        case onShoppingList = "on_shopping_list"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        quantity = try c.decodeIfPresent(String.self, forKey: .quantity)
        category = try c.decodeIfPresent(String.self, forKey: .category)
        onShoppingList = JSONHelpers.decodeBool(from: c, forKey: CodingKeys.onShoppingList)
    }
}

extension MealPlanEntry: Codable {
    enum CodingKeys: String, CodingKey {
        case id, date, title, notes, ingredients
        case mealType = "meal_type"
        case recipeId = "recipe_id"
        case recipeURL = "recipe_url"
        case recipeIngredientCount = "recipe_ingredient_count"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        date = try c.decodeIfPresent(String.self, forKey: .date) ?? ""
        mealType = try c.decodeIfPresent(String.self, forKey: .mealType) ?? "dinner"
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        recipeId = try c.decodeIfPresent(Int.self, forKey: .recipeId)
        recipeURL = try c.decodeIfPresent(String.self, forKey: .recipeURL)
        ingredients = try c.decodeIfPresent([MealIngredient].self, forKey: .ingredients) ?? []
        recipeIngredientCount = try c.decodeIfPresent(Int.self, forKey: .recipeIngredientCount) ?? 0
    }
}

struct MealsWeekResponse: Decodable {
    let data: [MealPlanEntry]
    let weekStart: String?
    let weekEnd: String?
}

enum MealType: String, CaseIterable, Identifiable {
    case breakfast, lunch, dinner, snack
    var id: String { rawValue }
    var title: String {
        switch self {
        case .breakfast: "Breakfast"
        case .lunch: "Lunch"
        case .dinner: "Dinner"
        case .snack: "Snack"
        }
    }
    var systemImage: String {
        switch self {
        case .breakfast: "cup.and.saucer.fill"
        case .lunch: "takeoutbag.and.cup.and.straw.fill"
        case .dinner: "fork.knife"
        case .snack: "carrot.fill"
        }
    }
}

// MARK: - Pantry

struct PantryItem: Identifiable, Equatable, Sendable {
    let id: Int
    var name: String
    var quantity: Double
    var unit: String?
    var locationId: Int?
    var locationName: String?
    var category: String?
    var expiresOn: String?
    var minQuantity: Double?
    var notes: String?

    var isLow: Bool {
        guard let min = minQuantity else { return quantity <= 0 }
        return quantity <= min
    }

    var isOut: Bool { quantity <= 0 }
}

extension PantryItem: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, quantity, unit, category, notes
        case locationId = "location_id"
        case locationName = "location_name"
        case expiresOn = "expires_on"
        case minQuantity = "min_quantity"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        if let d = try? c.decode(Double.self, forKey: .quantity) {
            quantity = d
        } else if let i = try? c.decode(Int.self, forKey: .quantity) {
            quantity = Double(i)
        } else {
            quantity = 0
        }
        unit = try c.decodeIfPresent(String.self, forKey: .unit)
        locationId = try c.decodeIfPresent(Int.self, forKey: .locationId)
        locationName = try c.decodeIfPresent(String.self, forKey: .locationName)
        category = try c.decodeIfPresent(String.self, forKey: .category)
        expiresOn = try c.decodeIfPresent(String.self, forKey: .expiresOn)
        if let d = try? c.decode(Double.self, forKey: .minQuantity) {
            minQuantity = d
        } else if let i = try? c.decode(Int.self, forKey: .minQuantity) {
            minQuantity = Double(i)
        } else {
            minQuantity = nil
        }
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
    }
}

struct PantryLocation: Identifiable, Codable, Equatable, Sendable {
    let id: Int
    var name: String
    var icon: String?
    var sortOrder: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, icon
        case sortOrder = "sort_order"
    }
}

struct PantryListResponse: Decodable {
    let data: [PantryItem]
    let locations: [PantryLocation]
}

struct TransferResult: Decodable {
    let transferred: Int?
    let skipped: Int?
    let added: Int?
    let merged: Int?
    let addedIds: [Int]?

    enum CodingKeys: String, CodingKey {
        case transferred, skipped, added, merged
        case addedIds = "added_ids"
    }
}
