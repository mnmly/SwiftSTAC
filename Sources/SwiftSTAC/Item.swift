import Foundation

/// A STAC Item — the granular GeoJSON Feature carrying metadata for one asset
/// bundle. Mirrors `pystac.item.Item`.
public final class Item: STACObject, AssetOwner, @unchecked Sendable {

    // MARK: - Fields

    /// GeoJSON geometry, or `nil` for "null geometry" items.
    public var geometry: JSONValue?

    /// Bounding box: 2*n entries where n is the number of dimensions.
    public var bbox: [Double]?

    /// Datetime, or `nil` when start/end datetime in properties supply a range.
    public var datetime: Date?

    /// Properties dictionary. Holds `datetime`, `start_datetime`,
    /// `end_datetime`, plus all extension fields.
    public var properties: [String: JSONValue]

    /// Collection back-reference (resolved object), if any.
    public weak var collection: Collection?

    /// Collection ID this item belongs to, if any.
    public var collectionID: String?

    /// Asset dictionary keyed by asset key.
    public var assets: [String: Asset]

    /// Additional top-level Item fields preserved verbatim.
    public var extraFields: [String: JSONValue]

    public override class var stacObjectType: STACObjectType { .item }

    // MARK: - Init

    /// Designated initializer. `datetime` may be `nil` only when both
    /// `start_datetime` and `end_datetime` are present in `properties` (or
    /// supplied here). Throws ``STACError/generic(_:)`` otherwise.
    public init(
        id: String,
        geometry: JSONValue?,
        bbox: [Double]?,
        datetime: Date?,
        properties: [String: JSONValue],
        startDatetime: Date? = nil,
        endDatetime: Date? = nil,
        stacExtensions: [String] = [],
        href: String? = nil,
        collection: Collection? = nil,
        collectionID: String? = nil,
        assets: [String: Asset] = [:],
        extraFields: [String: JSONValue] = [:]
    ) throws {
        self.geometry = geometry
        self.bbox = bbox
        self.assets = [:]
        self.extraFields = extraFields

        var props = properties
        if let startDatetime { props["start_datetime"] = .string(HREFUtils.datetimeToString(startDatetime)) }
        if let endDatetime { props["end_datetime"] = .string(HREFUtils.datetimeToString(endDatetime)) }
        if datetime == nil {
            if props["start_datetime"] == nil || props["end_datetime"] == nil {
                throw STACError.generic(
                    "Invalid Item: If datetime is None, a start_datetime and end_datetime must be supplied."
                )
            }
            self.datetime = nil
        } else {
            self.datetime = datetime
        }
        self.properties = props

        if let collection {
            self.collection = collection
            self.collectionID = collection.id
        } else {
            self.collectionID = collectionID
        }

        super.init(id: id, stacExtensions: stacExtensions, links: [])

        if let href { self.setSelfHref(href) }
        if let collection { self.addLink(Link.collection(collection)) }
        for (key, asset) in assets { self.addAsset(key: key, asset: asset) }
    }

    // MARK: - Self href

    /// Setting the self HREF keeps relative asset HREFs valid by re-anchoring
    /// them against the new self href when needed.
    public override func getSelfHref() -> String? {
        super.getSelfHref()
    }

    public func setSelfHrefKeepingAssetHrefs(_ href: String?) {
        let prev = getSelfHref()
        setSelfHref(href)
        let new = getSelfHref()
        guard let prev, let new else { return }
        for asset in assets.values {
            if !HREFUtils.isAbsolute(asset.href) {
                let abs = HREFUtils.makeAbsolute(asset.href, startHref: prev)
                asset.href = HREFUtils.makeRelative(abs, startHref: new)
            }
        }
    }

    // MARK: - Collection

    /// Replace the collection link & id. Pass nil to clear.
    @discardableResult
    public func setCollection(_ collection: Collection?) -> Item {
        removeLinks(rel: .collection)
        self.collectionID = nil
        self.collection = nil
        if let collection {
            addLink(Link.collection(collection))
            self.collection = collection
            self.collectionID = collection.id
        }
        return self
    }

    // MARK: - Datetime accessors per asset (parity with pystac)

    /// Get this Item's datetime, or an asset-level override if `asset` is
    /// supplied and has `datetime` in its extra fields.
    public func getDatetime(asset: Asset? = nil) -> Date? {
        if let asset, case let .string(s)? = asset.extraFields["datetime"] {
            return HREFUtils.stringToDate(s)
        }
        return datetime
    }

    /// Set this Item's datetime, or set the override on `asset`.
    public func setDatetime(_ d: Date, asset: Asset? = nil) {
        if let asset {
            asset.extraFields["datetime"] = .string(HREFUtils.datetimeToString(d))
        } else {
            self.datetime = d
        }
    }
}

// MARK: - JSON / Dict

extension Item {

