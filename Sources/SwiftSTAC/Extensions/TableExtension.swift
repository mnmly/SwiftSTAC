import Foundation

/// Table STAC extension. Mirrors `pystac.extensions.table`.

public struct TableColumn: Sendable, Equatable, Hashable {
    public var properties: [String: JSONValue]
    public init(properties: [String: JSONValue] = [:]) { self.properties = properties }

    public init(name: String, type: String? = nil, description: String? = nil) {
        var p: [String: JSONValue] = ["name": .string(name)]
        if let type { p["type"] = .string(type) }
        if let description { p["description"] = .string(description) }
        self.properties = p
    }

    public var name: String? {
        get { properties["name"]?.stringValue }
        set { setOrRemove("name", newValue.map(JSONValue.string)) }
    }
    public var type: String? {
        get { properties["type"]?.stringValue }
        set { setOrRemove("type", newValue.map(JSONValue.string)) }
    }
    public var columnDescription: String? {
        get { properties["description"]?.stringValue }
        set { setOrRemove("description", newValue.map(JSONValue.string)) }
    }

    private mutating func setOrRemove(_ key: String, _ value: JSONValue?) {
        if let value { properties[key] = value } else { properties.removeValue(forKey: key) }
    }
}

public struct TableExtension: STACExtension, PropertiesExtensionAccessor {
    public static let schemaURI = "https://stac-extensions.github.io/table/v1.2.0/schema.json"
    public static let prefix = "table:"

    public let host: ExtensionHost
    public init(_ item: Item) { self.host = .item(item) }
    public init(_ asset: Asset) { self.host = .asset(asset) }

    public static let columnsProp = prefix + "columns"
    public static let primaryGeometryProp = prefix + "primary_geometry"
    public static let rowCountProp = prefix + "row_count"
    public static let tablesProp = prefix + "tables"
    public static let storageOptionsProp = prefix + "storage_options"

    public var columns: [TableColumn]? {
        get {
            guard case let .array(arr)? = get(Self.columnsProp) else { return nil }
            return arr.compactMap { v in
                if case let .object(o) = v { return TableColumn(properties: o) }
                return nil
            }
        }
        nonmutating set {
            set(Self.columnsProp, newValue.map { .array($0.map { .object($0.properties) }) })
            registerSchema(Self.schemaURI)
        }
    }

    public var primaryGeometry: String? {
        get { get(Self.primaryGeometryProp)?.stringValue }
        nonmutating set { set(Self.primaryGeometryProp, newValue.map(JSONValue.string)); registerSchema(Self.schemaURI) }
    }

    public var rowCount: Int64? {
        get { get(Self.rowCountProp)?.intValue }
        nonmutating set { set(Self.rowCountProp, newValue.map(JSONValue.int)); registerSchema(Self.schemaURI) }
    }

    public var storageOptions: [String: JSONValue]? {
        get {
            if case let .object(o)? = get(Self.storageOptionsProp) { return o }
            return nil
        }
        nonmutating set { set(Self.storageOptionsProp, newValue.map(JSONValue.object)); registerSchema(Self.schemaURI) }
    }
}
public extension Item { var table: TableExtension { TableExtension(self) } }
public extension Asset { var table: TableExtension { TableExtension(self) } }
