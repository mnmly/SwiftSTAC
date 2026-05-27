import Foundation

/// Label STAC extension. Mirrors `pystac.extensions.label`.

public enum LabelType: String, Sendable, Codable {
    case vector, raster
}

public enum LabelTask: String, Sendable, Codable {
    case regression, classification, detection, segmentation
}

/// One entry in `label:classes`.
public struct LabelClasses: Sendable, Equatable, Hashable {
    public var name: String?
    /// Class values — can be strings or ints; carry them through as JSONValues.
    public var classes: [JSONValue]

    public init(name: String? = nil, classes: [JSONValue]) {
        self.name = name
        self.classes = classes
    }

    public func toJSON() -> JSONValue {
        var o: [String: JSONValue] = ["classes": .array(classes)]
        if let name { o["name"] = .string(name) }
        return .object(o)
    }

    public static func fromJSON(_ v: JSONValue) -> LabelClasses? {
        guard case let .object(o) = v else { return nil }
        guard case let .array(cs)? = o["classes"] else { return nil }
        return LabelClasses(name: o["name"]?.stringValue, classes: cs)
    }
}

/// One entry in `label:overviews`.
public struct LabelOverview: Sendable, Equatable, Hashable {
    public var propertyKey: String?
    public var counts: [LabelCount]?
    public var statistics: [LabelStatistics]?

    public init(propertyKey: String? = nil, counts: [LabelCount]? = nil, statistics: [LabelStatistics]? = nil) {
        self.propertyKey = propertyKey
        self.counts = counts
        self.statistics = statistics
    }

    public func toJSON() -> JSONValue {
        var o: [String: JSONValue] = [:]
        if let propertyKey { o["property_key"] = .string(propertyKey) }
        if let counts { o["counts"] = .array(counts.map { $0.toJSON() }) }
        if let statistics { o["statistics"] = .array(statistics.map { $0.toJSON() }) }
        return .object(o)
    }

    public static func fromJSON(_ v: JSONValue) -> LabelOverview? {
        guard case let .object(o) = v else { return nil }
        let counts: [LabelCount]? = {
            guard case let .array(arr)? = o["counts"] else { return nil }
            return arr.compactMap(LabelCount.fromJSON)
        }()
        let stats: [LabelStatistics]? = {
            guard case let .array(arr)? = o["statistics"] else { return nil }
            return arr.compactMap(LabelStatistics.fromJSON)
        }()
        return LabelOverview(
            propertyKey: o["property_key"]?.stringValue,
            counts: counts,
            statistics: stats
        )
    }
}

public struct LabelCount: Sendable, Equatable, Hashable {
    public var name: String
    public var count: Int
    public init(name: String, count: Int) { self.name = name; self.count = count }
    public func toJSON() -> JSONValue { .object(["name": .string(name), "count": .int(Int64(count))]) }
    public static func fromJSON(_ v: JSONValue) -> LabelCount? {
        guard case let .object(o) = v,
              case let .string(name)? = o["name"],
              let count = o["count"]?.intValue
        else { return nil }
        return LabelCount(name: name, count: Int(count))
    }
}

public struct LabelStatistics: Sendable, Equatable, Hashable {
    public var name: String
    public var value: Double
    public init(name: String, value: Double) { self.name = name; self.value = value }
    public func toJSON() -> JSONValue { .object(["name": .string(name), "value": .double(value)]) }
    public static func fromJSON(_ v: JSONValue) -> LabelStatistics? {
        guard case let .object(o) = v,
              case let .string(name)? = o["name"],
              let value = o["value"]?.doubleValue
        else { return nil }
        return LabelStatistics(name: name, value: value)
    }
}

public struct LabelExtension: STACExtension, PropertiesExtensionAccessor {
    public static let schemaURI = "https://stac-extensions.github.io/label/v1.0.1/schema.json"
    public static let prefix = "label:"

    public let host: ExtensionHost
    public init(_ item: Item) { self.host = .item(item) }

    public static let propertiesProp = prefix + "properties"
    public static let classesProp = prefix + "classes"
    public static let descriptionProp = prefix + "description"
    public static let typeProp = prefix + "type"
    public static let tasksProp = prefix + "tasks"
    public static let methodsProp = prefix + "methods"
    public static let overviewsProp = prefix + "overviews"

    /// `null` means raster labels; otherwise list of property names containing
    /// labels (vector labels). pystac semantics.
    public var labelProperties: [String]?? {
        get {
            guard let v = get(Self.propertiesProp) else { return nil }
            if v.isNull { return .some(nil) }
            if case let .array(arr) = v { return .some(arr.compactMap { $0.stringValue }) }
            return nil
        }
        nonmutating set {
            switch newValue {
            case .none: set(Self.propertiesProp, nil)
            case .some(.none): set(Self.propertiesProp, .null)
            case let .some(.some(props)): set(Self.propertiesProp, .array(props.map(JSONValue.string)))
            }
            registerSchema(Self.schemaURI)
        }
    }

    public var classes: [LabelClasses]? {
        get {
            guard case let .array(arr)? = get(Self.classesProp) else { return nil }
            return arr.compactMap(LabelClasses.fromJSON)
        }
        nonmutating set {
            set(Self.classesProp, newValue.map { .array($0.map { $0.toJSON() }) })
            registerSchema(Self.schemaURI)
        }
    }

    public var labelDescription: String? {
        get { get(Self.descriptionProp)?.stringValue }
        nonmutating set { set(Self.descriptionProp, newValue.map(JSONValue.string)); registerSchema(Self.schemaURI) }
    }

    public var labelType: LabelType? {
        get { get(Self.typeProp)?.stringValue.flatMap(LabelType.init(rawValue:)) }
        nonmutating set { set(Self.typeProp, newValue.map { .string($0.rawValue) }); registerSchema(Self.schemaURI) }
    }

    public var tasks: [String]? {
        get {
            guard case let .array(arr)? = get(Self.tasksProp) else { return nil }
            return arr.compactMap { $0.stringValue }
        }
        nonmutating set {
            set(Self.tasksProp, newValue.map { .array($0.map(JSONValue.string)) })
            registerSchema(Self.schemaURI)
        }
    }

    public var methods: [String]? {
        get {
            guard case let .array(arr)? = get(Self.methodsProp) else { return nil }
            return arr.compactMap { $0.stringValue }
        }
        nonmutating set {
            set(Self.methodsProp, newValue.map { .array($0.map(JSONValue.string)) })
            registerSchema(Self.schemaURI)
        }
    }

    public var overviews: [LabelOverview]? {
        get {
            guard case let .array(arr)? = get(Self.overviewsProp) else { return nil }
            return arr.compactMap(LabelOverview.fromJSON)
        }
        nonmutating set {
            set(Self.overviewsProp, newValue.map { .array($0.map { $0.toJSON() }) })
            registerSchema(Self.schemaURI)
        }
    }
}
public extension Item { var label: LabelExtension { LabelExtension(self) } }
