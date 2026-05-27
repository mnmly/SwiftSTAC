import Foundation

/// Datacube STAC extension. Mirrors `pystac.extensions.datacube`.
///
/// Dimensions and variables are exposed as property-bag types: the schema
/// allows a dozen+ optional fields per dimension and the variant is what
/// matters for typical consumers. Use `properties` to access fields not
/// surfaced by the typed accessors.

public enum DatacubeDimensionType: String, Sendable, Codable {
    case spatial, temporal, geometry, additional, other
}

public struct DatacubeDimension: Sendable, Equatable, Hashable {
    public var properties: [String: JSONValue]
    public init(properties: [String: JSONValue] = [:]) { self.properties = properties }

    public var dimensionType: DatacubeDimensionType? {
        get { properties["type"]?.stringValue.flatMap(DatacubeDimensionType.init(rawValue:)) }
        set { setOrRemove("type", newValue.map { .string($0.rawValue) }) }
    }
    public var dimensionDescription: String? {
        get { properties["description"]?.stringValue }
        set { setOrRemove("description", newValue.map(JSONValue.string)) }
    }
    public var axis: String? {
        get { properties["axis"]?.stringValue }
        set { setOrRemove("axis", newValue.map(JSONValue.string)) }
    }
    public var extent: [JSONValue]? {
        get { if case let .array(arr)? = properties["extent"] { return arr }; return nil }
        set { setOrRemove("extent", newValue.map(JSONValue.array)) }
    }
    public var values: [JSONValue]? {
        get { if case let .array(arr)? = properties["values"] { return arr }; return nil }
        set { setOrRemove("values", newValue.map(JSONValue.array)) }
    }
    public var step: Double? {
        get { properties["step"]?.doubleValue }
        set { setOrRemove("step", newValue.map(JSONValue.double)) }
    }
    public var referenceSystem: JSONValue? {
        get { properties["reference_system"] }
        set { setOrRemove("reference_system", newValue) }
    }
    public var unit: String? {
        get { properties["unit"]?.stringValue }
        set { setOrRemove("unit", newValue.map(JSONValue.string)) }
    }

    private mutating func setOrRemove(_ key: String, _ value: JSONValue?) {
        if let value { properties[key] = value } else { properties.removeValue(forKey: key) }
    }
}

public struct DatacubeVariable: Sendable, Equatable, Hashable {
    public var properties: [String: JSONValue]
    public init(properties: [String: JSONValue] = [:]) { self.properties = properties }

    public var variableType: String? {
        get { properties["type"]?.stringValue }
        set { setOrRemove("type", newValue.map(JSONValue.string)) }
    }
    public var variableDescription: String? {
        get { properties["description"]?.stringValue }
        set { setOrRemove("description", newValue.map(JSONValue.string)) }
    }
    public var dimensions: [String]? {
        get {
            guard case let .array(arr)? = properties["dimensions"] else { return nil }
            return arr.compactMap { $0.stringValue }
        }
        set { setOrRemove("dimensions", newValue.map { .array($0.map(JSONValue.string)) }) }
    }
    public var unit: String? {
        get { properties["unit"]?.stringValue }
        set { setOrRemove("unit", newValue.map(JSONValue.string)) }
    }

    private mutating func setOrRemove(_ key: String, _ value: JSONValue?) {
        if let value { properties[key] = value } else { properties.removeValue(forKey: key) }
    }
}

public struct DatacubeExtension: STACExtension, PropertiesExtensionAccessor {
    public static let schemaURI = "https://stac-extensions.github.io/datacube/v2.2.0/schema.json"
    public static let prefix = "cube:"

    public let host: ExtensionHost
    public init(_ item: Item) { self.host = .item(item) }
    public init(_ asset: Asset) { self.host = .asset(asset) }

    public static let dimensionsProp = prefix + "dimensions"
    public static let variablesProp = prefix + "variables"

    public var dimensions: [String: DatacubeDimension]? {
        get {
            guard case let .object(o)? = get(Self.dimensionsProp) else { return nil }
            var out: [String: DatacubeDimension] = [:]
            for (k, v) in o {
                if case let .object(inner) = v { out[k] = DatacubeDimension(properties: inner) }
            }
            return out
        }
        nonmutating set {
            if let value = newValue {
                var o: [String: JSONValue] = [:]
                for (k, v) in value { o[k] = .object(v.properties) }
                set(Self.dimensionsProp, .object(o))
            } else {
                set(Self.dimensionsProp, nil)
            }
            registerSchema(Self.schemaURI)
        }
    }

    public var variables: [String: DatacubeVariable]? {
        get {
            guard case let .object(o)? = get(Self.variablesProp) else { return nil }
            var out: [String: DatacubeVariable] = [:]
            for (k, v) in o {
                if case let .object(inner) = v { out[k] = DatacubeVariable(properties: inner) }
            }
            return out
        }
        nonmutating set {
            if let value = newValue {
                var o: [String: JSONValue] = [:]
                for (k, v) in value { o[k] = .object(v.properties) }
                set(Self.variablesProp, .object(o))
            } else {
                set(Self.variablesProp, nil)
            }
            registerSchema(Self.schemaURI)
        }
    }
}
public extension Item { var cube: DatacubeExtension { DatacubeExtension(self) } }
public extension Asset { var cube: DatacubeExtension { DatacubeExtension(self) } }
