import Foundation

extension STACObject {
    /// `true` if `target` is reachable through hierarchical (`child`, `item`,
    /// …) links starting from this object. Mirrors
    /// `pystac.stac_object.STACObject.target_in_hierarchy`.
    public func targetInHierarchy(_ target: STACObject) -> Bool {
        var visited = Set<ObjectIdentifier>()
        return traverse(from: self, target: target, visited: &visited)
    }

    private func traverse(from obj: STACObject, target: STACObject, visited: inout Set<ObjectIdentifier>) -> Bool {
        if obj === target { return true }
        visited.insert(ObjectIdentifier(obj))
        for link in obj.links where link.isHierarchical() {
            guard case let .object(t) = try? link.getTarget() else { continue }
            if visited.contains(ObjectIdentifier(t)) { continue }
            if traverse(from: t, target: target, visited: &visited) { return true }
        }
        return false
    }
}

extension Catalog {

    /// Force-resolve every link reachable from this catalog. After this, every
    /// child/item link points at an in-memory STAC object.
    /// Mirrors `pystac.Catalog.fully_resolve`.
    public func fullyResolve(stacIO: any StacIO = DefaultStacIO()) async throws {
        _ = try await walkResolving(stacIO: stacIO)
    }

    /// Apply `mapper` to every resolved item in the catalog tree. Returns a
    /// new catalog; the original is unmodified. Mirrors `pystac.Catalog.map_items`.
    public func mapItems(_ mapper: (Item) throws -> [Item]) throws -> Catalog {
        let newCat = clone()
        try mapCatalogItems(newCat, mapper: mapper)
        return newCat
    }

    /// Convenience overload for the common 1-to-1 case.
    public func mapItems(_ mapper: (Item) throws -> Item) throws -> Catalog {
        try mapItems { try [mapper($0)] }
    }

    /// Apply `mapper` to every asset of every item. Returns a new catalog.
    /// Mirrors `pystac.Catalog.map_assets`.
    public func mapAssets(_ mapper: (String, Asset) throws -> [String: Asset]) throws -> Catalog {
        try mapItems { item in
            var newAssets: [String: Asset] = [:]
            for (k, a) in item.assets {
                let mapped = try mapper(k, a)
                for (mk, ma) in mapped { newAssets[mk] = ma }
            }
            item.assets = [:]
            for (k, a) in newAssets { item.addAsset(key: k, asset: a) }
            return item
        }
    }

    private func mapCatalogItems(_ catalog: Catalog, mapper: (Item) throws -> [Item]) throws {
        for child in catalog.getChildren() {
            if let cat = child as? Catalog { try mapCatalogItems(cat, mapper: mapper) }
        }

        var newItemLinks: [Link] = []
        for itemLink in catalog.getItemLinks() {
            guard case let .object(target) = try? itemLink.getTarget(),
                  let item = target as? Item
            else { continue }
            let mapped = try mapper(item)
            if mapped.count == 1 {
                itemLink.setTarget(object: mapped[0])
                newItemLinks.append(itemLink)
            } else {
                for m in mapped {
                    let newLink = itemLink.clone()
                    newLink.setTarget(object: m)
                    newItemLinks.append(newLink)
                }
            }
        }
        catalog.clearItems()
        catalog.addLinks(newItemLinks)
    }

    /// Print a human-readable summary of this catalog tree to `output`.
    /// Mirrors `pystac.Catalog.describe`.
    public func describe(includeHrefs: Bool = false, indent: Int = 0, output: (String) -> Void = { print($0) }) {
        let pad = String(repeating: " ", count: indent)
        var line = "\(pad)* \(repr)"
        if includeHrefs, let href = getSelfHref() { line += " \(href)" }
        output(line)
        for child in getChildren() {
            if let cat = child as? Catalog {
                cat.describe(includeHrefs: includeHrefs, indent: indent + 4, output: output)
            }
        }
        for item in getItems() {
            var iline = "\(String(repeating: " ", count: indent + 2))* \(item.repr)"
            if includeHrefs, let href = item.getSelfHref() { iline += " \(href)" }
            output(iline)
        }
    }

    // MARK: - normalize_hrefs / save

