import Foundation

/// Strategy for laying out a STAC catalog tree on disk. Mirrors
/// `pystac.layout.HrefLayoutStrategy`.
public protocol HrefLayoutStrategy {
    func getCatalogHref(_ catalog: Catalog, parentDir: String, isRoot: Bool) -> String
    func getCollectionHref(_ collection: Collection, parentDir: String, isRoot: Bool) -> String
    func getItemHref(_ item: Item, parentDir: String) -> String
}

extension HrefLayoutStrategy {
    /// Dispatch helper that picks the right callback for a STACObject.
    public func getHref(_ object: STACObject, parentDir: String, isRoot: Bool = false) -> String {
        switch object {
        case let item as Item: return getItemHref(item, parentDir: parentDir)
        case let coll as Collection: return getCollectionHref(coll, parentDir: parentDir, isRoot: isRoot)
        case let cat as Catalog: return getCatalogHref(cat, parentDir: parentDir, isRoot: isRoot)
        default: return parentDir
        }
    }
}

/// Best-practices layout from the STAC spec. Mirrors
/// `pystac.layout.BestPracticesLayoutStrategy`.
///
/// - Root catalog / collection: `parent_dir/catalog.json` (or `collection.json`)
/// - Non-root catalog / collection: `parent_dir/{id}/catalog.json`
/// - Item: `parent_dir/{id}/{id}.json`
public struct BestPracticesLayoutStrategy: HrefLayoutStrategy, Sendable {

    public init() {}

    public func getCatalogHref(_ catalog: Catalog, parentDir: String, isRoot: Bool) -> String {
        let dir = isRoot ? parentDir : joined(parentDir, catalog.id)
        return joined(dir, Catalog.defaultFileName)
    }

    public func getCollectionHref(_ collection: Collection, parentDir: String, isRoot: Bool) -> String {
        let dir = isRoot ? parentDir : joined(parentDir, collection.id)
        return joined(dir, "collection.json")
    }

    public func getItemHref(_ item: Item, parentDir: String) -> String {
        let dir = joined(parentDir, item.id)
        return joined(dir, "\(item.id).json")
    }

    private func joined(_ a: String, _ b: String) -> String {
        if a.hasSuffix("/") { return a + b }
        return a + "/" + b
    }
}

/// Layout that preserves the existing self HREF on each object. Mirrors
/// `pystac.layout.AsIsLayoutStrategy`.
public struct AsIsLayoutStrategy: HrefLayoutStrategy, Sendable {
    public init() {}

    public func getCatalogHref(_ catalog: Catalog, parentDir: String, isRoot: Bool) -> String {
        catalog.getSelfHref() ?? BestPracticesLayoutStrategy().getCatalogHref(catalog, parentDir: parentDir, isRoot: isRoot)
    }
    public func getCollectionHref(_ collection: Collection, parentDir: String, isRoot: Bool) -> String {
        collection.getSelfHref() ?? BestPracticesLayoutStrategy().getCollectionHref(collection, parentDir: parentDir, isRoot: isRoot)
    }
    public func getItemHref(_ item: Item, parentDir: String) -> String {
        item.getSelfHref() ?? BestPracticesLayoutStrategy().getItemHref(item, parentDir: parentDir)
    }
}
