import Foundation

/// Information about a provider of STAC data. A provider is any organization
/// that captured or processed the content of a collection and therefore
/// influenced the data being offered.
///
/// Mirrors `pystac.provider.Provider`. Unknown JSON keys are preserved in
/// ``extraFields`` so round-tripping is lossless.
public struct Provider: Sendable, Equatable, Hashable {
    /// Organization or individual name.
    public var name: String

    /// Optional multi-line description with provider details.
    public var description: String?

    /// Optional provider roles (`licensor`, `producer`, `processor`, `host`).
    public var roles: [ProviderRole]?

    /// Optional homepage URL.
    public var url: String?

    /// Additional top-level fields preserved from JSON.
    public var extraFields: [String: JSONValue]

    public init(
        name: String,
        description: String? = nil,
        roles: [ProviderRole]? = nil,
        url: String? = nil,
        extraFields: [String: JSONValue] = [:]
    ) {
        self.name = name
        self.description = description
        self.roles = roles
        self.url = url
        self.extraFields = extraFields
    }
}

// MARK: - Codable

extension Provider: Codable {
    private static let knownKeys: Set<String> = ["name", "description", "roles", "url"]

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: JSONCodingKey.self)
        guard let nameKey = JSONCodingKey(stringValue: "name"),
              let name = try? c.decode(String.self, forKey: nameKey) else {
            throw STACError.requiredPropertyMissing(object: "Provider", property: "name")
        }
        self.name = name
        self.description = try c.decodeIfPresent(String.self, forKey: JSONCodingKey(stringValue: "description")!)
        self.roles = try c.decodeIfPresent([ProviderRole].self, forKey: JSONCodingKey(stringValue: "roles")!)
        self.url = try c.decodeIfPresent(String.self, forKey: JSONCodingKey(stringValue: "url")!)

        var extras: [String: JSONValue] = [:]
        for key in c.allKeys where !Provider.knownKeys.contains(key.stringValue) {
            extras[key.stringValue] = try c.decode(JSONValue.self, forKey: key)
        }
        self.extraFields = extras
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: JSONCodingKey.self)
        try c.encode(name, forKey: JSONCodingKey(stringValue: "name")!)
        try c.encodeIfPresent(description, forKey: JSONCodingKey(stringValue: "description")!)
        try c.encodeIfPresent(roles, forKey: JSONCodingKey(stringValue: "roles")!)
        try c.encodeIfPresent(url, forKey: JSONCodingKey(stringValue: "url")!)
        for (k, v) in extraFields {
            try c.encode(v, forKey: JSONCodingKey(stringValue: k)!)
        }
    }
}

/// Dynamic CodingKey used for objects whose key set is open-ended.
struct JSONCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    init?(stringValue: String) { self.stringValue = stringValue; self.intValue = nil }
    init?(intValue: Int) { self.stringValue = String(intValue); self.intValue = intValue }
}
