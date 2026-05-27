import Foundation

// MARK: - Grid

/// Grid STAC extension. Mirrors `pystac.extensions.grid`.
public struct GridExtension: STACExtension, PropertiesExtensionAccessor {
    public static let schemaURI = "https://stac-extensions.github.io/grid/v1.1.0/schema.json"
    public static let prefix = "grid:"

    public let host: ExtensionHost
    public init(_ item: Item) { self.host = .item(item) }
    public init(_ asset: Asset) { self.host = .asset(asset) }

    public static let codeProp = prefix + "code"

    /// Grid identifier; required when this extension is in use.
    public var code: String? {
        get { get(Self.codeProp)?.stringValue }
        nonmutating set {
            set(Self.codeProp, newValue.map(JSONValue.string))
            registerSchema(Self.schemaURI)
        }
    }
}
public extension Item { var grid: GridExtension { GridExtension(self) } }
public extension Asset { var grid: GridExtension { GridExtension(self) } }

// MARK: - MGRS

/// MGRS STAC extension. Mirrors `pystac.extensions.mgrs`.
public struct MGRSExtension: STACExtension, PropertiesExtensionAccessor {
    public static let schemaURI = "https://stac-extensions.github.io/mgrs/v1.0.0/schema.json"
    public static let prefix = "mgrs:"

    public let host: ExtensionHost
    public init(_ item: Item) { self.host = .item(item) }
    public init(_ asset: Asset) { self.host = .asset(asset) }

    public static let latitudeBandProp = prefix + "latitude_band"
    public static let gridSquareProp = prefix + "grid_square"
    public static let utmZoneProp = prefix + "utm_zone"

    public var latitudeBand: String? {
        get { get(Self.latitudeBandProp)?.stringValue }
        nonmutating set { set(Self.latitudeBandProp, newValue.map(JSONValue.string)); registerSchema(Self.schemaURI) }
    }
    public var gridSquare: String? {
        get { get(Self.gridSquareProp)?.stringValue }
        nonmutating set { set(Self.gridSquareProp, newValue.map(JSONValue.string)); registerSchema(Self.schemaURI) }
    }
    public var utmZone: Int? {
        get { get(Self.utmZoneProp)?.intValue.map(Int.init) }
        nonmutating set { set(Self.utmZoneProp, newValue.map { .int(Int64($0)) }); registerSchema(Self.schemaURI) }
    }
}
public extension Item { var mgrs: MGRSExtension { MGRSExtension(self) } }
public extension Asset { var mgrs: MGRSExtension { MGRSExtension(self) } }

// MARK: - View

/// View geometry STAC extension. Mirrors `pystac.extensions.view`.
public struct ViewExtension: STACExtension, PropertiesExtensionAccessor {
    public static let schemaURI = "https://stac-extensions.github.io/view/v1.0.0/schema.json"
    public static let prefix = "view:"

    public let host: ExtensionHost
    public init(_ item: Item) { self.host = .item(item) }
    public init(_ asset: Asset) { self.host = .asset(asset) }

    public static let offNadirProp = prefix + "off_nadir"
    public static let incidenceAngleProp = prefix + "incidence_angle"
    public static let azimuthProp = prefix + "azimuth"
    public static let sunAzimuthProp = prefix + "sun_azimuth"
    public static let sunElevationProp = prefix + "sun_elevation"

    public var offNadir: Double? {
        get { get(Self.offNadirProp)?.doubleValue }
        nonmutating set { set(Self.offNadirProp, newValue.map(JSONValue.double)); registerSchema(Self.schemaURI) }
    }
    public var incidenceAngle: Double? {
        get { get(Self.incidenceAngleProp)?.doubleValue }
        nonmutating set { set(Self.incidenceAngleProp, newValue.map(JSONValue.double)); registerSchema(Self.schemaURI) }
    }
    public var azimuth: Double? {
        get { get(Self.azimuthProp)?.doubleValue }
        nonmutating set { set(Self.azimuthProp, newValue.map(JSONValue.double)); registerSchema(Self.schemaURI) }
    }
    public var sunAzimuth: Double? {
        get { get(Self.sunAzimuthProp)?.doubleValue }
        nonmutating set { set(Self.sunAzimuthProp, newValue.map(JSONValue.double)); registerSchema(Self.schemaURI) }
    }
    public var sunElevation: Double? {
        get { get(Self.sunElevationProp)?.doubleValue }
        nonmutating set { set(Self.sunElevationProp, newValue.map(JSONValue.double)); registerSchema(Self.schemaURI) }
    }
}
public extension Item { var view: ViewExtension { ViewExtension(self) } }
public extension Asset { var view: ViewExtension { ViewExtension(self) } }

