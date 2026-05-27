import Foundation

/// SAR (Synthetic Aperture Radar) STAC extension. Mirrors
/// `pystac.extensions.sar`.
public enum SARFrequencyBand: String, Sendable, Codable {
    case P, L, S, C, X, Ku, K, Ka
}

public enum SARObservationDirection: String, Sendable, Codable {
    case left, right
}

public struct SARExtension: STACExtension, PropertiesExtensionAccessor {
    public static let schemaURI = "https://stac-extensions.github.io/sar/v1.0.0/schema.json"
    public static let prefix = "sar:"

    public let host: ExtensionHost
    public init(_ item: Item) { self.host = .item(item) }
    public init(_ asset: Asset) { self.host = .asset(asset) }

    public static let instrumentModeProp = prefix + "instrument_mode"
    public static let frequencyBandProp = prefix + "frequency_band"
    public static let polarizationsProp = prefix + "polarizations"
    public static let productTypeProp = prefix + "product_type"
    public static let centerFrequencyProp = prefix + "center_frequency"
    public static let resolutionRangeProp = prefix + "resolution_range"
    public static let resolutionAzimuthProp = prefix + "resolution_azimuth"
    public static let pixelSpacingRangeProp = prefix + "pixel_spacing_range"
    public static let pixelSpacingAzimuthProp = prefix + "pixel_spacing_azimuth"
    public static let looksRangeProp = prefix + "looks_range"
    public static let looksAzimuthProp = prefix + "looks_azimuth"
    public static let looksEquivalentNumberProp = prefix + "looks_equivalent_number"
    public static let observationDirectionProp = prefix + "observation_direction"

    public var instrumentMode: String? {
        get { get(Self.instrumentModeProp)?.stringValue }
        nonmutating set { set(Self.instrumentModeProp, newValue.map(JSONValue.string)); registerSchema(Self.schemaURI) }
    }
    public var frequencyBand: SARFrequencyBand? {
        get { get(Self.frequencyBandProp)?.stringValue.flatMap(SARFrequencyBand.init(rawValue:)) }
        nonmutating set { set(Self.frequencyBandProp, newValue.map { .string($0.rawValue) }); registerSchema(Self.schemaURI) }
    }
    public var polarizations: [String]? {
        get {
            guard case let .array(arr)? = get(Self.polarizationsProp) else { return nil }
            return arr.compactMap { $0.stringValue }
        }
        nonmutating set {
            set(Self.polarizationsProp, newValue.map { .array($0.map(JSONValue.string)) })
            registerSchema(Self.schemaURI)
        }
    }
    public var productType: String? {
        get { get(Self.productTypeProp)?.stringValue }
        nonmutating set { set(Self.productTypeProp, newValue.map(JSONValue.string)); registerSchema(Self.schemaURI) }
    }
    public var centerFrequency: Double? {
        get { get(Self.centerFrequencyProp)?.doubleValue }
        nonmutating set { set(Self.centerFrequencyProp, newValue.map(JSONValue.double)); registerSchema(Self.schemaURI) }
    }
    public var resolutionRange: Double? {
        get { get(Self.resolutionRangeProp)?.doubleValue }
        nonmutating set { set(Self.resolutionRangeProp, newValue.map(JSONValue.double)); registerSchema(Self.schemaURI) }
    }
    public var resolutionAzimuth: Double? {
        get { get(Self.resolutionAzimuthProp)?.doubleValue }
        nonmutating set { set(Self.resolutionAzimuthProp, newValue.map(JSONValue.double)); registerSchema(Self.schemaURI) }
    }
    public var pixelSpacingRange: Double? {
        get { get(Self.pixelSpacingRangeProp)?.doubleValue }
        nonmutating set { set(Self.pixelSpacingRangeProp, newValue.map(JSONValue.double)); registerSchema(Self.schemaURI) }
    }
    public var pixelSpacingAzimuth: Double? {
        get { get(Self.pixelSpacingAzimuthProp)?.doubleValue }
        nonmutating set { set(Self.pixelSpacingAzimuthProp, newValue.map(JSONValue.double)); registerSchema(Self.schemaURI) }
    }
    public var looksRange: Int? {
        get { get(Self.looksRangeProp)?.intValue.map(Int.init) }
        nonmutating set { set(Self.looksRangeProp, newValue.map { .int(Int64($0)) }); registerSchema(Self.schemaURI) }
    }
    public var looksAzimuth: Int? {
        get { get(Self.looksAzimuthProp)?.intValue.map(Int.init) }
        nonmutating set { set(Self.looksAzimuthProp, newValue.map { .int(Int64($0)) }); registerSchema(Self.schemaURI) }
    }
    public var looksEquivalentNumber: Double? {
        get { get(Self.looksEquivalentNumberProp)?.doubleValue }
        nonmutating set { set(Self.looksEquivalentNumberProp, newValue.map(JSONValue.double)); registerSchema(Self.schemaURI) }
    }
    public var observationDirection: SARObservationDirection? {
        get { get(Self.observationDirectionProp)?.stringValue.flatMap(SARObservationDirection.init(rawValue:)) }
        nonmutating set { set(Self.observationDirectionProp, newValue.map { .string($0.rawValue) }); registerSchema(Self.schemaURI) }
    }
}
public extension Item { var sar: SARExtension { SARExtension(self) } }
public extension Asset { var sar: SARExtension { SARExtension(self) } }
