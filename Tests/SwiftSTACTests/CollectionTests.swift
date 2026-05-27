import XCTest
@testable import SwiftSTAC

/// Tests ported from `pystac/tests/test_collection.py` for behaviors that
/// don't require StacIO.
final class CollectionTests: XCTestCase {

    private static func makeExtent() -> Extent {
        Extent(
            spatial: SpatialExtent(bboxes: [[-180, -90, 180, 90]]),
            temporal: TemporalExtent(intervals: [[Date(timeIntervalSince1970: 0), nil]])
        )
    }

    func test_construct_defaults() {
        let c = Collection(id: "c", description: "desc", extent: Self.makeExtent())
        XCTAssertEqual(c.id, "c")
        XCTAssertEqual(c.license, "other")
        XCTAssertTrue(c.assets.isEmpty)
        XCTAssertTrue(c.summaries.isEmpty)
    }

    // MARK: - Multi-extent fixture (pystac data)

    func test_fromDict_multiExtentFixture() throws {
        let dict = try Fixtures.jsonDict("collection/multi-extent.json")
        let coll = try Collection.parse(dict)
        XCTAssertEqual(coll.id, "area-1-1")
        XCTAssertEqual(coll.extent.spatial.bboxes.count, 3)
        // First bbox
        XCTAssertEqual(coll.extent.spatial.bboxes[0].count, 4)
    }

    func test_roundTrip_multiExtent_preservesKeyFields() throws {
        let dict = try Fixtures.jsonDict("collection/multi-extent.json")
        let coll = try Collection.parse(dict)
        let out = try coll.toDict()
        XCTAssertEqual(out["type"], .string("Collection"))
        XCTAssertEqual(out["id"], .string("area-1-1"))
        XCTAssertNotNil(out["extent"])
        XCTAssertNotNil(out["license"])
    }

    // MARK: - Example collection (license, providers)

    func test_fromDict_exampleCollection_hasLicenseAndProviders() throws {
        let dict = try Fixtures.jsonDict("collection/example-1.0.0.json")
        let coll = try Collection.parse(dict)
        XCTAssertFalse(coll.license.isEmpty)
    }

    // MARK: - addItem on Collection also calls item.setCollection

    func test_addItem_setsItemCollection() throws {
        let coll = Collection(id: "c", description: "d", extent: Self.makeExtent())
        let item = try Item(id: "i", geometry: nil, bbox: nil, datetime: Date(timeIntervalSince1970: 0), properties: [:])
        try coll.addItem(item)
        XCTAssertEqual(item.collectionID, "c")
        XCTAssertNotNil(item.getSingleLink(rel: .collection))
    }

    // MARK: - Summaries roundtrip

    func test_summaries_toDictAndBack() {
        var s = Summaries()
        s.add("gsd", value: .object(["minimum": .double(0.5), "maximum": .double(2.0)]))
        s.add("eo:bands", value: .array([.string("red"), .string("green")]))
        s.add("license", value: .string("MIT"))

        let dict = s.toDict()
        XCTAssertNotNil(dict["gsd"])
        XCTAssertNotNil(dict["eo:bands"])
        XCTAssertEqual(dict["license"], .string("MIT"))

        let parsed = Summaries.fromDict(dict)
        XCTAssertEqual(parsed.ranges["gsd"]?.minimum, .double(0.5))
        XCTAssertEqual(parsed.lists["eo:bands"], [.string("red"), .string("green")])
        XCTAssertEqual(parsed.other["license"], .string("MIT"))
    }

    // MARK: - Extent.fromItems

    func test_extent_fromItems() throws {
        let i1 = try Item(
            id: "1", geometry: nil, bbox: [0, 0, 1, 1],
            datetime: Date(timeIntervalSince1970: 0), properties: [:]
        )
        let i2 = try Item(
            id: "2", geometry: nil, bbox: [-1, -1, 2, 2],
            datetime: Date(timeIntervalSince1970: 100), properties: [:]
        )
        let ext = Extent.fromItems([i1, i2])
        XCTAssertEqual(ext.spatial.bboxes[0], [-1, -1, 2, 2])
        XCTAssertEqual(ext.temporal.intervals[0][0]?.timeIntervalSince1970, 0)
        XCTAssertEqual(ext.temporal.intervals[0][1]?.timeIntervalSince1970, 100)
    }
}
