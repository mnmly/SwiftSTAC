import Foundation

/// Describes the spatial extent of a Collection.
/// Mirrors `pystac.collection.SpatialExtent`.
public struct SpatialExtent: Sendable, Equatable, Hashable, Codable {
    /// One or more bounding boxes. Each bbox has length 2*n (n = dim count).
    public var bboxes: [[Double]]
    public var extraFields: [String: JSONValue]

    public init(bboxes: [[Double]], extraFields: [String: JSONValue] = [:]) {
        self.bboxes = bboxes
        self.extraFields = extraFields
    }

    /// Convenience for the common "single bbox" case.
    public init(_ bbox: [Double], extraFields: [String: JSONValue] = [:]) {
        self.bboxes = [bbox]
        self.extraFields = extraFields
    }

    public func toDict() -> [String: JSONValue] {
        var d: [String: JSONValue] = ["bbox": .array(bboxes.map { .array($0.map { .double($0) }) })]
        for (k, v) in extraFields { d[k] = v }
        return d
    }

    public static func fromDict(_ d: [String: JSONValue]) throws -> SpatialExtent {
        guard case let .array(arr)? = d["bbox"] else {
            throw STACError.requiredPropertyMissing(object: "SpatialExtent", property: "bbox")
        }
        var bboxes: [[Double]] = []
        // Detect single-bbox-as-flat-list case
        if let first = arr.first, case .double = first {
            bboxes = [arr.compactMap { $0.doubleValue }]
        } else if let first = arr.first, case .int = first {
            bboxes = [arr.compactMap { $0.doubleValue }]
        } else {
            for item in arr {
                if case let .array(inner) = item {
                    bboxes.append(inner.compactMap { $0.doubleValue })
                }
            }
        }
        var extras: [String: JSONValue] = [:]
        for (k, v) in d where k != "bbox" { extras[k] = v }
        return SpatialExtent(bboxes: bboxes, extraFields: extras)
    }

    // Codable
    public init(from decoder: Decoder) throws {
        let v = try JSONValue(from: decoder)
        guard case let .object(d) = v else {
            throw DecodingError.typeMismatch(SpatialExtent.self, .init(codingPath: decoder.codingPath, debugDescription: "Expected object"))
        }
        self = try SpatialExtent.fromDict(d)
    }
    public func encode(to encoder: Encoder) throws {
        try JSONValue.object(toDict()).encode(to: encoder)
    }
}

/// Describes the temporal extent of a Collection.
/// Mirrors `pystac.collection.TemporalExtent`.
public struct TemporalExtent: Sendable, Equatable, Hashable, Codable {
    /// One or more `[start, end]` pairs. `nil` represents an open bound.
    public var intervals: [[Date?]]
    public var extraFields: [String: JSONValue]

    public init(intervals: [[Date?]], extraFields: [String: JSONValue] = [:]) {
        self.intervals = intervals
        self.extraFields = extraFields
    }

    /// Convenience for the single-interval case.
    public init(_ interval: [Date?], extraFields: [String: JSONValue] = [:]) {
        self.intervals = [interval]
        self.extraFields = extraFields
    }

    public func toDict() -> [String: JSONValue] {
        let encoded: [JSONValue] = intervals.map { pair in
            let start: JSONValue = pair.first.flatMap { $0 }.map { .string(HREFUtils.datetimeToString($0)) } ?? .null
            let end: JSONValue = (pair.count > 1 ? pair[1] : nil).map { .string(HREFUtils.datetimeToString($0)) } ?? .null
            return .array([start, end])
        }
        var d: [String: JSONValue] = ["interval": .array(encoded)]
        for (k, v) in extraFields { d[k] = v }
        return d
    }

    public static func fromDict(_ d: [String: JSONValue]) throws -> TemporalExtent {
        guard case let .array(arr)? = d["interval"] else {
            throw STACError.requiredPropertyMissing(object: "TemporalExtent", property: "interval")
        }
        var parsed: [[Date?]] = []
        for item in arr {
            if case let .array(pair) = item, pair.count == 2 {
                let start = (pair[0].stringValue).flatMap(HREFUtils.stringToDate)
                let end = (pair[1].stringValue).flatMap(HREFUtils.stringToDate)
                parsed.append([start, end])
            }
        }
        var extras: [String: JSONValue] = [:]
        for (k, v) in d where k != "interval" { extras[k] = v }
        return TemporalExtent(intervals: parsed, extraFields: extras)
    }

