import Foundation

/// A link connects a ``STACObject`` to another entity. The target can be
/// either another ``STACObject`` or an opaque HREF.
///
/// Mirrors `pystac.link.Link`. Lazily resolved: a Link constructed with a
/// string target stays unresolved until a caller swaps the target for a
/// real object (or until a future `StacIO` reader does it).
public final class Link {

    /// Relation between owner and target (e.g. `child`, `item`, custom rel).
    public var rel: String

    /// Optional media type for the linked resource.
    public var mediaType: String?

    /// Stored explicit title. When `nil`, ``title`` falls back to the target
    /// object's auto-title (matching pystac's getter behavior).
    public var explicitTitle: String?

    /// Optional, additional fields preserved as-is (extension data).
    public var extraFields: [String: JSONValue]

    /// Owner of this link — the STACObject whose `links` array contains it.
    /// pystac uses this as the anchor for href transformation. Weak to avoid
    /// retain cycles.
    public weak var owner: STACObject?

    private var targetHref: String?
    private var targetObject: STACObject?

    // MARK: - Init

    /// Create a link with an opaque HREF target.
    public init(
        rel: String,
        target href: String,
        mediaType: String? = nil,
        title: String? = nil,
        extraFields: [String: JSONValue] = [:]
    ) {
        self.rel = rel
        if rel == RelType.`self`.rawValue {
            // Mirror pystac: SELF link hrefs are forced absolute against CWD.
            self.targetHref = HREFUtils.makeAbsolute(href)
        } else {
            self.targetHref = HREFUtils.makePosixStyle(href)
        }
        self.targetObject = nil
        self.mediaType = mediaType
        self.explicitTitle = title
        self.extraFields = extraFields
    }

    /// Create a link whose target is another STAC object.
    public init(
        rel: String,
        target object: STACObject,
        mediaType: String? = nil,
        title: String? = nil,
        extraFields: [String: JSONValue] = [:]
    ) {
        self.rel = rel
        self.targetHref = nil
        self.targetObject = object
        self.mediaType = mediaType
        self.explicitTitle = title
        self.extraFields = extraFields
    }

    // MARK: - Title

    /// Optional title for this link. If not set explicitly, returns the
    /// resolved target's auto-title (Catalog/Collection title), else `nil`.
    public var title: String? {
        get {
            if let explicitTitle { return explicitTitle }
            if let targetObject { return targetObject.linkAutoTitle }
            return nil
        }
        set { explicitTitle = newValue }
    }

    // MARK: - Target

    /// The link target: either a resolved STAC object or a plain HREF string.
    public enum Target {
        case href(String)
        case object(STACObject)
    }

    /// Current target. Throws if neither href nor object is set.
    public func getTarget() throws -> Target {
        if let targetObject { return .object(targetObject) }
        if let targetHref { return .href(targetHref) }
        throw STACError.generic("No target defined for link.")
    }

    /// Replace the target with an HREF.
    public func setTarget(href: String) {
        self.targetHref = HREFUtils.makePosixStyle(href)
        self.targetObject = nil
    }

    /// Replace the target with a resolved STAC object.
    public func setTarget(object: STACObject) {
        self.targetHref = nil
        self.targetObject = object
    }

    /// Returns the target as a string — the stored href if any, else the
    /// resolved object's self href, else `nil`.
    public func getTargetString() -> String? {
        if let targetHref { return targetHref }
        return targetObject?.getSelfHref()
    }

    /// `true` if the target is a resolved STACObject (not just an HREF).
    public func isResolved() -> Bool {
        targetObject != nil
    }

    /// `true` if this link has any explicit HREF set on it.
    public func hasTargetHref() -> Bool {
        targetHref != nil
    }

    // MARK: - HREF

    /// Get the (possibly nil) href representing this link.
    public func getHref() -> String? {
        if let targetObject {
            return targetObject.getSelfHref()
        }
        return targetHref
    }

    /// Get an absolute href for this link, anchored on the owner's self href
    /// if the link href is relative.
    public func getAbsoluteHref() -> String? {
        var href = getHref()
        if let h = href, let ownerSelf = owner?.getSelfHref() {
            href = HREFUtils.makeAbsolute(h, startHref: ownerSelf)
        }
        return href
    }

    // MARK: - Misc

    /// `true` if the rel type is hierarchical (root/child/parent/collection/item/items).
    public func isHierarchical() -> Bool {
        guard let rt = RelType(rawValue: rel) else { return false }
        return RelType.hierarchical.contains(rt)
    }

    /// Set the owning STAC object. Returns self for chaining.
    @discardableResult
    public func setOwner(_ owner: STACObject?) -> Link {
        self.owner = owner
        return self
    }

