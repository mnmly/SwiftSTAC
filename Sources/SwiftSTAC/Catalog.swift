import Foundation

/// A STAC Catalog. Mirrors `pystac.catalog.Catalog`.
///
/// Catalog can contain children (other Catalogs / Collections) and Items via
/// links. In-memory tree operations (`addChild`, `getItems`, etc.) work on
/// links whose targets are already resolved STAC objects — filesystem
/// resolution lives in a later phase along with `StacIO`.
open class Catalog: STACObject {

    public var description: String
    public var title: String?
    public var catalogType: CatalogType
    public var extraFields: [String: JSONValue]

    /// Default filename used when laying the catalog out on disk.
    public static let defaultFileName = "catalog.json"

    public override class var stacObjectType: STACObjectType { .catalog }
    public override var linkAutoTitle: String? { title }

    /// `true` when this catalog is its own root. Avoids a strong reference
    /// cycle that would arise from storing `Link(rel: root, target: self)` in
    /// `links`. ``getRoot()`` returns `self` while this flag is set.
    private var rootIsSelf: Bool = true

    public required init(
        id: String,
        description: String,
        title: String? = nil,
        stacExtensions: [String] = [],
        extraFields: [String: JSONValue] = [:],
        href: String? = nil,
        catalogType: CatalogType = .absolutePublished
    ) {
        self.description = description
        self.title = title
        self.extraFields = extraFields
        self.catalogType = catalogType
        super.init(id: id, stacExtensions: stacExtensions, links: [])
        if let href { self.setSelfHref(href) }
    }

    // MARK: - Root override (cycle-safe)

    open override func getRoot() -> STACObject? {
        if rootIsSelf { return self }
        return super.getRoot()
    }

    open override func setRoot(_ root: STACObject?) {
        if root === self {
            // Reset to self-root: remove any root link and set the flag.
            removeLinks(rel: .root)
            rootIsSelf = true
            return
        }
        rootIsSelf = false
        super.setRoot(root)
    }

    /// `true` when the catalog should be saved with relative links.
    public var isRelative: Bool {
        catalogType == .relativePublished || catalogType == .selfContained
    }

    /// In-memory clone of this catalog (links cloned, not their targets).
    /// Subclasses override to clone their own fields. Mirrors
    /// `pystac.Catalog.clone`.
    open func clone() -> Catalog {
        let copy = Self(
            id: id,
            description: description,
            title: title,
            stacExtensions: stacExtensions,
            extraFields: extraFields,
            href: nil,
            catalogType: catalogType
        )
        if let selfHref = getSelfHref() { copy.setSelfHref(selfHref) }
        for link in links where link.rel != RelType.root.rawValue {
            copy.addLink(link.clone())
        }
        return copy
    }

    // MARK: - Children / Items

    /// Add a child Catalog or Collection. Throws if `child` is an Item.
    /// The child's root is set to this catalog's root (or to this catalog if
    /// it is the root). When `setParent` is true, the child's parent is set
    /// to self.
    @discardableResult
    public func addChild(_ child: STACObject, title: String? = nil, setParent: Bool = true) throws -> Link {
        if child is Item {
            throw STACError.generic("Cannot add item as child. Use addItem instead.")
        }
        child.setRoot(getRoot() ?? self)
        if setParent { child.setParent(self) }
        let link = Link.child(child, title: title)
        addLink(link)
        return link
    }

    @discardableResult
    public func addChildren(_ children: [STACObject]) throws -> [Link] {
        var out: [Link] = []
        for c in children { out.append(try addChild(c)) }
        return out
    }

    /// Add an Item. Throws if `item` is a Catalog/Collection.
    @discardableResult
    public func addItem(_ item: STACObject, title: String? = nil, setParent: Bool = true) throws -> Link {
        if item is Catalog {
            throw STACError.generic("Cannot add catalog as item. Use addChild instead.")
        }
        item.setRoot(getRoot() ?? self)
        if setParent { item.setParent(self) }
        let link = Link.item(item, title: title)
        addLink(link)
        return link
    }

    @discardableResult
    public func addItems(_ items: [STACObject]) throws -> [Link] {
        var out: [Link] = []
        for i in items { out.append(try addItem(i)) }
        return out
    }

    /// All child Catalog/Collection objects whose links are already resolved.
    public func getChildren() -> [STACObject] {
        getLinks(rel: .child).compactMap { resolvedTarget($0) }
    }

