import Foundation

/// The STAC spec version SwiftSTAC writes as `stac_version` and the API
/// version it claims when relevant. Mirrors `pystac.version.STACVersion`.
///
/// The override slot is concurrency-safe via an internal lock so that
/// `setSTACVersion` / `getSTACVersion` can be called from any isolation
/// domain (or no isolation at all).
public enum STACVersion {
    public static let defaultSTACVersion = "1.1.0"
    public static let defaultSTACAPIVersion = "1.0.0"

    /// Override environment variable name, matching pystac.
    public static let overrideVersionEnvVar = "PYSTAC_STAC_VERSION_OVERRIDE"

    /// Returns the STAC version that SwiftSTAC emits.
    public static func getSTACVersion() -> String {
        if let v = OverrideStorage.shared.get() { return v }
        if let env = ProcessInfo.processInfo.environment[overrideVersionEnvVar] { return env }
        return defaultSTACVersion
    }

    /// Override the STAC version. Pass `nil` to clear.
    public static func setSTACVersion(_ v: String?) {
        OverrideStorage.shared.set(v)
    }
}

/// Process-wide, lock-guarded storage for the version override.
/// We avoid `nonisolated(unsafe)` (which the Swift 6 strict-concurrency
/// checker accepts but does not synchronize) in favor of an explicit
/// `NSLock` to make the locking discipline visible.
private final class OverrideStorage: @unchecked Sendable {
    static let shared = OverrideStorage()
    private let lock = NSLock()
    private var value: String?

    func get() -> String? {
        lock.withLock { value }
    }

    func set(_ new: String?) {
        lock.withLock { value = new }
    }
}
