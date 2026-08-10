import Foundation

struct User: Codable, Equatable, Identifiable, Sendable {
    let id: Int
    let username: String
    let displayName: String
    let avatarColor: String
    let role: String
    let familyRole: String
    let phone: String?
    let email: String?
    let birthDate: String?

    var isAdmin: Bool { role == "admin" }

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case avatarColor = "avatar_color"
        case role
        case familyRole = "family_role"
        case phone
        case email
        case birthDate = "birth_date"
    }

    init(
        id: Int,
        username: String,
        displayName: String,
        avatarColor: String,
        role: String,
        familyRole: String,
        phone: String? = nil,
        email: String? = nil,
        birthDate: String? = nil
    ) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.avatarColor = avatarColor
        self.role = role
        self.familyRole = familyRole
        self.phone = phone
        self.email = email
        self.birthDate = birthDate
    }

    /// Tolerant decode: Yuvomi may omit optional profile fields; older rows
    /// can lack `family_role` in edge cases; `id` may arrive as number or string.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let intId = try? c.decode(Int.self, forKey: .id) {
            id = intId
        } else if let stringId = try? c.decode(String.self, forKey: .id), let intId = Int(stringId) {
            id = intId
        } else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: c, debugDescription: "Expected user id")
        }
        username = try c.decodeIfPresent(String.self, forKey: .username) ?? ""
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName)
            ?? (username.isEmpty ? "Member" : username)
        avatarColor = try c.decodeIfPresent(String.self, forKey: .avatarColor) ?? "#4F4DC9"
        role = try c.decodeIfPresent(String.self, forKey: .role) ?? "member"
        familyRole = try c.decodeIfPresent(String.self, forKey: .familyRole) ?? "other"
        phone = try c.decodeIfPresent(String.self, forKey: .phone)
        email = try c.decodeIfPresent(String.self, forKey: .email)
        birthDate = try c.decodeIfPresent(String.self, forKey: .birthDate)
    }
}

struct MeResponse: Codable, Equatable, Sendable {
    let user: User
    let csrfToken: String?

    enum CodingKeys: String, CodingKey {
        case user
        case csrfToken
    }
}

typealias LoginResponse = MeResponse
