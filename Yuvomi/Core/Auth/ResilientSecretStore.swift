import Foundation

/// Tries Keychain first; on entitlement / access failures falls back to file storage.
final class ResilientSecretStore: SecretStore, @unchecked Sendable {
    private let keychain: SecretStore
    private let file: SecretStore
    private let lock = NSLock()
    private var preferFile = false

    init(keychain: SecretStore = KeychainStore(), file: SecretStore) {
        self.keychain = keychain
        self.file = file
    }

    static func makeDefault() -> ResilientSecretStore {
        let file: SecretStore
        do {
            file = try FileSecretStore()
        } catch {
            AuthLogger.log.error("FileSecretStore init failed: \(error.localizedDescription, privacy: .public)")
            file = InMemorySecretStore()
        }
        return ResilientSecretStore(file: file)
    }

    func set(_ data: Data, account: String) throws {
        lock.lock()
        defer { lock.unlock() }
        if preferFile {
            try file.set(data, account: account)
            return
        }
        do {
            try keychain.set(data, account: account)
        } catch {
            AuthLogger.log.error(
                "Keychain set failed, falling back to file store: \(error.localizedDescription, privacy: .public)"
            )
            preferFile = true
            try file.set(data, account: account)
        }
    }

    func get(account: String) throws -> Data? {
        lock.lock()
        defer { lock.unlock() }
        if preferFile {
            return try file.get(account: account)
        }
        do {
            if let data = try keychain.get(account: account) {
                return data
            }
            // Also check file store for migration / prior fallback writes.
            return try file.get(account: account)
        } catch {
            AuthLogger.log.error(
                "Keychain get failed, falling back to file store: \(error.localizedDescription, privacy: .public)"
            )
            preferFile = true
            return try file.get(account: account)
        }
    }

    func delete(account: String) throws {
        lock.lock()
        defer { lock.unlock() }
        // Best-effort both stores.
        if !preferFile {
            try? keychain.delete(account: account)
        }
        try file.delete(account: account)
    }
}