    /// Clone the link. Does not deep-copy a STACObject target — clones share
    /// the target reference, matching pystac semantics.
    public func clone() -> Link {
        switch (targetObject, targetHref) {
        case let (obj?, _):
            return Link(rel: rel, target: obj, mediaType: mediaType, title: explicitTitle, extraFields: extraFields)
        case let (_, href?):
            return Link(rel: rel, target: href, mediaType: mediaType, title: explicitTitle, extraFields: extraFields)
        default:
            return Link(rel: rel, target: "", mediaType: mediaType, title: explicitTitle, extraFields: extraFields)
        }
    }

    // MARK: - Static factories
    // pystac defines these on Link directly; we keep parity but accept any
    // STACObject conformer.

    public static func root(_ c: STACObject) -> Link {
        Link(rel: RelType.root.rawValue, target: c, mediaType: MediaType.json.rawValue)
    }

    public static func parent(_ c: STACObject) -> Link {
        Link(rel: RelType.parent.rawValue, target: c, mediaType: MediaType.json.rawValue)
    }

    public static func collection(_ c: STACObject) -> Link {
        Link(rel: RelType.collection.rawValue, target: c, mediaType: MediaType.json.rawValue)
    }

    public static func selfHref(_ href: String) -> Link {
        Link(rel: RelType.`self`.rawValue, target: href, mediaType: MediaType.json.rawValue)
    }

    public static func child(_ c: STACObject, title: String? = nil) -> Link {
        Link(rel: RelType.child.rawValue, target: c, mediaType: MediaType.json.rawValue, title: title)
    }

    public static func item(_ item: STACObject, title: String? = nil) -> Link {
        Link(rel: RelType.item.rawValue, target: item, mediaType: MediaType.geojson.rawValue, title: title)
    }

    public static func derivedFrom(_ item: STACObject, title: String? = nil) -> Link {
        Link(rel: RelType.derivedFrom.rawValue, target: item, mediaType: MediaType.json.rawValue, title: title)
    }

    public static func canonical(_ obj: STACObject, title: String? = nil) -> Link {
        Link(rel: RelType.canonical.rawValue, target: obj, mediaType: MediaType.json.rawValue, title: title)
    }
}

// MARK: - CustomStringConvertible

extension Link: CustomStringConvertible {
    public var description: String {
        let targetDesc: String
        switch (targetObject, targetHref) {
        case let (obj?, _): targetDesc = "\(obj)"
        case let (_, href?): targetDesc = href
        default: targetDesc = "<none>"
        }
        return "<Link rel=\(rel) target=\(targetDesc)>"
    }
}

// MARK: - Codable

extension Link: Codable {
    private static let knownKeys: Set<String> = ["rel", "href", "type", "title"]

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: JSONCodingKey.self)
        let relKey = JSONCodingKey(stringValue: "rel")!
        let hrefKey = JSONCodingKey(stringValue: "href")!

        guard let rel = try? c.decode(String.self, forKey: relKey) else {
            throw STACError.requiredPropertyMissing(object: "Link", property: "rel")
        }
        guard c.contains(hrefKey) else {
            throw STACError.requiredPropertyMissing(object: "Link", property: "href")
        }
        // href may be the JSON null
        let href = try c.decodeIfPresent(String.self, forKey: hrefKey) ?? ""
        let mediaType = try c.decodeIfPresent(String.self, forKey: JSONCodingKey(stringValue: "type")!)
        let title = try c.decodeIfPresent(String.self, forKey: JSONCodingKey(stringValue: "title")!)

        var extras: [String: JSONValue] = [:]
        for key in c.allKeys where !Link.knownKeys.contains(key.stringValue) {
            extras[key.stringValue] = try c.decode(JSONValue.self, forKey: key)
        }
        self.init(rel: rel, target: href, mediaType: mediaType, title: title, extraFields: extras)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: JSONCodingKey.self)
        try c.encode(rel, forKey: JSONCodingKey(stringValue: "rel")!)

        // Always emit `href`, even when nil — pystac writes `"href": null`
        // for unresolved object targets.
        let hrefKey = JSONCodingKey(stringValue: "href")!
        if let h = getHref() {
            try c.encode(h, forKey: hrefKey)
        } else {
            try c.encodeNil(forKey: hrefKey)
        }

        try c.encodeIfPresent(mediaType, forKey: JSONCodingKey(stringValue: "type")!)
        try c.encodeIfPresent(title, forKey: JSONCodingKey(stringValue: "title")!)
        for (k, v) in extraFields {
            try c.encode(v, forKey: JSONCodingKey(stringValue: k)!)
        }
    }
}