// MARK: - Sat

/// Satellite STAC extension. Mirrors `pystac.extensions.sat`.
public enum OrbitState: String, Sendable, Codable {
    case ascending, descending, geostationary
}

public struct SatExtension: STACExtension, PropertiesExtensionAccessor {
    public static let schemaURI = "https://stac-extensions.github.io/sat/v1.0.0/schema.json"
    public static let prefix = "sat:"

    public let host: ExtensionHost
    public init(_ item: Item) { self.host = .item(item) }
    public init(_ asset: Asset) { self.host = .asset(asset) }

    public static let platformInternationalDesignatorProp = prefix + "platform_international_designator"
    public static let absoluteOrbitProp = prefix + "absolute_orbit"
    public static let orbitStateProp = prefix + "orbit_state"
    public static let relativeOrbitProp = prefix + "relative_orbit"
    public static let anxDatetimeProp = prefix + "anx_datetime"

    public var platformInternationalDesignator: String? {
        get { get(Self.platformInternationalDesignatorProp)?.stringValue }
        nonmutating set { set(Self.platformInternationalDesignatorProp, newValue.map(JSONValue.string)); registerSchema(Self.schemaURI) }
    }
    public var absoluteOrbit: Int? {
        get { get(Self.absoluteOrbitProp)?.intValue.map(Int.init) }
        nonmutating set { set(Self.absoluteOrbitProp, newValue.map { .int(Int64($0)) }); registerSchema(Self.schemaURI) }
    }
    public var orbitState: OrbitState? {
        get { get(Self.orbitStateProp)?.stringValue.flatMap(OrbitState.init(rawValue:)) }
        nonmutating set { set(Self.orbitStateProp, newValue.map { .string($0.rawValue) }); registerSchema(Self.schemaURI) }
    }
    public var relativeOrbit: Int? {
        get { get(Self.relativeOrbitProp)?.intValue.map(Int.init) }
        nonmutating set { set(Self.relativeOrbitProp, newValue.map { .int(Int64($0)) }); registerSchema(Self.schemaURI) }
    }
    public var anxDatetime: Date? {
        get { get(Self.anxDatetimeProp)?.stringValue.flatMap(HREFUtils.stringToDate) }
        nonmutating set { set(Self.anxDatetimeProp, newValue.map { .string(HREFUtils.datetimeToString($0)) }); registerSchema(Self.schemaURI) }
    }
}
public extension Item { var sat: SatExtension { SatExtension(self) } }
public extension Asset { var sat: SatExtension { SatExtension(self) } }

// MARK: - Scientific

/// Scientific STAC extension. Mirrors `pystac.extensions.scientific`.
public struct Publication: Sendable, Equatable, Hashable {
    public var doi: String?
    public var citation: String?
    public init(doi: String? = nil, citation: String? = nil) {
        self.doi = doi; self.citation = citation
    }
    public func toJSON() -> JSONValue {
        var o: [String: JSONValue] = [:]
        if let doi { o["doi"] = .string(doi) }
        if let citation { o["citation"] = .string(citation) }
        return .object(o)
    }
    public static func fromJSON(_ v: JSONValue) -> Publication? {
        guard case let .object(o) = v else { return nil }
        return Publication(doi: o["doi"]?.stringValue, citation: o["citation"]?.stringValue)
    }
}

public struct ScientificExtension: STACExtension, PropertiesExtensionAccessor {
    public static let schemaURI = "https://stac-extensions.github.io/scientific/v1.0.0/schema.json"
    public static let prefix = "sci:"

    public let host: ExtensionHost
    public init(_ item: Item) { self.host = .item(item) }
    public init(_ asset: Asset) { self.host = .asset(asset) }

    public static let doiProp = prefix + "doi"
    public static let citationProp = prefix + "citation"
    public static let publicationsProp = prefix + "publications"

