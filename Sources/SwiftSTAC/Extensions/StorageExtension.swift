import Foundation

/// Storage STAC extension. Mirrors `pystac.extensions.storage`.
/// Describes alternate storage locations (e.g. S3, Azure Blob, GCS).

public struct StorageScheme: Sendable, Equatable, Hashable {
    public var properties: [String: JSONValue]
    public init(properties: [String: JSONValue] = [:]) { self.properties = properties }

    public init(
        type: String,
        platform: String? = nil,
        region: String? = nil,
        requesterPays: Bool? = nil
    ) {
        var p: [String: JSONValue] = ["type": .string(type)]
        if let platform { p["platform"] = .string(platform) }
        if let region { p["region"] = .string(region) }
        if let requesterPays { p["requester_pays"] = .bool(requesterPays) }
        self.properties = p
    }

    public var type: String? {
        get { properties["type"]?.stringValue }
        set { setOrRemove("type", newValue.map(JSONValue.string)) }
    }
    public var platform: String? {
        get { properties["platform"]?.stringValue }
        set { setOrRemove("platform", newValue.map(JSONValue.string)) }
    }
    public var region: String? {
        get { properties["region"]?.stringValue }
        set { setOrRemove("region", newValue.map(JSONValue.string)) }
    }
    public var requesterPays: Bool? {
        get { properties["requester_pays"]?.boolValue }
        set { setOrRemove("requester_pays", newValue.map(JSONValue.bool)) }
    }

    private mutating func setOrRemove(_ key: String, _ value: JSONValue?) {
        if let value { properties[key] = value } else { properties.removeValue(forKey: key) }
    }
}

public struct StorageExtension: STACExtension, PropertiesExtensionAccessor {
    public static let schemaURIPattern = "https://stac-extensions.github.io/storage/v{version}/schema.json"
    public static let schemaURI = "https://stac-extensions.github.io/storage/v2.0.0/schema.json"
    public static let prefix = "storage:"

    public let host: ExtensionHost
    public init(_ item: Item) { self.host = .item(item) }
    public init(_ asset: Asset) { self.host = .asset(asset) }

    public static let refsProp = prefix + "refs"
    public static let schemesProp = prefix + "schemes"

    /// Map of scheme key to ``StorageScheme``.
    public var schemes: [String: StorageScheme]? {
        get {
            guard case let .object(o)? = get(Self.schemesProp) else { return nil }
            var out: [String: StorageScheme] = [:]
            for (k, v) in o {
                if case let .object(inner) = v { out[k] = StorageScheme(properties: inner) }
            }
            return out
        }
        nonmutating set {
            if let value = newValue {
                var o: [String: JSONValue] = [:]
                for (k, v) in value { o[k] = .object(v.properties) }
                set(Self.schemesProp, .object(o))
            } else {
                set(Self.schemesProp, nil)
            }
            registerSchema(Self.schemaURI)
        }
    }

    /// Scheme references for this Asset/Item (list of scheme keys).
    public var refs: [String]? {
        get {
            guard case let .array(arr)? = get(Self.refsProp) else { return nil }
            return arr.compactMap { $0.stringValue }
        }
        nonmutating set {
            set(Self.refsProp, newValue.map { .array($0.map(JSONValue.string)) })
            registerSchema(Self.schemaURI)
        }
    }
}
public extension Item { var storage: StorageExtension { StorageExtension(self) } }
public extension Asset { var storage: StorageExtension { StorageExtension(self) } }
