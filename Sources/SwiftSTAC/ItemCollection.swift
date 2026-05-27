import Foundation

/// A GeoJSON `FeatureCollection` whose features are STAC Items.
///
/// Mirrors `pystac.item_collection.ItemCollection`. Not a STAC object — does
/// not subclass ``STACObject``.
public final class ItemCollection: @unchecked Sendable {

    public var items: [Item]
    public var extraFields: [String: JSONValue]

    public init(items: [Item], extraFields: [String: JSONValue] = [:]) {
        self.items = items
        self.extraFields = extraFields
    }

    public var count: Int { items.count }

    public subscript(index: Int) -> Item { items[index] }

    /// Concatenate two collections (matches pystac `__add__`).
    public static func + (lhs: ItemCollection, rhs: ItemCollection) -> ItemCollection {
        ItemCollection(items: lhs.items + rhs.items)
    }

    public func toDict() throws -> [String: JSONValue] {
        var features: [JSONValue] = []
        for item in items {
            features.append(.object(try item.toDict()))
        }
        var d: [String: JSONValue] = [
            "type": .string("FeatureCollection"),
            "features": .array(features),
        ]
        for (k, v) in extraFields where k != "type" && k != "features" {
            d[k] = v
        }
        return d
    }

    public static func fromDict(_ d: [String: JSONValue]) throws -> ItemCollection {
        guard isItemCollection(d) else {
            throw STACError.typeMismatch(id: nil, expected: "ItemCollection", extra: "type is not FeatureCollection")
        }
        var items: [Item] = []
        if case let .array(features)? = d["features"] {
            for f in features {
                if case let .object(o) = f {
                    items.append(try Item.fromDict(o))
                }
            }
        }
        var extras: [String: JSONValue] = [:]
        for (k, v) in d where k != "type" && k != "features" { extras[k] = v }
        return ItemCollection(items: items, extraFields: extras)
    }

    /// `true` if the dict shape is a STAC ItemCollection.
    public static func isItemCollection(_ d: [String: JSONValue]) -> Bool {
        guard case let .string(t)? = d["type"], t == "FeatureCollection" else { return false }
        if d["stac_version"] != nil { return true }
        // Fall back to checking each feature has STAC item shape.
        if case let .array(features)? = d["features"] {
            return features.allSatisfy { v in
                if case let .object(o) = v, case let .string(t)? = o["type"], t == "Feature" {
                    return true
                }
                return false
            }
        }
        return false
    }
}

extension ItemCollection: Sequence {
    public func makeIterator() -> IndexingIterator<[Item]> { items.makeIterator() }
}
