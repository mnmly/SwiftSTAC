import Foundation

/// Backing object for an extension accessor. An extension either lives on
/// an ``Item`` (its `properties`) or an ``Asset`` (its `extraFields`).
/// `ItemAssetDefinition`-hosted extensions can be added when needed —
/// pystac supports that via a third variant; we omit it here until
/// a concrete use case arrives.
public enum ExtensionHost {
    case item(Item)
    case asset(Asset)
}

/// Base protocol every extension type adopts. Each extension supplies a
/// `schemaURI`; reading from an object never requires registering the schema,
/// writing automatically registers it on the owning Item/Collection.
public protocol STACExtension {
    /// Latest schema URI for this extension.
    static var schemaURI: String { get }

    /// All historical schema URIs (for migration / detection).
    static var schemaURIs: [String] { get }

    /// Field-name prefix (e.g. `"eo:"`, `"proj:"`).
    static var prefix: String { get }
}

extension STACExtension {
    public static var schemaURIs: [String] { [schemaURI] }
}

/// Operations shared across extension accessors.
public protocol PropertiesExtensionAccessor {
    var host: ExtensionHost { get }
}

extension PropertiesExtensionAccessor {

    /// Read a field from the host's property bag.
    public func get(_ key: String) -> JSONValue? {
        switch host {
        case let .item(item): return item.properties[key]
        case let .asset(asset): return asset.extraFields[key]
        }
    }

    /// Write a field to the host's property bag.
    public func set(_ key: String, _ value: JSONValue?) {
        switch host {
        case let .item(item):
            if let value { item.properties[key] = value }
            else { item.properties.removeValue(forKey: key) }
        case let .asset(asset):
            if let value { asset.extraFields[key] = value }
            else { asset.extraFields.removeValue(forKey: key) }
        }
    }

    /// Register the extension's schema URI on the owning STAC object. Items
    /// have their own `stacExtensions`; Asset-hosted extensions delegate to
    /// the asset's owner if available.
    public func registerSchema(_ uri: String) {
        switch host {
        case let .item(item):
            if !item.stacExtensions.contains(uri) { item.stacExtensions.append(uri) }
        case let .asset(asset):
            if let owner = asset.owner as? STACObject, !owner.stacExtensions.contains(uri) {
                owner.stacExtensions.append(uri)
            }
        }
    }
}