    public init(from decoder: Decoder) throws {
        let v = try JSONValue(from: decoder)
        guard case let .object(d) = v else {
            throw DecodingError.typeMismatch(TemporalExtent.self, .init(codingPath: decoder.codingPath, debugDescription: "Expected object"))
        }
        self = try TemporalExtent.fromDict(d)
    }
    public func encode(to encoder: Encoder) throws {
        try JSONValue.object(toDict()).encode(to: encoder)
    }
}

/// Spatial + temporal extents for a Collection.
public struct Extent: Sendable, Equatable, Hashable, Codable {
    public var spatial: SpatialExtent
    public var temporal: TemporalExtent
    public var extraFields: [String: JSONValue]

    public init(spatial: SpatialExtent, temporal: TemporalExtent, extraFields: [String: JSONValue] = [:]) {
        self.spatial = spatial
        self.temporal = temporal
        self.extraFields = extraFields
    }

    public func toDict() -> [String: JSONValue] {
        var d: [String: JSONValue] = [
            "spatial": .object(spatial.toDict()),
            "temporal": .object(temporal.toDict()),
        ]
        for (k, v) in extraFields { d[k] = v }
        return d
    }

    public static func fromDict(_ d: [String: JSONValue]) throws -> Extent {
        guard case let .object(sp)? = d["spatial"] else {
            throw STACError.requiredPropertyMissing(object: "Extent", property: "spatial")
        }
        guard case let .object(tp)? = d["temporal"] else {
            throw STACError.requiredPropertyMissing(object: "Extent", property: "temporal")
        }
        var extras: [String: JSONValue] = [:]
        for (k, v) in d where k != "spatial" && k != "temporal" { extras[k] = v }
        return Extent(
            spatial: try SpatialExtent.fromDict(sp),
            temporal: try TemporalExtent.fromDict(tp),
            extraFields: extras
        )
    }

    /// Derive an extent from a list of items: bbox is the union of item bboxes,
    /// temporal start/end are min/max of item datetimes (and `start_datetime`,
    /// `end_datetime` properties).
    public static func fromItems(_ items: [Item], extraFields: [String: JSONValue] = [:]) -> Extent {
        var minX = Double.infinity, minY = Double.infinity
        var maxX = -Double.infinity, maxY = -Double.infinity
        var datetimes: [Date] = []
        var starts: [Date] = []
        var ends: [Date] = []
        for item in items {
            if let bbox = item.bbox, bbox.count >= 4 {
                minX = min(minX, bbox[0])
                minY = min(minY, bbox[1])
                maxX = max(maxX, bbox[2])
                maxY = max(maxY, bbox[3])
            }
            if let dt = item.datetime { datetimes.append(dt) }
            if case let .string(s)? = item.properties["start_datetime"], let d = HREFUtils.stringToDate(s) {
                starts.append(d)
            }
            if case let .string(s)? = item.properties["end_datetime"], let d = HREFUtils.stringToDate(s) {
                ends.append(d)
            }
        }
        let spatial = minX.isFinite
            ? SpatialExtent(bboxes: [[minX, minY, maxX, maxY]])
            : SpatialExtent(bboxes: [[-180, -90, 180, 90]])
        let startCandidates = datetimes + starts
        let endCandidates = datetimes + ends
        let temporal = TemporalExtent(intervals: [[startCandidates.min(), endCandidates.max()]])
        return Extent(spatial: spatial, temporal: temporal, extraFields: extraFields)
    }

    public init(from decoder: Decoder) throws {
        let v = try JSONValue(from: decoder)
        guard case let .object(d) = v else {
            throw DecodingError.typeMismatch(Extent.self, .init(codingPath: decoder.codingPath, debugDescription: "Expected object"))
        }
        self = try Extent.fromDict(d)
    }
    public func encode(to encoder: Encoder) throws {
        try JSONValue.object(toDict()).encode(to: encoder)
    }
}
