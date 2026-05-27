import XCTest
@testable import SwiftSTAC

/// Coverage for the second-wave catalog methods (`clone`, `mapItems`,
/// `mapAssets`, `describe`, `normalizeHrefs`, `normalizeAndSave`,
/// `targetInHierarchy`, `Item.getCollection`/`derivedFrom`).
final class GapFillerTests: XCTestCase {

    private func makeItem(_ id: String) throws -> Item {
        try Item(id: id, geometry: nil, bbox: nil, datetime: Date(timeIntervalSince1970: 0), properties: [:])
    }

    private func makeExtent() -> Extent {
        Extent(
            spatial: SpatialExtent(bboxes: [[-180, -90, 180, 90]]),
            temporal: TemporalExtent(intervals: [[nil, nil]])
        )
    }

    // MARK: - clone()

    func test_catalog_clone() {
        let cat = Catalog(id: "c", description: "d", title: "T")
        let copy = cat.clone()
        XCTAssertFalse(copy === cat)
        XCTAssertEqual(copy.id, cat.id)
        XCTAssertEqual(copy.description, cat.description)
        XCTAssertEqual(copy.title, cat.title)
    }

    func test_collection_clone() {
        let coll = Collection(id: "c", description: "d", extent: makeExtent(), license: "MIT", keywords: ["a"])
        coll.addAsset(key: "data", asset: Asset(href: "./x.tif"))
        let copy = coll.clone() as! Collection
        XCTAssertEqual(copy.id, "c")
        XCTAssertEqual(copy.license, "MIT")
        XCTAssertEqual(copy.keywords, ["a"])
        XCTAssertEqual(copy.assets.count, 1)
        // Asset is independently cloned
        XCTAssertFalse(copy.assets["data"]! === coll.assets["data"]!)
    }

    // MARK: - mapItems

    func test_mapItems_replacesItems() throws {
        let cat = Catalog(id: "c", description: "d")
        let i1 = try makeItem("i1")
        let i2 = try makeItem("i2")
        try cat.addItems([i1, i2])
        let mapped = try cat.mapItems { item in
            item.properties["touched"] = .bool(true)
            return item
        }
        let mappedIDs = mapped.getItems().map(\.id).sorted()
        XCTAssertEqual(mappedIDs, ["i1", "i2"])
        for item in mapped.getItems() {
            XCTAssertEqual(item.properties["touched"], .bool(true))
        }
    }

    func test_mapItems_oneToMany_expands() throws {
        let cat = Catalog(id: "c", description: "d")
        try cat.addItems([try makeItem("i1")])
        let mapped = try cat.mapItems { item -> [Item] in
            let a = try Item(id: "\(item.id)-a", geometry: nil, bbox: nil, datetime: Date(timeIntervalSince1970: 0), properties: [:])
            let b = try Item(id: "\(item.id)-b", geometry: nil, bbox: nil, datetime: Date(timeIntervalSince1970: 0), properties: [:])
            return [a, b]
        }
        XCTAssertEqual(mapped.getItems().map(\.id).sorted(), ["i1-a", "i1-b"])
    }

    // MARK: - mapAssets

    func test_mapAssets_rewritesAssets() throws {
        let cat = Catalog(id: "c", description: "d")
        let item = try makeItem("i1")
        item.addAsset(key: "data", asset: Asset(href: "./old.tif", mediaType: "image/tiff"))
        try cat.addItem(item)
        let mapped = try cat.mapAssets { key, asset in
            let renamed = asset.clone()
            renamed.href = "./new.tif"
            return [key: renamed]
        }
        let mappedItem = mapped.getItems().first!
        XCTAssertEqual(mappedItem.assets["data"]?.href, "./new.tif")
    }

    // MARK: - describe()

