import Foundation

/// Base class for Catalog, Collection, and Item. Mirrors
/// `pystac.stac_object.STACObject`.
///
/// Subclasses must:
/// - assign ``id``, ``stacExtensions``, and (optionally) build initial ``links``
/// - override ``stacObjectType``
/// - override ``linkAutoTitle`` to expose their title for resolved-target links
///
/// The base class implements link-graph helpers (`add_link`, `get_links`,
/// `get_root`, `set_self_href`, …) so subclasses inherit them.
open class STACObject: @unchecked Sendable {

    /// Short human-readable form used by ``Catalog/describe(includeHrefs:indent:output:)``
    /// and debugging tools. Mirrors `pystac`'s `__repr__`. Not named
    /// `description` to avoid clashing with the STAC `description` field on
    /// Catalog/Collection.
    open var repr: String {
        "<\(String(describing: type(of: self))) id=\(id)>"
    }

    /// Stable identifier within a STAC.
    public var id: String

    /// Schema URIs for STAC Extensions implemented by this object.
    public var stacExtensions: [String]

    /// All links attached to this object.
    public var links: [Link]

    /// Subclass-defined discriminator. Override.
    open class var stacObjectType: STACObjectType {
        fatalError("Subclasses must override stacObjectType")
    }

    /// Auto-title returned to a resolved-target ``Link`` (Catalog/Collection
    /// override; Item returns `nil`).
    open var linkAutoTitle: String? { nil }

    public init(id: String, stacExtensions: [String] = [], links: [Link] = []) {
        self.id = id
        self.stacExtensions = stacExtensions
        self.links = links
        for link in links { link.setOwner(self) }
    }

    // MARK: - Link management

    /// Add a link and set its owner to this object.
    public func addLink(_ link: Link) {
        link.setOwner(self)
        links.append(link)
    }

    /// Add several links.
    public func addLinks(_ links: [Link]) {
        for link in links { addLink(link) }
    }

    /// Remove every link with the given rel.
    public func removeLinks(rel: String) {
        links.removeAll { $0.rel == rel }
    }

    public func removeLinks(rel: RelType) {
        removeLinks(rel: rel.rawValue)
    }

    /// Clear all links, or those matching the given rel.
    public func clearLinks(rel: String? = nil) {
        if let rel {
            links.removeAll { $0.rel == rel }
        } else {
            links.removeAll()
        }
    }

    /// Remove all hierarchical links. If `addCanonical` is true and a self
    /// href is set, a canonical link is added pointing at the self href.
    /// Returns the removed links.
    @discardableResult
    public func removeHierarchicalLinks(addCanonical: Bool = false) -> [Link] {
        var keep: [Link] = []
        var removed: [Link] = []
        if addCanonical, let selfHref = getSelfHref() {
            keep.append(Link(rel: RelType.canonical.rawValue, target: selfHref, mediaType: MediaType.geojson.rawValue))
        }
        for link in links {
            if link.isHierarchical() {
                removed.append(link)
            } else {
                keep.append(link)
            }
        }
        // Re-establish owner on the canonical link if we added one.
        for link in keep where link.owner !== self { link.setOwner(self) }
        self.links = keep
        return removed
    }

    /// Get the first link, optionally filtered by rel and/or media type.
    public func getSingleLink(rel: String? = nil, mediaType: [String?]? = nil) -> Link? {
        if rel == nil && mediaType == nil { return links.first }
        return links.first { link in
            if let rel, link.rel != rel { return false }
            if let mediaType, !mediaType.contains(link.mediaType) { return false }
            return true
        }
    }

    public func getSingleLink(rel: RelType) -> Link? {
        getSingleLink(rel: rel.rawValue)
    }

    /// Get all links matching the given filters.
    public func getLinks(rel: String? = nil, mediaType: [String?]? = nil) -> [Link] {
        if rel == nil && mediaType == nil { return links }
        return links.filter { link in
            if let rel, link.rel != rel { return false }
            if let mediaType, !mediaType.contains(link.mediaType) { return false }
            return true
        }
    }

    public func getLinks(rel: RelType) -> [Link] {
        getLinks(rel: rel.rawValue)
    }

    // MARK: - Self / root / parent

    /// Get the root link, if any.
    public func getRootLink() -> Link? {
        getSingleLink(
            rel: RelType.root.rawValue,
            mediaType: MediaType.stacJSON.map { $0?.rawValue }
        )
    }

    /// Get the absolute self HREF for this object.
    public func getSelfHref() -> String? {
        guard let selfLink = getSingleLink(rel: .`self`),
              selfLink.hasTargetHref()
        else { return nil }
        return selfLink.getTargetString()
    }

    /// Set the absolute self HREF (or clear with nil).
    public func setSelfHref(_ href: String?) {
        removeLinks(rel: .`self`)
        if let href {
            addLink(Link.selfHref(href))
        }
    }

    /// Get the root catalog by following the root link. Does not currently
    /// auto-resolve string targets — pystac's `resolve_stac_object` belongs to
    /// a later phase (StacIO).
    public func getRoot() -> STACObject? {
        guard let rootLink = getRootLink(), rootLink.isResolved() else { return nil }
        if case let .object(o) = try? rootLink.getTarget() { return o }
        return nil
    }

    /// Set the root object (or clear).
    public func setRoot(_ root: STACObject?) {
        let existing = links.firstIndex { $0.rel == RelType.root.rawValue }
        if let root {
            let newLink = Link.root(root)
            newLink.setOwner(self)
            if let idx = existing {
                links[idx] = newLink
            } else {
                links.append(newLink)
            }
        } else {
            removeLinks(rel: .root)
        }
    }

    /// Get the parent object (only if the parent link is already resolved).
    public func getParent() -> STACObject? {
        guard let link = getSingleLink(rel: .parent), link.isResolved() else { return nil }
        if case let .object(o) = try? link.getTarget() { return o }
        return nil
    }

    /// Set the parent object (or clear).
    public func setParent(_ parent: STACObject?) {
        removeLinks(rel: .parent)
        if let parent {
            addLink(Link.parent(parent))
        }
    }
}