    /// Rewrite the self HREFs of every reachable STAC object using the given
    /// layout strategy, anchored at `rootHref`. Mirrors
    /// `pystac.Catalog.normalize_hrefs`.
    public func normalizeHrefs(
        rootHref: String,
        strategy: any HrefLayoutStrategy = BestPracticesLayoutStrategy(),
        stacIO: any StacIO = DefaultStacIO(),
        resolveAll: Bool = true
    ) async throws {
        if resolveAll { try await fullyResolve(stacIO: stacIO) }
        try normalize(parentDir: rootHref, isRoot: true, strategy: strategy)
    }

    private func normalize(parentDir: String, isRoot: Bool, strategy: any HrefLayoutStrategy) throws {
        let href = strategy.getHref(self, parentDir: parentDir, isRoot: isRoot)
        setSelfHref(href)
        let myDir = HREFUtils.parentDir(href)
        for child in getChildren() {
            if let cat = child as? Catalog {
                try cat.normalize(parentDir: myDir, isRoot: false, strategy: strategy)
            }
        }
        for item in getItems() {
            let itemHref = strategy.getItemHref(item, parentDir: myDir)
            item.setSelfHrefKeepingAssetHrefs(itemHref)
        }
    }

    /// Save this catalog and every resolved child / item to disk using each
    /// object's self HREF. Mirrors `pystac.Catalog.save`.
    public func save(
        catalogType: CatalogType? = nil,
        stacIO: any StacIO = DefaultStacIO(),
        includeSelfLink: Bool? = nil
    ) async throws {
        let actualType = catalogType ?? self.catalogType
        let includeSelf: Bool = {
            if let includeSelfLink { return includeSelfLink }
            return actualType == .absolutePublished || actualType == .relativePublished
        }()
        try await saveObject(includeSelfLink: includeSelf, stacIO: stacIO)
        for child in getChildren() {
            if let cat = child as? Catalog {
                try await cat.save(catalogType: actualType, stacIO: stacIO, includeSelfLink: includeSelf)
            }
        }
        for item in getItems() {
            try await item.saveObject(includeSelfLink: includeSelf, stacIO: stacIO)
        }
    }

    /// Convenience: normalize + save in one call. Mirrors
    /// `pystac.Catalog.normalize_and_save`.
    public func normalizeAndSave(
        rootHref: String,
        catalogType: CatalogType? = nil,
        strategy: any HrefLayoutStrategy = BestPracticesLayoutStrategy(),
        stacIO: any StacIO = DefaultStacIO()
    ) async throws {
        try await normalizeHrefs(rootHref: rootHref, strategy: strategy, stacIO: stacIO, resolveAll: false)
        try await save(catalogType: catalogType, stacIO: stacIO)
    }
}

extension Collection {

    /// Recompute the extent from this collection's reachable items.
    /// Mirrors `pystac.Collection.update_extent_from_items`.
    public func updateExtentFromItems() {
        self.extent = Extent.fromItems(getItems(recursive: true))
    }
}

extension Item {

    /// Resolved Collection back-reference, when there is a `collection` link
    /// whose target has already been resolved. Mirrors
    /// `pystac.Item.get_collection`.
    public func getCollection() -> Collection? {
        if let collection { return collection }
        guard let link = getSingleLink(rel: .collection) else { return nil }
        if case let .object(o) = try? link.getTarget(), let coll = o as? Collection {
            self.collection = coll
            return coll
        }
        return nil
    }

    /// Add one or more `derived_from` links. Mirrors
    /// `pystac.Item.add_derived_from`.
    @discardableResult
    public func addDerivedFrom(_ items: [Item]) -> Item {
        for item in items { addLink(Link.derivedFrom(item)) }
        return self
    }

    /// Add `derived_from` links by raw href.
    @discardableResult
    public func addDerivedFrom(hrefs: [String]) -> Item {
        for h in hrefs {
            addLink(Link(rel: RelType.derivedFrom.rawValue, target: h, mediaType: MediaType.json.rawValue))
        }
        return self
    }

    /// All `derived_from` links that have already been resolved to Items.
    public func getDerivedFrom() -> [Item] {
        getLinks(rel: .derivedFrom).compactMap { link in
            if case let .object(o) = try? link.getTarget() { return o as? Item }
            return nil
        }
    }

    /// Remove every `derived_from` link whose resolved target item has the
    /// given id.
    public func removeDerivedFrom(itemID: String) {
        var keep: [Link] = []
        for link in links {
            if link.rel != RelType.derivedFrom.rawValue { keep.append(link); continue }
            if case let .object(o) = try? link.getTarget(), let it = o as? Item, it.id == itemID {
                continue
            }
            keep.append(link)
        }
        links = keep
    }
}
