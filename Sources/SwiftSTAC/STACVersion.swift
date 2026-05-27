import Foundation

/// The STAC spec version SwiftSTAC writes as `stac_version` and the API
/// version it claims when relevant. Mirrors `pystac.version.STACVersion`.
public enum STACVersion {
    public static let defaultSTACVersion = "1.1.0"
    public static let defaultSTACAPIVersion = "1.0.0"

    /// Override environment variable name, matching pystac.
    public static let overrideVersionEnvVar = "PYSTAC_STAC_VERSION_OVERRIDE"

    /// User-set override (highest priority). Set via ``setSTACVersion``.
    nonisolated(unsafe) private static var overrideVersion: String?

    /// Returns the STAC version that SwiftSTAC emits.
    public static func getSTACVersion() -> String {
        if let v = overrideVersion { return v }
        if let env = ProcessInfo.processInfo.environment[overrideVersionEnvVar] { return env }
        return defaultSTACVersion
    }

    /// Override the STAC version. Pass `nil` to clear.
    public static func setSTACVersion(_ v: String?) {
        overrideVersion = v
    }
}