    func test_describe_capturesTree() throws {
        let cat = Catalog(id: "root", description: "d")
        let child = Catalog(id: "child", description: "d")
        try cat.addChild(child)
        try cat.addItem(try makeItem("item-1"))

        var lines: [String] = []
        cat.describe { lines.append($0) }
        XCTAssertTrue(lines.contains { $0.contains("id=root") })
        XCTAssertTrue(lines.contains { $0.contains("id=child") })
        XCTAssertTrue(lines.contains { $0.contains("id=item-1") })
    }

    // MARK: - target_in_hierarchy

    func test_targetInHierarchy_findsDescendant() throws {
        let root = Catalog(id: "root", description: "d")
        let c1 = Catalog(id: "c1", description: "d")
        let item = try makeItem("i1")
        try root.addChild(c1)
        try c1.addItem(item)
        XCTAssertTrue(root.targetInHierarchy(item))
        XCTAssertTrue(root.targetInHierarchy(c1))
        let unrelated = try makeItem("orphan")
        XCTAssertFalse(root.targetInHierarchy(unrelated))
    }

    // MARK: - Item.getCollection / derivedFrom

    func test_item_getCollection_followsResolvedLink() throws {
        let coll = Collection(id: "c1", description: "d", extent: makeExtent())
        let item = try makeItem("i1")
        try coll.addItem(item)
        XCTAssertTrue(item.getCollection() === coll)
    }

    func test_item_derivedFrom_addReadRemove() throws {
        let src1 = try makeItem("src1")
        let src2 = try makeItem("src2")
        let item = try makeItem("derived")
        item.addDerivedFrom([src1, src2])

        XCTAssertEqual(item.getDerivedFrom().map(\.id), ["src1", "src2"])

        item.removeDerivedFrom(itemID: "src1")
        XCTAssertEqual(item.getDerivedFrom().map(\.id), ["src2"])
    }

    // MARK: - Collection.updateExtentFromItems

    func test_collection_updateExtentFromItems() throws {
        let coll = Collection(id: "c", description: "d", extent: makeExtent())
        let i1 = try Item(id: "1", geometry: nil, bbox: [0, 0, 1, 1], datetime: Date(timeIntervalSince1970: 0), properties: [:])
        let i2 = try Item(id: "2", geometry: nil, bbox: [-1, -1, 2, 2], datetime: Date(timeIntervalSince1970: 100), properties: [:])
        try coll.addItems([i1, i2])
        coll.updateExtentFromItems()
        XCTAssertEqual(coll.extent.spatial.bboxes[0], [-1, -1, 2, 2])
    }

    // MARK: - BestPracticesLayoutStrategy

    func test_layout_bestPractices_paths() {
        let strategy = BestPracticesLayoutStrategy()
        let cat = Catalog(id: "root", description: "d")
        let child = Catalog(id: "child", description: "d")
        XCTAssertEqual(strategy.getCatalogHref(cat, parentDir: "/data", isRoot: true), "/data/catalog.json")
        XCTAssertEqual(strategy.getCatalogHref(child, parentDir: "/data", isRoot: false), "/data/child/catalog.json")
        let item = try! Item(id: "i1", geometry: nil, bbox: nil, datetime: Date(timeIntervalSince1970: 0), properties: [:])
        XCTAssertEqual(strategy.getItemHref(item, parentDir: "/data"), "/data/i1/i1.json")
    }

    // MARK: - normalize + save end-to-end

    func test_normalizeAndSave_roundTripsTree() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let root = Catalog(id: "root", description: "d", catalogType: .selfContained)
        let coll = Collection(id: "c1", description: "d", extent: makeExtent())
        let item = try makeItem("i1")
        try root.addChild(coll)
        try coll.addItem(item)

        try await root.normalizeAndSave(rootHref: dir.path)

        // Each file should exist where the strategy says it should
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("catalog.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("c1/collection.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("c1/i1/i1.json").path))

        // Read root back and confirm shape
        let reloaded = try await Catalog.fromFile(dir.appendingPathComponent("catalog.json").path)
        XCTAssertEqual(reloaded.id, "root")
    }
}