    public var doi: String? {
        get { get(Self.doiProp)?.stringValue }
        nonmutating set { set(Self.doiProp, newValue.map(JSONValue.string)); registerSchema(Self.schemaURI) }
    }
    public var citation: String? {
        get { get(Self.citationProp)?.stringValue }
        nonmutating set { set(Self.citationProp, newValue.map(JSONValue.string)); registerSchema(Self.schemaURI) }
    }
    public var publications: [Publication]? {
        get {
            guard case let .array(arr)? = get(Self.publicationsProp) else { return nil }
            return arr.compactMap(Publication.fromJSON)
        }
        nonmutating set {
            set(Self.publicationsProp, newValue.map { .array($0.map { $0.toJSON() }) })
            registerSchema(Self.schemaURI)
        }
    }
}
public extension Item { var sci: ScientificExtension { ScientificExtension(self) } }
public extension Asset { var sci: ScientificExtension { ScientificExtension(self) } }

// MARK: - File

/// File STAC extension. Mirrors `pystac.extensions.file`.
public enum ByteOrder: String, Sendable, Codable {
    case bigEndian = "big-endian"
    case littleEndian = "little-endian"
}

public struct MappedObject: Sendable, Equatable, Hashable {
    public var values: [JSONValue]
    public var summary: String
    public init(values: [JSONValue], summary: String) {
        self.values = values; self.summary = summary
    }
}

public struct FileExtension: STACExtension, PropertiesExtensionAccessor {
    public static let schemaURI = "https://stac-extensions.github.io/file/v2.1.0/schema.json"
    public static let prefix = "file:"

    public let host: ExtensionHost
    public init(_ item: Item) { self.host = .item(item) }
    public init(_ asset: Asset) { self.host = .asset(asset) }

    public static let byteOrderProp = prefix + "byte_order"
    public static let checksumProp = prefix + "checksum"
    public static let headerSizeProp = prefix + "header_size"
    public static let sizeProp = prefix + "size"
    public static let valuesProp = prefix + "values"
    public static let localPathProp = prefix + "local_path"

    public var byteOrder: ByteOrder? {
        get { get(Self.byteOrderProp)?.stringValue.flatMap(ByteOrder.init(rawValue:)) }
        nonmutating set { set(Self.byteOrderProp, newValue.map { .string($0.rawValue) }); registerSchema(Self.schemaURI) }
    }
    /// File checksum, encoded per the
    /// [multihash](https://github.com/multiformats/multihash) spec.
    public var checksum: String? {
        get { get(Self.checksumProp)?.stringValue }
        nonmutating set { set(Self.checksumProp, newValue.map(JSONValue.string)); registerSchema(Self.schemaURI) }
    }
    public var headerSize: Int64? {
        get { get(Self.headerSizeProp)?.intValue }
        nonmutating set { set(Self.headerSizeProp, newValue.map(JSONValue.int)); registerSchema(Self.schemaURI) }
    }
    public var size: Int64? {
        get { get(Self.sizeProp)?.intValue }
        nonmutating set { set(Self.sizeProp, newValue.map(JSONValue.int)); registerSchema(Self.schemaURI) }
    }
    public var localPath: String? {
        get { get(Self.localPathProp)?.stringValue }
        nonmutating set { set(Self.localPathProp, newValue.map(JSONValue.string)); registerSchema(Self.schemaURI) }
    }
}
public extension Item { var file: FileExtension { FileExtension(self) } }
public extension Asset { var file: FileExtension { FileExtension(self) } }

// MARK: - Version

/// Version STAC extension. Mirrors `pystac.extensions.version`.
public struct VersionExtension: STACExtension, PropertiesExtensionAccessor {
    public static let schemaURI = "https://stac-extensions.github.io/version/v1.2.0/schema.json"
    public static let prefix = ""

    public let host: ExtensionHost
    public init(_ item: Item) { self.host = .item(item) }

    public static let versionProp = "version"
    public static let deprecatedProp = "deprecated"

    public var version: String? {
        get { get(Self.versionProp)?.stringValue }
        nonmutating set { set(Self.versionProp, newValue.map(JSONValue.string)); registerSchema(Self.schemaURI) }
    }
    public var deprecated: Bool? {
        get { get(Self.deprecatedProp)?.boolValue }
        nonmutating set { set(Self.deprecatedProp, newValue.map(JSONValue.bool)); registerSchema(Self.schemaURI) }
    }
}
public extension Item { var version: VersionExtension { VersionExtension(self) } }