    /// All resolved Collection children.
    public func getCollections() -> [Collection] {
        getChildren().compactMap { $0 as? Collection }
    }

    /// Recursively walk children to collect every reachable Collection.
    public func getAllCollections() -> [Collection] {
        var out: [Collection] = getCollections()
        for child in getChildren() {
            if let cat = child as? Catalog {
                out.append(contentsOf: cat.getAllCollections())
            }
        }
        return out
    }

    /// All `child` links on this catalog.
    public func getChildLinks() -> [Link] { getLinks(rel: .child) }

    /// Resolved direct child whose id matches `id`. When `recursive` is true,
    /// walk the subtree.
    public func getChild(id: String, recursive: Bool = false) -> STACObject? {
        if let direct = getChildren().first(where: { $0.id == id }) { return direct }
        if !recursive { return nil }
        for child in getChildren() {
            if let cat = child as? Catalog, let found = cat.getChild(id: id, recursive: true) {
                return found
            }
        }
        return nil
    }

    /// All resolved Items linked from this catalog. When `recursive` is true,
    /// also walks children.
    public func getItems(ids: Set<String>? = nil, recursive: Bool = false) -> [Item] {
        var items: [Item] = getLinks(rel: .item).compactMap { resolvedTarget($0) as? Item }
        if recursive {
            for child in getChildren() {
                if let cat = child as? Catalog {
                    items.append(contentsOf: cat.getItems(ids: nil, recursive: true))
                }
            }
        }
        if let ids { items = items.filter { ids.contains($0.id) } }
        return items
    }

    /// All `item` links on this catalog.
    public func getItemLinks() -> [Link] { getLinks(rel: .item) }

    /// Convenience for the recursive variant in pystac.
    public func getAllItems() -> [Item] { getItems(recursive: true) }

    public func clearChildren() {
        for child in getChildren() {
            child.setParent(nil)
            child.setRoot(nil)
        }
        removeLinks(rel: .child)
    }

    public func removeChild(id: String) {
        var keep: [Link] = []
        for link in links {
            if link.rel != RelType.child.rawValue {
                keep.append(link)
                continue
            }
            if let child = resolvedTarget(link), child.id == id {
                child.setParent(nil)
                child.setRoot(nil)
            } else {
                keep.append(link)
            }
        }
        links = keep
    }

    public func clearItems() {
        for item in getItems() {
            item.setParent(nil)
            item.setRoot(nil)
        }
        removeLinks(rel: .item)
    }

    public func removeItem(id: String) {
        var keep: [Link] = []
        for link in links {
            if link.rel != RelType.item.rawValue {
                keep.append(link)
                continue
            }
            if let item = resolvedTarget(link) as? Item, item.id == id {
                item.setParent(nil)
                item.setRoot(nil)
            } else {
                keep.append(link)
            }
        }
        links = keep
    }

    // MARK: - Walk

    /// Tuple-style walk yielding `(catalog, children, items)` for every node
    /// in the subtree. Mirrors `pystac.Catalog.walk`.
    public func walk() -> [(catalog: Catalog, children: [STACObject], items: [Item])] {
        var out: [(Catalog, [STACObject], [Item])] = []
        let children = getChildren()
        out.append((self, children, getItems()))
        for child in children {
            if let cat = child as? Catalog {
                out.append(contentsOf: cat.walk())
            }
        }
        return out
    }

    // MARK: - Asset href propagation (Collection overrides to also touch its own assets)

    public func makeAllAssetHrefsRelative() throws {
        for item in getItems(recursive: true) {
            try item.makeAssetHrefsRelative()
        }
        for coll in getAllCollections() {
            try coll.makeAssetHrefsRelative()
        }
    }

    public func makeAllAssetHrefsAbsolute() throws {
        for item in getItems(recursive: true) {
            try item.makeAssetHrefsAbsolute()
        }
        for coll in getAllCollections() {
            try coll.makeAssetHrefsAbsolute()
        }
    }

    // MARK: - Dict round-trip

