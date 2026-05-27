import Foundation

/// Classification STAC extension. Mirrors `pystac.extensions.classification`.

/// A single class entry.
public struct Classification: Sendable, Equatable, Hashable {
    public var value: Int
    public var classDescription: String?
    public var name: String?
    public var title: String?
    public var color: String?
    public var nodata: Bool?
    public var percentage: Double?
    public var count: Int?

    public init(
        value: Int,
        description: String? = nil,
        name: String? = nil,
        title: String? = nil,
        color: String? = nil,
        nodata: Bool? = nil,
        percentage: Double? = nil,
        count: Int? = nil
    ) {
        self.value = value
        self.classDescription = description
        self.name = name
        self.title = title
        self.color = color
        self.nodata = nodata
        self.percentage = percentage
        self.count = count
    }

    public func toJSON() -> JSONValue {
        var o: [String: JSONValue] = ["value": .int(Int64(value))]
        if let classDescription { o["description"] = .string(classDescription) }
        if let name { o["name"] = .string(name) }
        if let title { o["title"] = .string(title) }
        if let color { o["color_hint"] = .string(color) }
        if let nodata { o["nodata"] = .bool(nodata) }
        if let percentage { o["percentage"] = .double(percentage) }
        if let count { o["count"] = .int(Int64(count)) }
        return .object(o)
    }

    public static func fromJSON(_ v: JSONValue) -> Classification? {
        guard case let .object(o) = v,
              let value = o["value"]?.intValue.map(Int.init)
        else { return nil }
        return Classification(
            value: value,
            description: o["description"]?.stringValue,
            name: o["name"]?.stringValue,
            title: o["title"]?.stringValue,
            color: o["color_hint"]?.stringValue,
            nodata: o["nodata"]?.boolValue,
            percentage: o["percentage"]?.doubleValue,
            count: o["count"]?.intValue.map(Int.init)
        )
    }
}

/// A bitfield entry.
public struct ClassificationBitfield: Sendable, Equatable, Hashable {
    public var offset: Int
    public var length: Int
    public var classes: [Classification]
    public var roles: [String]?
    public var bitDescription: String?
    public var name: String?

    public init(
        offset: Int,
        length: Int,
        classes: [Classification],
        roles: [String]? = nil,
        description: String? = nil,
        name: String? = nil
    ) {
        self.offset = offset
        self.length = length
        self.classes = classes
        self.roles = roles
        self.bitDescription = description
        self.name = name
    }

    public func toJSON() -> JSONValue {
        var o: [String: JSONValue] = [
            "offset": .int(Int64(offset)),
            "length": .int(Int64(length)),
            "classes": .array(classes.map { $0.toJSON() }),
        ]
        if let roles { o["roles"] = .array(roles.map(JSONValue.string)) }
        if let bitDescription { o["description"] = .string(bitDescription) }
        if let name { o["name"] = .string(name) }
        return .object(o)
    }

    public static func fromJSON(_ v: JSONValue) -> ClassificationBitfield? {
        guard case let .object(o) = v,
              let offset = o["offset"]?.intValue.map(Int.init),
              let length = o["length"]?.intValue.map(Int.init),
              case let .array(arr)? = o["classes"]
        else { return nil }
        let classes = arr.compactMap(Classification.fromJSON)
        let roles: [String]? = {
            guard case let .array(rs)? = o["roles"] else { return nil }
            return rs.compactMap { $0.stringValue }
        }()
        return ClassificationBitfield(
            offset: offset, length: length, classes: classes,
            roles: roles,
            description: o["description"]?.stringValue,
            name: o["name"]?.stringValue
        )
    }
}

public struct ClassificationExtension: STACExtension, PropertiesExtensionAccessor {
    public static let schemaURIPattern = "https://stac-extensions.github.io/classification/v{version}/schema.json"
    public static let schemaURI = "https://stac-extensions.github.io/classification/v2.0.0/schema.json"
    public static let prefix = "classification:"

    public let host: ExtensionHost
    public init(_ item: Item) { self.host = .item(item) }
    public init(_ asset: Asset) { self.host = .asset(asset) }

    public static let bitfieldsProp = prefix + "bitfields"
    public static let classesProp = prefix + "classes"

    public var classes: [Classification]? {
        get {
            guard case let .array(arr)? = get(Self.classesProp) else { return nil }
            return arr.compactMap(Classification.fromJSON)
        }
        nonmutating set {
            set(Self.classesProp, newValue.map { .array($0.map { $0.toJSON() }) })
            registerSchema(Self.schemaURI)
        }
    }

    public var bitfields: [ClassificationBitfield]? {
        get {
            guard case let .array(arr)? = get(Self.bitfieldsProp) else { return nil }
            return arr.compactMap(ClassificationBitfield.fromJSON)
        }
        nonmutating set {
            set(Self.bitfieldsProp, newValue.map { .array($0.map { $0.toJSON() }) })
            registerSchema(Self.schemaURI)
        }
    }
}
public extension Item { var classification: ClassificationExtension { ClassificationExtension(self) } }
public extension Asset { var classification: ClassificationExtension { ClassificationExtension(self) } }
