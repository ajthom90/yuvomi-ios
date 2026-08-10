import Foundation

struct CachedPayload: Equatable, Sendable {
    let data: Data
    let savedAt: Date
}

actor ResponseCache {
    private let directory: URL
    private let fileManager: FileManager

    init(directory: URL, fileManager: FileManager = .default) {
        self.directory = directory
        self.fileManager = fileManager
    }

    static func applicationSupportCache() throws -> ResponseCache {
        let root = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = root.appendingPathComponent("YuvomiCache", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return ResponseCache(directory: dir)
    }

    static func key(host: String, userId: Int, path: String) -> String {
        let raw = "\(host)|\(userId)|\(path)"
        let digest = raw.utf8.reduce(into: UInt64(5381)) { hash, byte in
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }
        return String(digest, radix: 16)
    }

    func store(key: String, data: Data) throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let payload = CacheEnvelope(savedAt: Date(), dataBase64: data.base64EncodedString())
        let encoded = try JSONEncoder().encode(payload)
        try encoded.write(to: fileURL(for: key), options: .atomic)
    }

    func load(key: String) -> CachedPayload? {
        let url = fileURL(for: key)
        guard let encoded = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(CacheEnvelope.self, from: encoded),
              let data = Data(base64Encoded: payload.dataBase64)
        else {
            return nil
        }
        return CachedPayload(data: data, savedAt: payload.savedAt)
    }

    func clearAll() throws {
        guard fileManager.fileExists(atPath: directory.path) else { return }
        try fileManager.removeItem(at: directory)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func fileURL(for key: String) -> URL {
        directory.appendingPathComponent("\(key).json")
    }
}

private struct CacheEnvelope: Codable {
    let savedAt: Date
    let dataBase64: String
}
