import Foundation

/// Point Cloud STAC extension. Mirrors `pystac.extensions.pointcloud`.

public enum PointCloudType: String, Sendable, Codable {
    case lidar, radar, sonar, otherPointCloudType = "other"
}

/// One entry in `pc:schemas`.
public struct PointCloudSchema: Sendable, Equatable, Hashable {
    public var name: String
    public var size: Int
    public var type: String

    public init(name: String, size: Int, type: String) {
        self.name = name; self.size = size; self.type = type
    }
    public func toJSON() -> JSONValue {
        .object(["name": .string(name), "size": .int(Int64(size)), "type": .string(type)])
    }
    public static func fromJSON(_ v: JSONValue) -> PointCloudSchema? {
        guard case let .object(o) = v,
              case let .string(name)? = o["name"],
              let size = o["size"]?.intValue.map(Int.init),
              case let .string(type)? = o["type"]
        else { return nil }
        return PointCloudSchema(name: name, size: size, type: type)
    }
}

/// One entry in `pc:statistics`.
public struct PointCloudStatistics: Sendable, Equatable, Hashable {
    public var properties: [String: JSONValue]
    public init(properties: [String: JSONValue] = [:]) { self.properties = properties }
}

public struct PointCloudExtension: STACExtension, PropertiesExtensionAccessor {
    public static let schemaURI = "https://stac-extensions.github.io/pointcloud/v1.0.0/schema.json"
    public static let prefix = "pc:"

    public let host: ExtensionHost
    public init(_ item: Item) { self.host = .item(item) }
    public init(_ asset: Asset) { self.host = .asset(asset) }

    public static let countProp = prefix + "count"
    public static let typeProp = prefix + "type"
    public static let encodingProp = prefix + "encoding"
    public static let schemasProp = prefix + "schemas"
    public static let densityProp = prefix + "density"
    public static let statisticsProp = prefix + "statistics"

    public var count: Int64? {
        get { get(Self.countProp)?.intValue }
        nonmutating set { set(Self.countProp, newValue.map(JSONValue.int)); registerSchema(Self.schemaURI) }
    }
    public var type: PointCloudType? {
        get { get(Self.typeProp)?.stringValue.flatMap(PointCloudType.init(rawValue:)) }
        nonmutating set { set(Self.typeProp, newValue.map { .string($0.rawValue) }); registerSchema(Self.schemaURI) }
    }
    public var encoding: String? {
        get { get(Self.encodingProp)?.stringValue }
        nonmutating set { set(Self.encodingProp, newValue.map(JSONValue.string)); registerSchema(Self.schemaURI) }
    }
    public var schemas: [PointCloudSchema]? {
        get {
            guard case let .array(arr)? = get(Self.schemasProp) else { return nil }
            return arr.compactMap(PointCloudSchema.fromJSON)
        }
        nonmutating set {
            set(Self.schemasProp, newValue.map { .array($0.map { $0.toJSON() }) })
            registerSchema(Self.schemaURI)
        }
    }
    public var density: Double? {
        get { get(Self.densityProp)?.doubleValue }
        nonmutating set { set(Self.densityProp, newValue.map(JSONValue.double)); registerSchema(Self.schemaURI) }
    }
    public var statistics: [PointCloudStatistics]? {
        get {
            guard case let .array(arr)? = get(Self.statisticsProp) else { return nil }
            return arr.compactMap { v in
                if case let .object(o) = v { return PointCloudStatistics(properties: o) }
                return nil
            }
        }
        nonmutating set {
            set(Self.statisticsProp, newValue.map { .array($0.map { .object($0.properties) }) })
            registerSchema(Self.schemaURI)
        }
    }
}
public extension Item { var pc: PointCloudExtension { PointCloudExtension(self) } }
public extension Asset { var pc: PointCloudExtension { PointCloudExtension(self) } }
