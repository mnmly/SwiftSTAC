import XCTest
@testable import SwiftSTAC

/// Tests covering `StacIO`, `fromFile`, `saveObject`, and link resolution
/// against vendored pystac catalog fixtures.
final class StacIOTests: XCTestCase {

    // MARK: - DefaultStacIO

    func test_defaultStacIO_readWrite_localText() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let dest = dir.appendingPathComponent("hello.txt").path
        let io = DefaultStacIO()
        try await io.writeText("hello world", to: dest)
        let text = try await io.readText(dest)
        XCTAssertEqual(text, "hello world")
    }

    func test_defaultStacIO_acceptsFileURLPrefix() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let path = dir.appendingPathComponent("x.txt").path
        let io = DefaultStacIO()
        try await io.writeText("hi", to: path)
        let text = try await io.readText("file://\(path)")
        XCTAssertEqual(text, "hi")
    }

    // MARK: - Catalog.fromFile dispatch

    func test_fromFile_catalogFixture() async throws {
        let url = try Fixtures.url("catalog/test-case-1-tree/catalog.json")
        let obj = try await Catalog.fromFile(url.path)
        guard let cat = obj as? Catalog else {
            XCTFail("Expected Catalog, got \(type(of: obj))")
            return
        }
        XCTAssertEqual(cat.id, "test")
        XCTAssertEqual(cat.getSelfHref(), url.path)
    }

    func test_fromFile_collection_dispatchesToCollection() async throws {
        let url = try Fixtures.url("collection/multi-extent.json")
        let obj = try await Catalog.fromFile(url.path)
        XCTAssertTrue(obj is Collection)
    }

    func test_fromFile_itemDispatchesToItem() async throws {
        let url = try Fixtures.url("item/sample-item.json")
        let obj = try await Catalog.fromFile(url.path)
        XCTAssertTrue(obj is Item)
    }

    // MARK: - Link resolution

    func test_resolveSTACObject_followsRelativeChildLink() async throws {
        let url = try Fixtures.url("catalog/test-case-1-tree/catalog.json")
        let cat = try await Catalog.fromFile(url.path) as! Catalog
        let childLink = try XCTUnwrap(cat.getLinks(rel: .child).first)
        let resolved = try await childLink.resolveSTACObject()
        XCTAssertTrue(resolved is Catalog)
        XCTAssertTrue((resolved as! Catalog).id.starts(with: "country-"))
    }

    func test_resolveSTACObject_cachesTarget() async throws {
        let url = try Fixtures.url("catalog/test-case-1-tree/catalog.json")
        let cat = try await Catalog.fromFile(url.path) as! Catalog
        let link = try XCTUnwrap(cat.getLinks(rel: .child).first)
        XCTAssertFalse(link.isResolved())
        _ = try await link.resolveSTACObject()
        XCTAssertTrue(link.isResolved())
    }

    // MARK: - Walk with resolution

    func test_walkResolving_fullTree() async throws {
        let url = try Fixtures.url("catalog/test-case-1-tree/catalog.json")
        let cat = try await Catalog.fromFile(url.path) as! Catalog
        let walked = try await cat.walkResolving()
        // Should include the root + 2 countries + 4 areas = 7 nodes minimum
        XCTAssertGreaterThanOrEqual(walked.count, 5)
        // Every walked node should have a resolved self href
        for (node, _, _) in walked {
            XCTAssertNotNil(node.getSelfHref(), "Resolved node \(node.id) missing self href")
        }
    }

    // MARK: - Save round-trip

    func test_saveObject_andReadBack_item() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let item = try Item(
            id: "x",
            geometry: nil, bbox: nil,
            datetime: Date(timeIntervalSince1970: 0),
            properties: [:],
            href: dir.appendingPathComponent("item.json").path
        )
        try await item.saveObject()

        let loaded = try await Item.fromFile(dir.appendingPathComponent("item.json").path)
        XCTAssertEqual(loaded.id, "x")
    }

    func test_saveObject_andReadBack_catalog() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let cat = Catalog(id: "c", description: "d", href: dir.appendingPathComponent("catalog.json").path)
        try await cat.saveObject()

        let loaded = try await Catalog.fromFile(dir.appendingPathComponent("catalog.json").path)
        XCTAssertEqual(loaded.id, "c")
        XCTAssertTrue(loaded is Catalog)
    }

    func test_saveObject_throwsWithoutSelfHrefOrDest() async throws {
        let item = try Item(id: "x", geometry: nil, bbox: nil, datetime: Date(timeIntervalSince1970: 0), properties: [:])
        do {
            try await item.saveObject()
            XCTFail("expected throw")
        } catch {
            // expected
        }
    }
}
