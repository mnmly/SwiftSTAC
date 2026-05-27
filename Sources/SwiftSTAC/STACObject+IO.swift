import Foundation

extension STACObject {
    /// Save this object as JSON to `destHref` (or its self href when `nil`).
    public func saveObject(
        includeSelfLink: Bool = true,
        destHref: String? = nil,
        stacIO: any StacIO = DefaultStacIO()
    ) async throws {
        let dest: String
        if let destHref {
            dest = destHref
        } else if let self_ = getSelfHref() {
            dest = self_
        } else {
            throw STACError.generic("Self HREF must be set before saving without an explicit dest_href.")
        }
        let dict: [String: JSONValue]
        switch self {
        case let item as Item:
            dict = try item.toDict(includeSelfLink: includeSelfLink)
        case let collection as Collection:
            dict = try collection.toDict(includeSelfLink: includeSelfLink)
        case let catalog as Catalog:
            dict = try catalog.toDict(includeSelfLink: includeSelfLink)
        default:
            throw STACError.generic("Cannot serialize unknown STACObject subclass: \(type(of: self))")
        }
        try await stacIO.saveJSON(dict, to: dest)
    }
}

extension Catalog {
    /// Load a STAC document at `href`. Returns Catalog, Collection, or Item
    /// depending on the document's `type`. Sets the self href to `href`.
    public static func fromFile(
        _ href: String,
        stacIO: any StacIO = DefaultStacIO()
    ) async throws -> STACObject {
        let absolute = HREFUtils.isAbsolute(href) ? href : HREFUtils.makeAbsolute(href)
        return try await stacIO.readSTACObject(absolute)
    }
}

extension Item {
    /// Load an Item at `href`.
    public static func fromFile(
        _ href: String,
        stacIO: any StacIO = DefaultStacIO()
    ) async throws -> Item {
        let abs = HREFUtils.isAbsolute(href) ? href : HREFUtils.makeAbsolute(href)
        let obj = try await stacIO.readSTACObject(abs)
        guard let item = obj as? Item else {
            throw STACError.typeMismatch(id: obj.id, expected: "Item", extra: nil)
        }
        return item
    }
}

extension Collection {
    /// Load a Collection at `href`.
    public static func fromCollectionFile(
        _ href: String,
        stacIO: any StacIO = DefaultStacIO()
    ) async throws -> Collection {
        let abs = HREFUtils.isAbsolute(href) ? href : HREFUtils.makeAbsolute(href)
        let obj = try await stacIO.readSTACObject(abs)
        guard let coll = obj as? Collection else {
            throw STACError.typeMismatch(id: obj.id, expected: "Collection", extra: nil)
        }
        return coll
    }
}

extension Link {
    /// Resolve this link's target to a concrete STACObject, mirroring
    /// `pystac.Link.resolve_stac_object`.
    @discardableResult
    public func resolveSTACObject(
        root: Catalog? = nil,
        stacIO: (any StacIO)? = nil
    ) async throws -> STACObject {
        if case let .object(o) = try? getTarget() { return o }
        guard let href = getTargetString() else {
            throw STACError.generic("Cannot resolve STAC object without a target.")
        }
        let resolvedHref: String
        if HREFUtils.isAbsolute(href) {
            resolvedHref = href
        } else if let owner = owner, let anchor = owner.getSelfHref() {
            resolvedHref = HREFUtils.makeAbsolute(href, startHref: anchor)
        } else if root != nil {
            resolvedHref = href
        } else {
            throw STACError.generic("Relative href '\(href)' encountered without owner or root.")
        }
        let io = stacIO ?? DefaultStacIO()
        let obj: STACObject
        do {
            obj = try await io.readSTACObject(resolvedHref, root: root)
        } catch {
            throw STACError.generic("HREF: '\(resolvedHref)' does not resolve to a STAC object")
        }
        setTarget(object: obj)
        return obj
    }
}

// MARK: - Catalog walking (with resolution)

extension Catalog {
    /// Walk the catalog tree, resolving child & item links via `stacIO` as we
    /// go. Returns `(catalog, children, items)` tuples like ``walk()``.
    public func walkResolving(
        stacIO: any StacIO = DefaultStacIO()
    ) async throws -> [(catalog: Catalog, children: [STACObject], items: [Item])] {
        var out: [(Catalog, [STACObject], [Item])] = []
        let resolved = try await resolveChildrenAndItems(stacIO: stacIO)
        out.append((self, resolved.children, resolved.items))
        for child in resolved.children {
            if let cat = child as? Catalog {
                out.append(contentsOf: try await cat.walkResolving(stacIO: stacIO))
            }
        }
        return out
    }

    /// Resolve every child and item link on this catalog (single level).
    @discardableResult
    public func resolveChildrenAndItems(
        stacIO: any StacIO = DefaultStacIO()
    ) async throws -> (children: [STACObject], items: [Item]) {
        var children: [STACObject] = []
        var items: [Item] = []
        let root = getRoot() as? Catalog
        for link in getLinks(rel: .child) {
            let obj = try await link.resolveSTACObject(root: root, stacIO: stacIO)
            children.append(obj)
        }
        for link in getLinks(rel: .item) {
            let obj = try await link.resolveSTACObject(root: root, stacIO: stacIO)
            if let item = obj as? Item { items.append(item) }
        }
        return (children, items)
    }
}
