import Foundation

enum AuthMethod: String, Codable, Sendable, Equatable {
    case apiToken
    case session
}

struct ServerProfile: Codable, Equatable, Sendable {
    var serverURL: String
    var method: AuthMethod
    var displayName: String?
    var username: String?
    var userId: Int?
}
