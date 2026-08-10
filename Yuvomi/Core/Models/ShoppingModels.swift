import Foundation

struct ShoppingList: Identifiable, Codable, Equatable, Sendable {
    let id: Int
    var name: String
    var createdAt: String?
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ShoppingItem: Identifiable, Equatable, Sendable {
    let id: Int
    var listId: Int
    var name: String
    var quantity: String?
    var category: String?
    var isChecked: Bool
    var notes: String?
    var sortOrder: Int
}

extension ShoppingItem: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, quantity, category, notes
        case listId = "list_id"
        case isChecked = "is_checked"
        case sortOrder = "sort_order"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        listId = try c.decodeIfPresent(Int.self, forKey: .listId) ?? 0
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        quantity = try c.decodeIfPresent(String.self, forKey: .quantity)
        category = try c.decodeIfPresent(String.self, forKey: .category)
        isChecked = JSONHelpers.decodeBool(from: c, forKey: CodingKeys.isChecked)
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        sortOrder = try c.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(listId, forKey: .listId)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(quantity, forKey: .quantity)
        try c.encodeIfPresent(category, forKey: .category)
        try c.encode(isChecked, forKey: .isChecked)
        try c.encodeIfPresent(notes, forKey: .notes)
        try c.encode(sortOrder, forKey: .sortOrder)
    }
}

struct ShoppingItemsResponse: Decodable {
    let data: [ShoppingItem]
    let list: ShoppingList?
}
