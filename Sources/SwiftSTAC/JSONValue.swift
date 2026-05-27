import Foundation

/// A type-erased JSON value used wherever pystac uses `dict[str, Any]` /
/// `list[Any]` — `extra_fields`, item `properties`, GeoJSON geometry, etc.
///
/// Modelled to round-trip with `Foundation`'s `JSONSerialization` and to be
/// `Codable`. Equatable on structural content.
public enum JSONValue: Sendable, Equatable, Hashable {
    case null
    case bool(Bool)
    case int(Int64)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])
}

// MARK: - Codable

extension JSONValue: Codable {
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let b = try? c.decode(Bool.self) { self = .bool(b); return }
        if let i = try? c.decode(Int64.self) { self = .int(i); return }
        if let d = try? c.decode(Double.self) { self = .double(d); return }
        if let s = try? c.decode(String.self) { self = .string(s); return }
        if let a = try? c.decode([JSONValue].self) { self = .array(a); return }
        if let o = try? c.decode([String: JSONValue].self) { self = .object(o); return }
        throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unsupported JSON value")
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case let .bool(b): try c.encode(b)
        case let .int(i): try c.encode(i)
        case let .double(d): try c.encode(d)
        case let .string(s): try c.encode(s)
        case let .array(a): try c.encode(a)
        case let .object(o): try c.encode(o)
        }
    }
}

// MARK: - Bridging to Foundation `Any`

extension JSONValue {
    /// Build a JSONValue from any value that `JSONSerialization` would emit
    /// (`NSNull`, `Bool`, `NSNumber`, `String`, arrays, dictionaries).
    public static func from(any value: Any) throws -> JSONValue {
        if value is NSNull { return .null }
        if let n = value as? NSNumber {
            // Distinguish booleans from numerics. `NSNumber`s wrapping bools
            // have `objCType == "c"` (signed char) on both Apple Foundation
            // and swift-corelibs-foundation. On Apple we'd reach for
            // `CFGetTypeID(n) == CFBooleanGetTypeID()`, but CoreFoundation is
            // Darwin-only.
            let t = String(cString: n.objCType)
            if t == "c" || t == "B" { return .bool(n.boolValue) }
            if t == "f" || t == "d" { return .double(n.doubleValue) }
            return .int(n.int64Value)
        }
        if let b = value as? Bool { return .bool(b) }
        if let i = value as? Int { return .int(Int64(i)) }
        if let i = value as? Int64 { return .int(i) }
        if let d = value as? Double { return .double(d) }
        if let s = value as? String { return .string(s) }
        if let arr = value as? [Any] {
            return .array(try arr.map(JSONValue.from(any:)))
        }
        if let obj = value as? [String: Any] {
            var out: [String: JSONValue] = [:]
            out.reserveCapacity(obj.count)
            for (k, v) in obj { out[k] = try JSONValue.from(any: v) }
            return .object(out)
        }
        throw STACError.generic("Cannot convert \(type(of: value)) to JSONValue")
    }

    /// Convert back to a Foundation `Any` value suitable for `JSONSerialization`.
    public var anyValue: Any {
        switch self {
        case .null: return NSNull()
        case let .bool(b): return b
        case let .int(i): return NSNumber(value: i)
        case let .double(d): return NSNumber(value: d)
        case let .string(s): return s
        case let .array(a): return a.map(\.anyValue)
        case let .object(o):
            var out: [String: Any] = [:]
            out.reserveCapacity(o.count)
            for (k, v) in o { out[k] = v.anyValue }
            return out
        }
    }
}

// MARK: - Literals (convenience for tests and call sites)

extension JSONValue: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) { self = .null }
}
extension JSONValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) { self = .bool(value) }
}
extension JSONValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int64) { self = .int(value) }
}
extension JSONValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) { self = .double(value) }
}
extension JSONValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) { self = .string(value) }
}
extension JSONValue: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: JSONValue...) { self = .array(elements) }
}
extension JSONValue: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, JSONValue)...) {
        self = .object(Dictionary(uniqueKeysWithValues: elements))
    }
}

// MARK: - Accessors

extension JSONValue {
    public var stringValue: String? { if case let .string(s) = self { return s }; return nil }
    public var intValue: Int64? {
        switch self {
        case let .int(i): return i
        case let .double(d) where d.rounded() == d: return Int64(d)
        default: return nil
        }
    }
    public var doubleValue: Double? {
        switch self {
        case let .double(d): return d
        case let .int(i): return Double(i)
        default: return nil
        }
    }
    public var boolValue: Bool? { if case let .bool(b) = self { return b }; return nil }
    public var arrayValue: [JSONValue]? { if case let .array(a) = self { return a }; return nil }
    public var objectValue: [String: JSONValue]? { if case let .object(o) = self { return o }; return nil }
    public var isNull: Bool { if case .null = self { return true }; return false }

    public subscript(key: String) -> JSONValue? {
        if case let .object(o) = self { return o[key] }
        return nil
    }
}
