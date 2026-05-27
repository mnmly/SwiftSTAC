import Foundation

/// A `min`/`max` pair attached to a property in a Collection's `summaries`.
///
/// Mirrors `pystac.summaries.RangeSummary`.
public struct RangeSummary: Sendable, Equatable, Hashable {
    public var minimum: JSONValue
    public var maximum: JSONValue

    public init(minimum: JSONValue, maximum: JSONValue) {
        self.minimum = minimum
        self.maximum = maximum
    }

    public func toDict() -> [String: JSONValue] {
        ["minimum": minimum, "maximum": maximum]
    }

    public static func fromDict(_ d: [String: JSONValue]) throws -> RangeSummary {
        guard let minimum = d["minimum"] else {
            throw STACError.requiredPropertyMissing(object: "RangeSummary", property: "minimum")
        }
        guard let maximum = d["maximum"] else {
            throw STACError.requiredPropertyMissing(object: "RangeSummary", property: "maximum")
        }
        return RangeSummary(minimum: minimum, maximum: maximum)
    }
}

/// Collection-level summaries. Mirrors `pystac.summaries.Summaries`.
///
/// Each property in the source dict goes into one of four bins:
/// - ``lists``   — JSON arrays (set summaries)
/// - ``ranges``  — `{"minimum": …, "maximum": …}` range summaries
/// - ``schemas`` — JSON Schema objects (anything else dict-shaped)
/// - ``other``   — everything that does not fit the above
public struct Summaries: Sendable, Equatable, Hashable {

    public static let defaultMaxCount = 25

    public var lists: [String: [JSONValue]]
    public var ranges: [String: RangeSummary]
    public var schemas: [String: [String: JSONValue]]
    public var other: [String: JSONValue]
    public var maxCount: Int

    public init(
        lists: [String: [JSONValue]] = [:],
        ranges: [String: RangeSummary] = [:],
        schemas: [String: [String: JSONValue]] = [:],
        other: [String: JSONValue] = [:],
        maxCount: Int = Summaries.defaultMaxCount
    ) {
        self.lists = lists
        self.ranges = ranges
        self.schemas = schemas
        self.other = other
        self.maxCount = maxCount
    }

    public static var empty: Summaries { Summaries() }

    public var isEmpty: Bool {
        lists.isEmpty && ranges.isEmpty && schemas.isEmpty && other.isEmpty
    }

    public func getList(_ prop: String) -> [JSONValue]? { lists[prop] }
    public func getRange(_ prop: String) -> RangeSummary? { ranges[prop] }
    public func getSchema(_ prop: String) -> [String: JSONValue]? { schemas[prop] }

    /// Insert a property summary into the correct bin based on its JSON shape.
    public mutating func add(_ prop: String, value: JSONValue) {
        clearKey(prop)
        switch value {
        case let .array(arr):
            lists[prop] = arr
        case let .object(o):
            if o["minimum"] != nil, o["maximum"] != nil, (try? RangeSummary.fromDict(o)) != nil {
                ranges[prop] = try! RangeSummary.fromDict(o)
            } else {
                schemas[prop] = o
            }
        default:
            other[prop] = value
        }
    }

    public mutating func addRange(_ prop: String, _ range: RangeSummary) {
        clearKey(prop)
        ranges[prop] = range
    }

    public mutating func remove(_ prop: String) { clearKey(prop) }

    private mutating func clearKey(_ k: String) {
        lists.removeValue(forKey: k)
        ranges.removeValue(forKey: k)
        schemas.removeValue(forKey: k)
        other.removeValue(forKey: k)
    }

    /// Encode to the flat `[String: JSONValue]` shape expected by STAC.
    public func toDict() -> [String: JSONValue] {
        var d: [String: JSONValue] = [:]
        for (k, v) in lists where v.count < maxCount {
            d[k] = .array(v)
        }
        for (k, r) in ranges {
            d[k] = .object(r.toDict())
        }
        for (k, s) in schemas {
            d[k] = .object(s)
        }
        for (k, v) in other {
            d[k] = v
        }
        return d
    }

    public static func fromDict(_ d: [String: JSONValue], maxCount: Int = Summaries.defaultMaxCount) -> Summaries {
        var s = Summaries(maxCount: maxCount)
        for (k, v) in d { s.add(k, value: v) }
        return s
    }
}
