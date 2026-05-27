import XCTest
@testable import SwiftSTAC

/// Tests ported from `pystac/tests/test_catalog.py`. Recursive walking that
/// requires StacIO (resolving link hrefs to objects) is deferred to phase 3 —
/// these tests focus on the in-memory tree, dict round-trip, and link graph.
final class CatalogTests: XCTestCase {

    // MARK: - Construction

    func test_catalog_construct_defaults() {
        let cat = Catalog(id: "c", description: "desc")
        XCTAssertEqual(cat.id, "c")
        XCTAssertEqual(cat.description, "desc")
        XCTAssertNil(cat.title)
        XCTAssertEqual(cat.catalogType, .absolutePublished)
        // Self-rooting: getRoot returns self without a link in the array
        XCTAssertTrue(cat.getRoot() === cat)
        XCTAssertFalse(cat.links.contains(where: { $0.rel == "root" }))
    }

    func test_catalog_construct_withHref_setsSelfLink() {
        let cat = Catalog(id: "c", description: "desc", href: "/x/catalog.json")
        XCTAssertEqual(cat.getSelfHref(), "/x/catalog.json")
    }

    // MARK: - addChild / addItem semantics (pystac test_catalog)

    func test_addChild_setsRootAndParent() throws {
        let root = Catalog(id: "root", description: "root")
        let child = Catalog(id: "c1", description: "c1")
        try root.addChild(child)
        XCTAssertTrue(child.getParent() === root)
        XCTAssertTrue(child.getRoot() === root)
        XCTAssertEqual(root.getChildLinks().count, 1)
    }

    func test_addChild_throwsForItem() throws {
        let root = Catalog(id: "root", description: "root")
        let item = try Item(id: "i", geometry: nil, bbox: nil, datetime: Date(timeIntervalSince1970: 0), properties: [:])
        XCTAssertThrowsError(try root.addChild(item))
    }

    func test_addItem_throwsForCatalog() throws {
        let root = Catalog(id: "root", description: "root")
        let child = Catalog(id: "c1", description: "c1")
        XCTAssertThrowsError(try root.addItem(child))
    }

    func test_addItem_setsParentAndRoot() throws {
        let root = Catalog(id: "root", description: "root")
        let item = try Item(id: "i", geometry: nil, bbox: nil, datetime: Date(timeIntervalSince1970: 0), properties: [:])
        try root.addItem(item)
        XCTAssertTrue(item.getParent() === root)
        XCTAssertTrue(item.getRoot() === root)
        XCTAssertEqual(root.getItemLinks().count, 1)
    }

    // MARK: - getChild / getItems

    func test_getChild_byId_directOnly() throws {
        let root = Catalog(id: "root", description: "root")
        let c1 = Catalog(id: "c1", description: "c1")
        let c2 = Catalog(id: "c2", description: "c2")
        try root.addChildren([c1, c2])
        XCTAssertTrue(root.getChild(id: "c1") === c1)
        XCTAssertTrue(root.getChild(id: "c2") === c2)
        XCTAssertNil(root.getChild(id: "missing"))
    }

    func test_getChild_recursive() throws {
        let root = Catalog(id: "root", description: "root")
        let c1 = Catalog(id: "c1", description: "c1")
        let nested = Catalog(id: "deep", description: "deep")
        try root.addChild(c1)
        try c1.addChild(nested)
        XCTAssertNil(root.getChild(id: "deep"))
        XCTAssertTrue(root.getChild(id: "deep", recursive: true) === nested)
    }

    func test_getItems_recursive() throws {
        let root = Catalog(id: "root", description: "root")
        let c1 = Catalog(id: "c1", description: "c1")
        try root.addChild(c1)
        let i1 = try Item(id: "i1", geometry: nil, bbox: nil, datetime: Date(timeIntervalSince1970: 0), properties: [:])
        let i2 = try Item(id: "i2", geometry: nil, bbox: nil, datetime: Date(timeIntervalSince1970: 0), properties: [:])
        try c1.addItem(i1)
        try root.addItem(i2)
        XCTAssertEqual(root.getItems().map(\.id).sorted(), ["i2"])
        XCTAssertEqual(root.getItems(recursive: true).map(\.id).sorted(), ["i1", "i2"])
    }

    // MARK: - clearChildren / removeChild / removeItem

    func test_clearChildren_resetsParentAndRoot() throws {
        let root = Catalog(id: "root", description: "root")
        let c1 = Catalog(id: "c1", description: "c1")
        try root.addChild(c1)
        root.clearChildren()
        XCTAssertNil(c1.getParent())
        XCTAssertEqual(root.getChildLinks().count, 0)
    }

    func test_removeChild_byId() throws {
        let root = Catalog(id: "root", description: "root")
        let c1 = Catalog(id: "c1", description: "c1")
        let c2 = Catalog(id: "c2", description: "c2")
        try root.addChildren([c1, c2])
        root.removeChild(id: "c1")
        XCTAssertEqual(root.getChildren().map(\.id), ["c2"])
        XCTAssertNil(c1.getParent())
    }

    func test_removeItem_byId() throws {
        let root = Catalog(id: "root", description: "root")
        let i1 = try Item(id: "i1", geometry: nil, bbox: nil, datetime: Date(timeIntervalSince1970: 0), properties: [:])
        let i2 = try Item(id: "i2", geometry: nil, bbox: nil, datetime: Date(timeIntervalSince1970: 0), properties: [:])
        try root.addItems([i1, i2])
        root.removeItem(id: "i1")
        XCTAssertEqual(root.getItems().map(\.id), ["i2"])
    }

    // MARK: - Dict round-trip

    func test_toDict_includesRequiredKeys() throws {
        let cat = Catalog(id: "c", description: "desc", title: "T", href: "/x/cat.json")
        let d = try cat.toDict()
        XCTAssertEqual(d["type"], .string("Catalog"))
        XCTAssertEqual(d["id"], .string("c"))
        XCTAssertEqual(d["description"], .string("desc"))
        XCTAssertEqual(d["title"], .string("T"))
        XCTAssertNotNil(d["links"])
        XCTAssertEqual(d["stac_version"]?.stringValue, STACVersion.getSTACVersion())
        // synthesized root link present, points at self href
        if case let .array(links)? = d["links"] {
            let root = links.first(where: { $0["rel"] == .string("root") })
            XCTAssertNotNil(root)
            XCTAssertEqual(root?["href"], .string("/x/cat.json"))
        } else { XCTFail("links not array") }
    }

    func test_fromDict_parsesCatalogFixture() throws {
        let dict = try Fixtures.jsonDict("catalog/test-case-1.json")
        let cat = try Catalog.fromDict(dict)
        XCTAssertEqual(cat.id, "test")
        XCTAssertEqual(cat.description, "test catalog")
        XCTAssertEqual(cat.getChildLinks().count, 2)
    }

    // MARK: - removeHierarchicalLinks parity

    func test_removeHierarchicalLinks() throws {
        let cat = Catalog(id: "c", description: "desc", href: "/x/cat.json")
        try cat.addChild(Catalog(id: "c1", description: "c1"))
        cat.addLink(Link(rel: "alternate", target: "alt.json"))
        let removed = cat.removeHierarchicalLinks(addCanonical: true)
        XCTAssertGreaterThan(removed.count, 0)
        XCTAssertEqual(cat.getLinks(rel: "child").count, 0)
        XCTAssertEqual(cat.getLinks(rel: "canonical").count, 1)
        XCTAssertEqual(cat.getLinks(rel: "alternate").count, 1)
    }
}