// MARK: - Xarray Assets

/// xarray-assets STAC extension. Mirrors `pystac.extensions.xarray_assets`.
public struct XarrayAssetsExtension: STACExtension, PropertiesExtensionAccessor {
    public static let schemaURI = "https://stac-extensions.github.io/xarray-assets/v1.0.0/schema.json"
    public static let prefix = "xarray:"

    public let host: ExtensionHost
    public init(_ asset: Asset) { self.host = .asset(asset) }

    public static let openKwargsProp = prefix + "open_kwargs"
    public static let storageOptionsProp = prefix + "storage_options"

    public var openKwargs: [String: JSONValue]? {
        get {
            if case let .object(o)? = get(Self.openKwargsProp) { return o }
            return nil
        }
        nonmutating set { set(Self.openKwargsProp, newValue.map(JSONValue.object)); registerSchema(Self.schemaURI) }
    }
    public var storageOptions: [String: JSONValue]? {
        get {
            if case let .object(o)? = get(Self.storageOptionsProp) { return o }
            return nil
        }
        nonmutating set { set(Self.storageOptionsProp, newValue.map(JSONValue.object)); registerSchema(Self.schemaURI) }
    }
}
public extension Asset { var xarrayAssets: XarrayAssetsExtension { XarrayAssetsExtension(self) } }

// MARK: - Timestamps

/// Timestamps STAC extension. Mirrors `pystac.extensions.timestamps`.
public struct TimestampsExtension: STACExtension, PropertiesExtensionAccessor {
    public static let schemaURI = "https://stac-extensions.github.io/timestamps/v1.1.0/schema.json"
    public static let prefix = ""

    public let host: ExtensionHost
    public init(_ item: Item) { self.host = .item(item) }
    public init(_ asset: Asset) { self.host = .asset(asset) }

    public static let publishedProp = "published"
    public static let expiresProp = "expires"
    public static let unpublishedProp = "unpublished"

    public var published: Date? {
        get { get(Self.publishedProp)?.stringValue.flatMap(HREFUtils.stringToDate) }
        nonmutating set { set(Self.publishedProp, newValue.map { .string(HREFUtils.datetimeToString($0)) }); registerSchema(Self.schemaURI) }
    }
    public var expires: Date? {
        get { get(Self.expiresProp)?.stringValue.flatMap(HREFUtils.stringToDate) }
        nonmutating set { set(Self.expiresProp, newValue.map { .string(HREFUtils.datetimeToString($0)) }); registerSchema(Self.schemaURI) }
    }
    public var unpublished: Date? {
        get { get(Self.unpublishedProp)?.stringValue.flatMap(HREFUtils.stringToDate) }
        nonmutating set { set(Self.unpublishedProp, newValue.map { .string(HREFUtils.datetimeToString($0)) }); registerSchema(Self.schemaURI) }
    }
}
public extension Item { var timestamps: TimestampsExtension { TimestampsExtension(self) } }
public extension Asset { var timestamps: TimestampsExtension { TimestampsExtension(self) } }

// MARK: - Render

/// Render STAC extension. Mirrors `pystac.extensions.render`. Renders are
/// stored as an `[String: [String: JSONValue]]` map at the Item/Collection
/// level under the top-level `renders` key.
public struct RenderExtension: STACExtension, PropertiesExtensionAccessor {
    public static let schemaURIPattern = "https://stac-extensions.github.io/render/v{version}/schema.json"
    public static let schemaURI = "https://stac-extensions.github.io/render/v2.0.0/schema.json"
    public static let prefix = ""

    public let host: ExtensionHost
    public init(_ item: Item) { self.host = .item(item) }

    public static let rendersProp = "renders"

    public var renders: [String: [String: JSONValue]]? {
        get {
            guard case let .object(o)? = get(Self.rendersProp) else { return nil }
            var out: [String: [String: JSONValue]] = [:]
            for (k, v) in o { if case let .object(inner) = v { out[k] = inner } }
            return out
        }
        nonmutating set {
            if let value = newValue {
                var o: [String: JSONValue] = [:]
                for (k, v) in value { o[k] = .object(v) }
                set(Self.rendersProp, .object(o))
            } else {
                set(Self.rendersProp, nil)
            }
            registerSchema(Self.schemaURI)
        }
    }
}
public extension Item { var render: RenderExtension { RenderExtension(self) } }
