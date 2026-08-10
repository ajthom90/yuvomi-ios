import Foundation

struct VersionInfo: Codable, Equatable, Sendable {
    let version: String?
    let appName: String
    let setupRequired: Bool
    let passwordResetEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case version
        case appName = "app_name"
        case setupRequired = "setup_required"
        case passwordResetEnabled = "password_reset_enabled"
    }
}