    /// Decode an Item from a JSON dictionary. Mirrors `Item.from_dict`.
    public static func fromDict(_ d: [String: JSONValue]) throws -> Item {
        // Type guard
        if case let .string(t)? = d["type"], t != "Feature" {
            throw STACError.typeMismatch(id: d["id"]?.stringValue, expected: "Item", extra: "'type' is \(t), expected 'Feature'.")
        }
        guard case let .string(id) = d["id"] ?? .null else {
            throw STACError.typeMismatch(id: nil, expected: "Item", extra: "'id' is missing.")
        }

        let geometry = d["geometry"]
        var bbox: [Double]? = nil
        if case let .array(arr)? = d["bbox"] {
            bbox = arr.compactMap { $0.doubleValue }
            if bbox?.isEmpty == true { bbox = nil }
        }
        var properties: [String: JSONValue] = [:]
        if case let .object(o)? = d["properties"] { properties = o }

        var datetime: Date? = nil
        if case let .string(s)? = properties["datetime"] {
            datetime = HREFUtils.stringToDate(s)
        }

        var stacExtensions: [String] = []
        if case let .array(arr)? = d["stac_extensions"] {
            stacExtensions = arr.compactMap { $0.stringValue }
        }

        var assets: [String: Asset] = [:]
        if case let .object(o)? = d["assets"] {
            let enc = JSONEncoder()
            let dec = JSONDecoder()
            for (k, v) in o {
                let data = try enc.encode(v)
                let asset = try dec.decode(Asset.self, from: data)
                assets[k] = asset
            }
        }

        let collectionID: String? = (d["collection"]?.stringValue)

        let excluded: Set<String> = [
            "type", "stac_version", "stac_extensions", "id",
            "geometry", "bbox", "properties", "links", "assets", "collection",
        ]
        var extraFields: [String: JSONValue] = [:]
        for (k, v) in d where !excluded.contains(k) { extraFields[k] = v }

        let item = try Item(
            id: id,
            geometry: geometry,
            bbox: bbox,
            datetime: datetime,
            properties: properties,
            stacExtensions: stacExtensions,
            collectionID: collectionID,
            assets: assets,
            extraFields: extraFields
        )

        if case let .array(arr)? = d["links"] {
            let enc = JSONEncoder()
            let dec = JSONDecoder()
            for linkVal in arr {
                let data = try enc.encode(linkVal)
                let link = try dec.decode(Link.self, from: data)
                item.addLink(link)
            }
        }
        return item
    }

    /// Encode this Item to a JSON dictionary. Mirrors `Item.to_dict`.
    public func toDict(includeSelfLink: Bool = true) throws -> [String: JSONValue] {
        var properties = self.properties
        if let datetime {
            properties["datetime"] = .string(HREFUtils.datetimeToString(datetime))
        } else {
            properties["datetime"] = .null
        }

        let outLinks = includeSelfLink ? links : links.filter { $0.rel != RelType.`self`.rawValue }

        let enc = JSONEncoder()
        enc.outputFormatting = [.withoutEscapingSlashes]
        let dec = JSONDecoder()

        // Re-serialize links and assets through their Codable conformance, then
        // re-parse into JSONValue so the output respects each type's encode().
        var linksJSON: [JSONValue] = []
        for link in outLinks {
            let data = try enc.encode(link)
            linksJSON.append(try dec.decode(JSONValue.self, from: data))
        }

        var assetsJSON: [String: JSONValue] = [:]
        for (k, asset) in assets {
            let data = try enc.encode(asset)
            assetsJSON[k] = try dec.decode(JSONValue.self, from: data)
        }

        var d: [String: JSONValue] = [
            "type": .string("Feature"),
            "stac_version": .string(STACVersion.getSTACVersion()),
            "stac_extensions": .array(stacExtensions.map(JSONValue.string)),
            "id": .string(id),
            "geometry": geometry ?? .null,
            "properties": .object(properties),
            "links": .array(linksJSON),
            "assets": .object(assetsJSON),
        ]
        // bbox: present only when geometry is non-null
        if geometry != nil && !(geometry?.isNull ?? true) {
            d["bbox"] = .array((bbox ?? []).map { .double($0) })
        }
        if let cid = collectionID { d["collection"] = .string(cid) }
        for (k, v) in extraFields { d[k] = v }
        return d
    }
}

// MARK: - Codable

extension Item: Codable {

    public convenience init(from decoder: Decoder) throws {
        let value = try JSONValue(from: decoder)
        guard case let .object(dict) = value else {
            throw DecodingError.typeMismatch(
                [String: JSONValue].self,
                .init(codingPath: decoder.codingPath, debugDescription: "Item must be a JSON object")
            )
        }
        let item = try Item.fromDict(dict)
        self.init(copying: item)
    }

    public func encode(to encoder: Encoder) throws {
        let dict = try toDict()
        try JSONValue.object(dict).encode(to: encoder)
    }

    /// Copy constructor used to satisfy the Codable convenience init.
    private convenience init(copying other: Item) {
        try! self.init(
            id: other.id,
            geometry: other.geometry,
            bbox: other.bbox,
            datetime: other.datetime,
            properties: other.properties,
            stacExtensions: other.stacExtensions,
            extraFields: other.extraFields
        )
        self.collectionID = other.collectionID
        self.collection = other.collection
        self.assets = [:]
        for (k, a) in other.assets { self.addAsset(key: k, asset: a) }
        for link in other.links { self.addLink(link.clone()) }
    }
}

