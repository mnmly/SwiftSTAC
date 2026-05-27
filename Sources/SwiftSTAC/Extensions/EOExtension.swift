import Foundation

/// Electro-Optical (EO) STAC extension.
///
/// Mirrors `pystac.extensions.eo`. Add bands, cloud cover, snow cover to
/// Items, Assets, or Collection-level Item Asset Definitions.
public struct EOExtension: STACExtension, PropertiesExtensionAccessor {

    public static let schemaURI = "https://stac-extensions.github.io/eo/v1.1.0/schema.json"
    public static let schemaURIs: [String] = [
        "https://stac-extensions.github.io/eo/v1.0.0/schema.json",
        schemaURI,
    ]
    public static let prefix = "eo:"

    public let host: ExtensionHost

    public init(_ item: Item) { self.host = .item(item) }
    public init(_ asset: Asset) { self.host = .asset(asset) }

    // MARK: - Fields

    public static let bandsProp = prefix + "bands"
    public static let cloudCoverProp = prefix + "cloud_cover"
    public static let snowCoverProp = prefix + "snow_cover"

    public var bands: [EOBand]? {
        get {
            guard case let .array(arr)? = get(Self.bandsProp) else { return nil }
            return arr.compactMap { v in
                if case let .object(o) = v { return EOBand(properties: o) }
                return nil
            }
        }
        nonmutating set {
            if let bands = newValue {
                set(Self.bandsProp, .array(bands.map { .object($0.properties) }))
            } else {
                set(Self.bandsProp, nil)
            }
            registerSchema(Self.schemaURI)
        }
    }

    public var cloudCover: Double? {
        get { get(Self.cloudCoverProp)?.doubleValue }
        nonmutating set {
            set(Self.cloudCoverProp, newValue.map(JSONValue.double))
            registerSchema(Self.schemaURI)
        }
    }

    public var snowCover: Double? {
        get { get(Self.snowCoverProp)?.doubleValue }
        nonmutating set {
            set(Self.snowCoverProp, newValue.map(JSONValue.double))
            registerSchema(Self.schemaURI)
        }
    }

    /// Apply the common EO fields at once. Pass `nil` for any field to leave
    /// it untouched.
    public func apply(bands: [EOBand]? = nil, cloudCover: Double? = nil, snowCover: Double? = nil) {
        if let bands { self.bands = bands }
        if let cloudCover { self.cloudCover = cloudCover }
        if let snowCover { self.snowCover = snowCover }
    }
}

/// One spectral band in an EO asset / item. Mirrors `pystac.extensions.eo.Band`.
public struct EOBand: Sendable, Equatable, Hashable {

    public var properties: [String: JSONValue]

    public init(properties: [String: JSONValue]) { self.properties = properties }

    public init(
        name: String,
        commonName: String? = nil,
        description: String? = nil,
        centerWavelength: Double? = nil,
        fullWidthHalfMax: Double? = nil,
        solarIllumination: Double? = nil
    ) {
        var p: [String: JSONValue] = ["name": .string(name)]
        if let commonName { p["common_name"] = .string(commonName) }
        if let description { p["description"] = .string(description) }
        if let centerWavelength { p["center_wavelength"] = .double(centerWavelength) }
        if let fullWidthHalfMax { p["full_width_half_max"] = .double(fullWidthHalfMax) }
        if let solarIllumination { p["solar_illumination"] = .double(solarIllumination) }
        self.properties = p
    }

    public var name: String? {
        get { properties["name"]?.stringValue }
        set { setOrRemove("name", newValue.map(JSONValue.string)) }
    }
    public var commonName: String? {
        get { properties["common_name"]?.stringValue }
        set { setOrRemove("common_name", newValue.map(JSONValue.string)) }
    }
    public var bandDescription: String? {
        get { properties["description"]?.stringValue }
        set { setOrRemove("description", newValue.map(JSONValue.string)) }
    }
    public var centerWavelength: Double? {
        get { properties["center_wavelength"]?.doubleValue }
        set { setOrRemove("center_wavelength", newValue.map(JSONValue.double)) }
    }
    public var fullWidthHalfMax: Double? {
        get { properties["full_width_half_max"]?.doubleValue }
        set { setOrRemove("full_width_half_max", newValue.map(JSONValue.double)) }
    }
    public var solarIllumination: Double? {
        get { properties["solar_illumination"]?.doubleValue }
        set { setOrRemove("solar_illumination", newValue.map(JSONValue.double)) }
    }

    private mutating func setOrRemove(_ key: String, _ value: JSONValue?) {
        if let value { properties[key] = value }
        else { properties.removeValue(forKey: key) }
    }
}

// MARK: - Sugar accessors

public extension Item {
    /// EO extension accessor.
    var eo: EOExtension { EOExtension(self) }
}

public extension Asset {
    /// EO extension accessor.
    var eo: EOExtension { EOExtension(self) }
}
