import Foundation

/// Definition of an asset that may appear on Items belonging to a Collection.
/// Mirrors `pystac.item_assets.ItemAssetDefinition`.
///
/// Internally just a property bag; the `title`, `description`, `type`, `roles`
/// accessors are computed views over the underlying dict (matching pystac).
public struct ItemAssetDefinition: Sendable, Equatable, Hashable {

    public var properties: [String: JSONValue]

    public static func == (lhs: ItemAssetDefinition, rhs: ItemAssetDefinition) -> Bool {
        lhs.properties == rhs.properties
    }
    public func hash(into hasher: inout Hasher) { hasher.combine(properties) }

    public init(properties: [String: JSONValue] = [:]) {
        self.properties = properties
    }

    public init(
        title: String? = nil,
        description: String? = nil,
        mediaType: String? = nil,
        roles: [String]? = nil,
        extraFields: [String: JSONValue] = [:]
    ) {
        var props = extraFields
        if let title { props["title"] = .string(title) }
        if let description { props["description"] = .string(description) }
        if let mediaType { props["type"] = .string(mediaType) }
        if let roles { props["roles"] = .array(roles.map(JSONValue.string)) }
        self.properties = props
    }

    public var title: String? {
        get { properties["title"]?.stringValue }
        set { setOrRemove("title", newValue.map(JSONValue.string)) }
    }

    public var assetDescription: String? {
        get { properties["description"]?.stringValue }
        set { setOrRemove("description", newValue.map(JSONValue.string)) }
    }

    public var mediaType: String? {
        get { properties["type"]?.stringValue }
        set { setOrRemove("type", newValue.map(JSONValue.string)) }
    }

    public var roles: [String]? {
        get {
            if case let .array(a)? = properties["roles"] {
                return a.compactMap { $0.stringValue }
            }
            return nil
        }
        set {
            setOrRemove("roles", newValue.map { .array($0.map(JSONValue.string)) })
        }
    }

    /// Hydrate a real ``Asset`` rooted at `href`, copying this definition's
    /// properties. Mirrors `ItemAssetDefinition.create_asset`.
    public func createAsset(href: String) -> Asset {
        let extras = properties.filter { !["title", "description", "type", "roles"].contains($0.key) }
        return Asset(
            href: href,
            title: title,
            description: assetDescription,
            mediaType: mediaType,
            roles: roles,
            extraFields: extras
        )
    }

    public func toDict() -> [String: JSONValue] { properties }

    public static func fromDict(_ d: [String: JSONValue]) -> ItemAssetDefinition {
        ItemAssetDefinition(properties: d)
    }

    private mutating func setOrRemove(_ key: String, _ value: JSONValue?) {
        if let value { properties[key] = value }
        else { properties.removeValue(forKey: key) }
    }
}
