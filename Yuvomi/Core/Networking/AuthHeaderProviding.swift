import Foundation

protocol AuthHeaderProviding: AnyObject {
    func authorize(_ request: inout URLRequest) async throws
}

/// No-op provider for public endpoints / tests.
final class NoAuthProvider: AuthHeaderProviding {
    func authorize(_ request: inout URLRequest) async throws {}
}
