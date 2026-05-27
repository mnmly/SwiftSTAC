import Foundation

/// One raster band entry in a `raster:bands` array. Mirrors
/// `pystac.extensions.raster.RasterBand` — a property bag with typed accessors.
public struct RasterBand: Sendable, Equatable, Hashable {
    public var properties: [String: JSONValue]
    public init(properties: [String: JSONValue] = [:]) { self.properties = properties }

    public init(
        nodata: JSONValue? = nil,
        dataType: String? = nil,
        bitsPerSample: Int? = nil,
        spatialResolution: Double? = nil,
        scale: Double? = nil,
        offset: Double? = nil,
        unit: String? = nil,
        statistics: [String: JSONValue]? = nil,
        histogram: [String: JSONValue]? = nil
    ) {
        var p: [String: JSONValue] = [:]
        if let nodata { p["nodata"] = nodata }
        if let dataType { p["data_type"] = .string(dataType) }
        if let bitsPerSample { p["bits_per_sample"] = .int(Int64(bitsPerSample)) }
        if let spatialResolution { p["spatial_resolution"] = .double(spatialResolution) }
        if let scale { p["scale"] = .double(scale) }
        if let offset { p["offset"] = .double(offset) }
        if let unit { p["unit"] = .string(unit) }
        if let statistics { p["statistics"] = .object(statistics) }
        if let histogram { p["histogram"] = .object(histogram) }
        self.properties = p
    }

    public var nodata: JSONValue? {
        get { properties["nodata"] }
        set { setOrRemove("nodata", newValue) }
    }
    public var dataType: String? {
        get { properties["data_type"]?.stringValue }
        set { setOrRemove("data_type", newValue.map(JSONValue.string)) }
    }
    public var bitsPerSample: Int? {
        get { properties["bits_per_sample"]?.intValue.map(Int.init) }
        set { setOrRemove("bits_per_sample", newValue.map { .int(Int64($0)) }) }
    }
    public var spatialResolution: Double? {
        get { properties["spatial_resolution"]?.doubleValue }
        set { setOrRemove("spatial_resolution", newValue.map(JSONValue.double)) }
    }
    public var scale: Double? {
        get { properties["scale"]?.doubleValue }
        set { setOrRemove("scale", newValue.map(JSONValue.double)) }
    }
    public var offset: Double? {
        get { properties["offset"]?.doubleValue }
        set { setOrRemove("offset", newValue.map(JSONValue.double)) }
    }
    public var unit: String? {
        get { properties["unit"]?.stringValue }
        set { setOrRemove("unit", newValue.map(JSONValue.string)) }
    }

    private mutating func setOrRemove(_ key: String, _ value: JSONValue?) {
        if let value { properties[key] = value } else { properties.removeValue(forKey: key) }
    }
}

/// Raster STAC extension. Mirrors `pystac.extensions.raster`.
public struct RasterExtension: STACExtension, PropertiesExtensionAccessor {
    public static let schemaURI = "https://stac-extensions.github.io/raster/v1.1.0/schema.json"
    public static let prefix = "raster:"

    public let host: ExtensionHost
    public init(_ item: Item) { self.host = .item(item) }
    public init(_ asset: Asset) { self.host = .asset(asset) }

    /// Note: `raster:bands` actually has the literal prefix `raster:` but is
    /// also stored unprefixed in older versions. We always use the prefixed
    /// form for parity with the v1.1.0 schema.
    public static let bandsProp = "raster:bands"

    public var bands: [RasterBand]? {
        get {
            guard case let .array(arr)? = get(Self.bandsProp) else { return nil }
            return arr.compactMap { v in
                if case let .object(o) = v { return RasterBand(properties: o) }
                return nil
            }
        }
        nonmutating set {
            set(Self.bandsProp, newValue.map { .array($0.map { .object($0.properties) }) })
            registerSchema(Self.schemaURI)
        }
    }
}
public extension Item { var raster: RasterExtension { RasterExtension(self) } }
public extension Asset { var raster: RasterExtension { RasterExtension(self) } }
