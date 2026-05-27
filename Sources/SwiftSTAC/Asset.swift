import Foundation

/// An object that contains a link to data associated with an Item or Collection
/// that can be downloaded or streamed.
///
/// Mirrors `pystac.asset.Asset`. The owning Item/Collection back-reference is
/// modeled via the ``owner`` weak reference — set automatically by
/// ``AssetOwner/addAsset(key:asset:)`` / Item / Collection construction.
public final class Asset: @unchecked Sendable {

    /// Link to the asset object. Relative and absolute hrefs are both allowed.
    public var href: String

    /// Optional displayed title.
    public var title: String?

    /// A description of the asset, CommonMark allowed.
    public var assetDescription: String?

    /// Optional media type. Use ``MediaType`` raw values where possible.
    public var mediaType: String?

    /// Optional semantic roles (`thumbnail`, `overview`, `data`, `metadata`).
    public var roles: [String]?

    /// Additional top-level fields (extension data) preserved verbatim.
    public var extraFields: [String: JSONValue]

    /// Back-reference to the owning Item or Collection. Not Codable.
    public weak var owner: (any AssetOwner)?

    public init(
        href: String,
        title: String? = nil,
        description: String? = nil,
        mediaType: String? = nil,
        roles: [String]? = nil,
        extraFields: [String: JSONValue] = [:]
    ) {
        self.href = HREFUtils.makePosixStyle(href)
        self.title = title
        self.assetDescription = description
        self.mediaType = mediaType
        self.roles = roles
        self.extraFields = extraFields
        self.owner = nil
    }

    /// True iff the asset's role list contains `role`.
    public func hasRole(_ role: String) -> Bool {
        roles?.contains(role) ?? false
    }

    /// Resolve the asset's absolute href against the owner's self href, if
    /// available. Returns `nil` if the asset href is relative and no anchor
    /// can be derived.
    public func getAbsoluteHref() -> String? {
        let anchor = owner?.getSelfHref()
        if HREFUtils.isAbsolute(href, startHref: anchor) {
            return href
        }
        guard let anchor else { return nil }
        return HREFUtils.makeAbsolute(href, startHref: anchor)
    }

    /// Make a shallow clone. Owner is intentionally not carried over so that
    /// callers can re-parent the clone.
    public func clone() -> Asset {
        let c = Asset(
            href: href,
            title: title,
            description: assetDescription,
            mediaType: mediaType,
            roles: roles,
            extraFields: extraFields
        )
        return c
    }
}

// MARK: - Equatable / Hashable

extension Asset: Equatable {
    public static func == (lhs: Asset, rhs: Asset) -> Bool {
        lhs.href == rhs.href
            && lhs.title == rhs.title
            && lhs.assetDescription == rhs.assetDescription
            && lhs.mediaType == rhs.mediaType
            && lhs.roles == rhs.roles
            && lhs.extraFields == rhs.extraFields
    }
}

// MARK: - Codable

extension Asset: Codable {
    private static let knownKeys: Set<String> = ["href", "type", "title", "description", "roles"]

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: JSONCodingKey.self)
        guard let hrefKey = JSONCodingKey(stringValue: "href"),
              let href = try? c.decode(String.self, forKey: hrefKey) else {
            throw STACError.requiredPropertyMissing(object: "Asset", property: "href")
        }
        let mediaType = try c.decodeIfPresent(String.self, forKey: JSONCodingKey(stringValue: "type")!)
        let title = try c.decodeIfPresent(String.self, forKey: JSONCodingKey(stringValue: "title")!)
        let description = try c.decodeIfPresent(String.self, forKey: JSONCodingKey(stringValue: "description")!)
        let roles = try c.decodeIfPresent([String].self, forKey: JSONCodingKey(stringValue: "roles")!)

        var extras: [String: JSONValue] = [:]
        for key in c.allKeys where !Asset.knownKeys.contains(key.stringValue) {
            extras[key.stringValue] = try c.decode(JSONValue.self, forKey: key)
        }

        self.init(
            href: href,
            title: title,
            description: description,
            mediaType: mediaType,
            roles: roles,
            extraFields: extras
        )
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: JSONCodingKey.self)
        try c.encode(href, forKey: JSONCodingKey(stringValue: "href")!)
        try c.encodeIfPresent(mediaType, forKey: JSONCodingKey(stringValue: "type")!)
        try c.encodeIfPresent(title, forKey: JSONCodingKey(stringValue: "title")!)
        try c.encodeIfPresent(assetDescription, forKey: JSONCodingKey(stringValue: "description")!)
        // Match pystac's emission order: href, type, title, description, extras…, roles
        for (k, v) in extraFields {
            try c.encode(v, forKey: JSONCodingKey(stringValue: k)!)
        }
        try c.encodeIfPresent(roles, forKey: JSONCodingKey(stringValue: "roles")!)
    }
}

// MARK: - AssetOwner protocol (parallels pystac's `Assets` Protocol)

/// A STAC object that owns a collection of ``Asset`` values (Item / Collection).
public protocol AssetOwner: AnyObject {
    /// Self href used to resolve relative asset hrefs.
    func getSelfHref() -> String?

    /// The owner's assets keyed by asset key.
    var assets: [String: Asset] { get set }
}

extension AssetOwner {
    /// Get assets filtered by media type and/or role. Returns copies (clones).
    public func getAssets(mediaType: String? = nil, role: String? = nil) -> [String: Asset] {
        var out: [String: Asset] = [:]
        for (k, a) in assets {
            if let mediaType, a.mediaType != mediaType { continue }
            if let role, !a.hasRole(role) { continue }
            out[k] = a.clone()
        }
        return out
    }

    /// Add an asset and set its owner back-reference.
    public func addAsset(key: String, asset: Asset) {
        asset.owner = self
        assets[key] = asset
    }

    /// Rewrite all asset hrefs to be relative to the owner's self href.
    /// Throws if any asset is absolute and there is no self href to anchor on.
    public func makeAssetHrefsRelative() throws {
        let selfHref = getSelfHref()
        for asset in assets.values {
            if HREFUtils.isAbsolute(asset.href, startHref: selfHref) {
                guard let selfHref else {
                    throw STACError.generic("Cannot make asset HREFs relative if no self_href is set.")
                }
                asset.href = HREFUtils.makeRelative(asset.href, startHref: selfHref)
            }
        }
    }

    /// Rewrite all relative asset hrefs to absolute, anchored on the owner's
    /// self href. Throws if there is no self href to anchor on.
    public func makeAssetHrefsAbsolute() throws {
        let selfHref = getSelfHref()
        for asset in assets.values {
            if !HREFUtils.isAbsolute(asset.href, startHref: selfHref) {
                guard let selfHref else {
                    throw STACError.generic("Cannot make relative asset HREFs absolute if no self_href is set.")
                }
                asset.href = HREFUtils.makeAbsolute(asset.href, startHref: selfHref)
            }
        }
    }
}
