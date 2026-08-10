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
