import Foundation

/// Application Support–backed secret store used when Keychain is unavailable
/// (unsigned simulator builds, missing application-identifier entitlement).
final class FileSecretStore: SecretStore, @unchecked Sendable {
    private let directory: URL
    private let lock = NSLock()

    init(directory: URL? = nil) throws {
        if let directory {
            self.directory = directory
        } else {
            let root = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            self.directory = root.appendingPathComponent("YuvomiSecrets", isDirectory: true)
        }
        try FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var dir = self.directory
        try? dir.setResourceValues(values)
    }

    func set(_ data: Data, account: String) throws {
        lock.lock()
        defer { lock.unlock() }
        try data.write(to: fileURL(for: account), options: .atomic)
    }

    func get(account: String) throws -> Data? {
        lock.lock()
        defer { lock.unlock() }
        let url = fileURL(for: account)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }

    func delete(account: String) throws {
        lock.lock()
        defer { lock.unlock() }
        let url = fileURL(for: account)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    private func fileURL(for account: String) -> URL {
        let safe = account.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? account
        return directory.appendingPathComponent("\(safe).bin")
    }
}
