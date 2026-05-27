import Foundation

/// A STAC Collection — Catalog plus the discovery metadata (extent, license,
/// providers, summaries, assets, item_assets).
///
/// Mirrors `pystac.collection.Collection`.
public final class Collection: Catalog, AssetOwner, @unchecked Sendable {

    public var extent: Extent
    public var license: String
    public var keywords: [String]?
    public var providers: [Provider]?
    public var summaries: Summaries
    public var assets: [String: Asset]
    public var itemAssets: [String: ItemAssetDefinition]

    public override class var stacObjectType: STACObjectType { .collection }
    public static let defaultFileName_ = "collection.json"

    public init(
        id: String,
        description: String,
        extent: Extent,
        title: String? = nil,
        stacExtensions: [String] = [],
        extraFields: [String: JSONValue] = [:],
        href: String? = nil,
        catalogType: CatalogType = .absolutePublished,
        license: String = "other",
        keywords: [String]? = nil,
        providers: [Provider]? = nil,
        summaries: Summaries = .empty,
        assets: [String: Asset] = [:],
        itemAssets: [String: ItemAssetDefinition] = [:]
    ) {
        self.extent = extent
        self.license = license
        self.keywords = keywords
        self.providers = providers
        self.summaries = summaries
        self.assets = [:]
        self.itemAssets = itemAssets
        super.init(
            id: id,
            description: description,
            title: title,
            stacExtensions: stacExtensions,
            extraFields: extraFields,
            href: href,
            catalogType: catalogType
        )
        for (k, asset) in assets { self.addAsset(key: k, asset: asset) }
    }

    /// Required by Catalog's subclass-friendly designated init.
    public required convenience init(
        id: String,
        description: String,
        title: String? = nil,
        stacExtensions: [String] = [],
        extraFields: [String: JSONValue] = [:],
        href: String? = nil,
        catalogType: CatalogType = .absolutePublished
    ) {
        // Default extent — overwritten by `parse(_:)` after construction.
        let extent = Extent(
            spatial: SpatialExtent(bboxes: [[-180, -90, 180, 90]]),
            temporal: TemporalExtent(intervals: [[nil, nil]])
        )
        self.init(
            id: id,
            description: description,
            extent: extent,
            title: title,
            stacExtensions: stacExtensions,
            extraFields: extraFields,
            href: href,
            catalogType: catalogType
        )
    }

    // MARK: - clone()

    public override func clone() -> Catalog {
        let copy = Collection(
            id: id,
            description: description,
            extent: extent,
            title: title,
            stacExtensions: stacExtensions,
            extraFields: extraFields,
            href: nil,
            catalogType: catalogType,
            license: license,
            keywords: keywords,
            providers: providers,
            summaries: summaries,
            assets: assets.mapValues { $0.clone() },
            itemAssets: itemAssets
        )
        if let selfHref = getSelfHref() { copy.setSelfHref(selfHref) }
        for link in links where link.rel != RelType.root.rawValue {
            copy.addLink(link.clone())
        }
        return copy
    }

    // MARK: - Adding items: also set their collection

    @discardableResult
    public override func addItem(_ item: STACObject, title: String? = nil, setParent: Bool = true) throws -> Link {
        let link = try super.addItem(item, title: title, setParent: setParent)
        if let item = item as? Item {
            item.setCollection(self)
        }
        return link
    }

    // MARK: - Dict

    public override func toDict(includeSelfLink: Bool = true) throws -> [String: JSONValue] {
        var d = try super.toDict(includeSelfLink: includeSelfLink)
        d["extent"] = .object(extent.toDict())
        d["license"] = .string(license)
        if let keywords, !keywords.isEmpty { d["keywords"] = .array(keywords.map(JSONValue.string)) }
        if let providers, !providers.isEmpty {
            let enc = JSONEncoder()
            let dec = JSONDecoder()
            let provJSON: [JSONValue] = try providers.map { p in
                let data = try enc.encode(p)
                return try dec.decode(JSONValue.self, from: data)
            }
            d["providers"] = .array(provJSON)
        }
        if !summaries.isEmpty { d["summaries"] = .object(summaries.toDict()) }
        if !assets.isEmpty {
            let enc = JSONEncoder()
            let dec = JSONDecoder()
            var out: [String: JSONValue] = [:]
            for (k, a) in assets {
                let data = try enc.encode(a)
                out[k] = try dec.decode(JSONValue.self, from: data)
            }
            d["assets"] = .object(out)
        }
        if !itemAssets.isEmpty {
            var out: [String: JSONValue] = [:]
            for (k, ia) in itemAssets { out[k] = .object(ia.toDict()) }
            d["item_assets"] = .object(out)
        }
        return d
    }

    public override class func fromDict(_ d: [String: JSONValue]) throws -> Catalog {
        // override returns Catalog, but the actual object will be a Collection.
        // For the natural Collection.fromDict(...) API, see `Collection.parse(_:)` below.
        try parse(d)
    }

    /// Concrete Collection-typed entry point.
    public static func parse(_ d: [String: JSONValue]) throws -> Collection {
        guard case let .string(t)? = d["type"], t == STACObjectType.collection.rawValue else {
            throw STACError.typeMismatch(id: d["id"]?.stringValue, expected: "Collection", extra: "'type' missing or wrong")
        }
        // Build through Catalog's subclass-friendly init prelude
        let cat = try Collection.fromDictInternal(d) as! Collection

        // Populate Collection-specific fields
        guard case let .object(extDict)? = d["extent"] else {
            throw STACError.requiredPropertyMissing(object: "Collection(\(cat.id))", property: "extent")
        }
        cat.extent = try Extent.fromDict(extDict)
        cat.license = d["license"]?.stringValue ?? "other"
        if case let .array(arr)? = d["keywords"] {
            cat.keywords = arr.compactMap { $0.stringValue }
        }
        if case let .array(arr)? = d["providers"] {
            let enc = JSONEncoder()
            let dec = JSONDecoder()
            var out: [Provider] = []
            for v in arr {
                let data = try enc.encode(v)
                out.append(try dec.decode(Provider.self, from: data))
            }
            cat.providers = out
        }
        if case let .object(summ)? = d["summaries"] {
            cat.summaries = Summaries.fromDict(summ)
        }
        if case let .object(assets)? = d["assets"] {
            let enc = JSONEncoder()
            let dec = JSONDecoder()
            for (k, v) in assets {
                let data = try enc.encode(v)
                let a = try dec.decode(Asset.self, from: data)
                cat.addAsset(key: k, asset: a)
            }
        }
        if case let .object(itemAssets)? = d["item_assets"] {
            for (k, v) in itemAssets {
                if case let .object(o) = v {
                    cat.itemAssets[k] = ItemAssetDefinition.fromDict(o)
                }
            }
        }

        // Remove Collection-only keys from extraFields (Catalog put everything
        // unknown into extraFields, but these are known to Collection).
        let collectionKeys: Set<String> = [
            "extent", "license", "keywords", "providers", "summaries", "assets", "item_assets",
        ]
        for k in collectionKeys { cat.extraFields.removeValue(forKey: k) }
        return cat
    }
}
