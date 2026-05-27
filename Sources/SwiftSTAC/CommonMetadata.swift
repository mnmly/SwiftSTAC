import Foundation

/// Backing object for ``CommonMetadata``: either an Item (read/write
/// `properties`) or an Asset (read/write `extraFields`).
public enum CommonMetadataHost {
    case item(Item)
    case asset(Asset)
}

/// Convenient typed accessors over an Item's `properties` or an Asset's
/// `extraFields`. Mirrors `pystac.common_metadata.CommonMetadata`.
public struct CommonMetadata {

    public let host: CommonMetadataHost

    public init(_ item: Item) { self.host = .item(item) }
    public init(_ asset: Asset) { self.host = .asset(asset) }

    // MARK: - Backing storage

    private func get(_ key: String) -> JSONValue? {
        switch host {
        case let .item(item): return item.properties[key]
        case let .asset(asset): return asset.extraFields[key]
        }
    }

    private func set(_ key: String, _ value: JSONValue?) {
        switch host {
        case let .item(item):
            if let value { item.properties[key] = value } else { item.properties.removeValue(forKey: key) }
        case let .asset(asset):
            if let value { asset.extraFields[key] = value } else { asset.extraFields.removeValue(forKey: key) }
        }
    }

    // MARK: - String fields

    public var title: String? {
        get { get("title")?.stringValue }
        nonmutating set { set("title", newValue.map(JSONValue.string)) }
    }

    public var commonMetadataDescription: String? {
        get { get("description")?.stringValue }
        nonmutating set { set("description", newValue.map(JSONValue.string)) }
    }

    public var license: String? {
        get { get("license")?.stringValue }
        nonmutating set { set("license", newValue.map(JSONValue.string)) }
    }

    public var platform: String? {
        get { get("platform")?.stringValue }
        nonmutating set { set("platform", newValue.map(JSONValue.string)) }
    }

    public var constellation: String? {
        get { get("constellation")?.stringValue }
        nonmutating set { set("constellation", newValue.map(JSONValue.string)) }
    }

    public var mission: String? {
        get { get("mission")?.stringValue }
        nonmutating set { set("mission", newValue.map(JSONValue.string)) }
    }

    // MARK: - Numeric

    public var gsd: Double? {
        get { get("gsd")?.doubleValue }
        nonmutating set { set("gsd", newValue.map(JSONValue.double)) }
    }

    // MARK: - Array<String>

    public var instruments: [String]? {
        get { arrayOfString("instruments") }
        nonmutating set { set("instruments", newValue.map { .array($0.map(JSONValue.string)) }) }
    }

    public var keywords: [String]? {
        get { arrayOfString("keywords") }
        nonmutating set { set("keywords", newValue.map { .array($0.map(JSONValue.string)) }) }
    }

    public var roles: [String]? {
        get { arrayOfString("roles") }
        nonmutating set { set("roles", newValue.map { .array($0.map(JSONValue.string)) }) }
    }

    // MARK: - Dates

    public var startDatetime: Date? {
        get { get("start_datetime")?.stringValue.flatMap(HREFUtils.stringToDate) }
        nonmutating set { set("start_datetime", newValue.map { .string(HREFUtils.datetimeToString($0)) }) }
    }

    public var endDatetime: Date? {
        get { get("end_datetime")?.stringValue.flatMap(HREFUtils.stringToDate) }
        nonmutating set { set("end_datetime", newValue.map { .string(HREFUtils.datetimeToString($0)) }) }
    }

    public var created: Date? {
        get { get("created")?.stringValue.flatMap(HREFUtils.stringToDate) }
        nonmutating set { set("created", newValue.map { .string(HREFUtils.datetimeToString($0)) }) }
    }

    public var updated: Date? {
        get { get("updated")?.stringValue.flatMap(HREFUtils.stringToDate) }
        nonmutating set { set("updated", newValue.map { .string(HREFUtils.datetimeToString($0)) }) }
    }

    // MARK: - Providers

    public var providers: [Provider]? {
        get {
            guard case let .array(arr)? = get("providers") else { return nil }
            let enc = JSONEncoder()
            let dec = JSONDecoder()
            return arr.compactMap { v in
                guard let data = try? enc.encode(v) else { return nil }
                return try? dec.decode(Provider.self, from: data)
            }
        }
        nonmutating set {
            guard let providers = newValue else { set("providers", nil); return }
            let enc = JSONEncoder()
            let dec = JSONDecoder()
            let encoded: [JSONValue] = providers.compactMap { p in
                guard let data = try? enc.encode(p) else { return nil }
                return try? dec.decode(JSONValue.self, from: data)
            }
            set("providers", .array(encoded))
        }
    }

    // MARK: - Helpers

    private func arrayOfString(_ key: String) -> [String]? {
        guard case let .array(arr)? = get(key) else { return nil }
        return arr.compactMap { $0.stringValue }
    }
}

public extension Item {
    /// CommonMetadata accessor for the item's properties.
    var commonMetadata: CommonMetadata { CommonMetadata(self) }
}

public extension Asset {
    /// CommonMetadata accessor for the asset's extra fields.
    var commonMetadata: CommonMetadata { CommonMetadata(self) }
}
