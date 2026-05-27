import Foundation

/// Projection STAC extension. Mirrors `pystac.extensions.projection`.
public struct ProjectionExtension: STACExtension, PropertiesExtensionAccessor {

    public static let schemaURI = "https://stac-extensions.github.io/projection/v2.0.0/schema.json"
    public static let schemaURIs: [String] = [
        "https://stac-extensions.github.io/projection/v1.0.0/schema.json",
        "https://stac-extensions.github.io/projection/v1.1.0/schema.json",
        "https://stac-extensions.github.io/projection/v1.2.0/schema.json",
        schemaURI,
    ]
    public static let prefix = "proj:"

    public let host: ExtensionHost

    public init(_ item: Item) { self.host = .item(item) }
    public init(_ asset: Asset) { self.host = .asset(asset) }

    // MARK: - Field constants

    public static let codeProp = prefix + "code"
    public static let epsgProp = prefix + "epsg"
    public static let wkt2Prop = prefix + "wkt2"
    public static let projjsonProp = prefix + "projjson"
    public static let geometryProp = prefix + "geometry"
    public static let bboxProp = prefix + "bbox"
    public static let centroidProp = prefix + "centroid"
    public static let shapeProp = prefix + "shape"
    public static let transformProp = prefix + "transform"

    // MARK: - Accessors

    public var code: String? {
        get { get(Self.codeProp)?.stringValue }
        nonmutating set {
            set(Self.codeProp, newValue.map(JSONValue.string))
            registerSchema(Self.schemaURI)
        }
    }

    public var epsg: Int? {
        get { get(Self.epsgProp)?.intValue.map(Int.init) }
        nonmutating set {
            set(Self.epsgProp, newValue.map { .int(Int64($0)) })
            registerSchema(Self.schemaURI)
        }
    }

    public var wkt2: String? {
        get { get(Self.wkt2Prop)?.stringValue }
        nonmutating set {
            set(Self.wkt2Prop, newValue.map(JSONValue.string))
            registerSchema(Self.schemaURI)
        }
    }

    public var projjson: [String: JSONValue]? {
        get {
            if case let .object(o)? = get(Self.projjsonProp) { return o }
            return nil
        }
        nonmutating set {
            set(Self.projjsonProp, newValue.map(JSONValue.object))
            registerSchema(Self.schemaURI)
        }
    }

    public var geometry: [String: JSONValue]? {
        get {
            if case let .object(o)? = get(Self.geometryProp) { return o }
            return nil
        }
        nonmutating set {
            set(Self.geometryProp, newValue.map(JSONValue.object))
            registerSchema(Self.schemaURI)
        }
    }

    public var bbox: [Double]? {
        get {
            if case let .array(arr)? = get(Self.bboxProp) {
                return arr.compactMap { $0.doubleValue }
            }
            return nil
        }
        nonmutating set {
            set(Self.bboxProp, newValue.map { .array($0.map(JSONValue.double)) })
            registerSchema(Self.schemaURI)
        }
    }

    public var centroid: [String: Double]? {
        get {
            if case let .object(o)? = get(Self.centroidProp) {
                var result: [String: Double] = [:]
                for (k, v) in o {
                    if let d = v.doubleValue { result[k] = d }
                }
                return result
            }
            return nil
        }
        nonmutating set {
            if let value = newValue {
                var out: [String: JSONValue] = [:]
                for (k, v) in value { out[k] = .double(v) }
                set(Self.centroidProp, .object(out))
            } else {
                set(Self.centroidProp, nil)
            }
            registerSchema(Self.schemaURI)
        }
    }

    public var shape: [Int]? {
        get {
            if case let .array(arr)? = get(Self.shapeProp) {
                return arr.compactMap { $0.intValue.map(Int.init) }
            }
            return nil
        }
        nonmutating set {
            set(Self.shapeProp, newValue.map { .array($0.map { .int(Int64($0)) }) })
            registerSchema(Self.schemaURI)
        }
    }

    public var transform: [Double]? {
        get {
            if case let .array(arr)? = get(Self.transformProp) {
                return arr.compactMap { $0.doubleValue }
            }
            return nil
        }
        nonmutating set {
            set(Self.transformProp, newValue.map { .array($0.map(JSONValue.double)) })
            registerSchema(Self.schemaURI)
        }
    }
}

public extension Item {
    /// Projection extension accessor.
    var proj: ProjectionExtension { ProjectionExtension(self) }
}

public extension Asset {
    /// Projection extension accessor.
    var proj: ProjectionExtension { ProjectionExtension(self) }
}
