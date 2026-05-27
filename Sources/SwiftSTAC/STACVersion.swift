import Foundation

/// The STAC spec version SwiftSTAC writes as `stac_version` and the API
/// version it claims when relevant. Mirrors `pystac.version.STACVersion`.
///
/// The override slot is concurrency-safe via an internal lock so that
/// `setSTACVersion` / `getSTACVersion` can be called from any isolation
/// domain (or no isolation at all).
public enum STACVersion {
    /// STAC spec version SwiftSTAC writes as `stac_version`.
    public static let defaultSTACVersion = "1.1.0"

    /// STAC API spec version SwiftSTAC claims.
    public static let defaultSTACAPIVersion = "1.0.0"

    /// Version of [PySTAC](https://github.com/stac-utils/pystac) this port
    /// tracks. Bump in lockstep with the upstream tag/commit pinned in
    /// `portedFromPystacCommit`. Read with `STACVersion.portedFromPystac`
    /// to discover compatibility at runtime.
    public static let portedFromPystac = "1.15.0-rc.0"

    /// Upstream PySTAC git commit this port was taken from.
    public static let portedFromPystacCommit = "6184a7ca"

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
        lock.lock(); defer { lock.unlock() }
        return value
    }

    func set(_ new: String?) {
        lock.lock(); defer { lock.unlock() }
        value = new
    }
}