    /// Encode this catalog to a JSON-shaped dictionary. The `type` key is
    /// title-cased (`Catalog` / `Collection`).
    open func toDict(includeSelfLink: Bool = true) throws -> [String: JSONValue] {
        var outLinks = links
        if !includeSelfLink {
            outLinks.removeAll { $0.rel == RelType.`self`.rawValue }
        }

        // Synthesize a root link when self-root.
        if rootIsSelf, !outLinks.contains(where: { $0.rel == RelType.root.rawValue }) {
            let href = getSelfHref()
            let rootLink = Link(
                rel: RelType.root.rawValue,
                target: href ?? "",
                mediaType: MediaType.json.rawValue
            )
            outLinks.insert(rootLink, at: 0)
        }

        let enc = JSONEncoder()
        enc.outputFormatting = [.withoutEscapingSlashes]
        let dec = JSONDecoder()

        var linksJSON: [JSONValue] = []
        for link in outLinks {
            // Skip resolved root link with no href (matches pystac filter)
            if link.rel == RelType.root.rawValue && link.getHref() == nil { continue }
            let data = try enc.encode(link)
            linksJSON.append(try dec.decode(JSONValue.self, from: data))
        }

        var d: [String: JSONValue] = [
            "type": .string(Self.stacObjectType.rawValue),
            "id": .string(id),
            "stac_version": .string(STACVersion.getSTACVersion()),
            "description": .string(description),
            "links": .array(linksJSON),
        ]
        if !stacExtensions.isEmpty {
            d["stac_extensions"] = .array(stacExtensions.map(JSONValue.string))
        }
        for (k, v) in extraFields { d[k] = v }
        if let title { d["title"] = .string(title) }
        return d
    }

    public class func fromDict(_ d: [String: JSONValue]) throws -> Catalog {
        guard case let .string(t)? = d["type"] else {
            throw STACError.typeMismatch(id: d["id"]?.stringValue, expected: "Catalog", extra: "'type' missing")
        }
        guard t == STACObjectType.catalog.rawValue else {
            throw STACError.typeMismatch(id: d["id"]?.stringValue, expected: "Catalog", extra: "'type' is \(t)")
        }
        return try Catalog.fromDictInternal(d)
    }

    /// Subclass hook so Collection can re-use the parsing prelude.
    class func fromDictInternal(_ d: [String: JSONValue]) throws -> Catalog {
        guard case let .string(id)? = d["id"] else {
            throw STACError.typeMismatch(id: nil, expected: "Catalog", extra: "'id' missing")
        }
        guard case let .string(desc)? = d["description"] else {
            throw STACError.requiredPropertyMissing(object: "Catalog(\(id))", property: "description")
        }
        let title = d["title"]?.stringValue
        var stacExtensions: [String] = []
        if case let .array(arr)? = d["stac_extensions"] {
            stacExtensions = arr.compactMap { $0.stringValue }
        }
        let catalogType = CatalogType.determine(from: d) ?? .absolutePublished

        let excluded: Set<String> = ["type", "id", "stac_version", "stac_extensions", "description", "title", "links"]
        var extras: [String: JSONValue] = [:]
        for (k, v) in d where !excluded.contains(k) { extras[k] = v }

        let cat = Self.init(
            id: id,
            description: desc,
            title: title,
            stacExtensions: stacExtensions,
            extraFields: extras,
            href: nil,
            catalogType: catalogType
        )

        if case let .array(linksArr)? = d["links"] {
            let enc = JSONEncoder()
            let dec = JSONDecoder()
            for linkVal in linksArr {
                let data = try enc.encode(linkVal)
                let link = try dec.decode(Link.self, from: data)
                cat.addLink(link)
            }
        }
        return cat
    }

    // MARK: - Helpers

    /// Return the link's already-resolved STAC object target, or `nil` when
    /// the link still points at a string href.
    func resolvedTarget(_ link: Link) -> STACObject? {
        if case let .object(o) = try? link.getTarget() { return o }
        return nil
    }
}

// MARK: - JSON convenience
// Catalog/Collection do not conform to Codable directly because their
// hierarchical link graph makes default Codable behavior surprising. Use
// `toDict()` / `fromDict(_:)` to round-trip through JSON.

extension Catalog {
    /// Convenience: encode as JSON `Data` with stable, lossless output.
    public func toJSONData(includeSelfLink: Bool = true) throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.withoutEscapingSlashes]
        let dict = try toDict(includeSelfLink: includeSelfLink)
        return try enc.encode(JSONValue.object(dict))
    }

    /// Convenience: decode from JSON `Data`.
    public static func fromJSONData(_ data: Data) throws -> Catalog {
        let value = try JSONDecoder().decode(JSONValue.self, from: data)
        guard case let .object(d) = value else {
            throw STACError.generic("Expected a JSON object at the top level")
        }
        if case let .string(t)? = d["type"], t == STACObjectType.collection.rawValue {
            return try Collection.parse(d)
        }
        return try Catalog.fromDict(d)
    }
}
