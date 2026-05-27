import XCTest
@testable import SwiftSTAC

/// Tests ported from `pystac/tests/test_item_collection.py`.
final class ItemCollectionTests: XCTestCase {

    func test_construct_empty() {
        let ic = ItemCollection(items: [])
        XCTAssertEqual(ic.count, 0)
    }

    func test_construct_withItems() throws {
        let i1 = try Item(id: "1", geometry: nil, bbox: nil, datetime: Date(timeIntervalSince1970: 0), properties: [:])
        let i2 = try Item(id: "2", geometry: nil, bbox: nil, datetime: Date(timeIntervalSince1970: 0), properties: [:])
        let ic = ItemCollection(items: [i1, i2])
        XCTAssertEqual(ic.count, 2)
        XCTAssertEqual(ic[0].id, "1")
    }

    func test_concat() throws {
        let i1 = try Item(id: "1", geometry: nil, bbox: nil, datetime: Date(timeIntervalSince1970: 0), properties: [:])
        let i2 = try Item(id: "2", geometry: nil, bbox: nil, datetime: Date(timeIntervalSince1970: 0), properties: [:])
        let a = ItemCollection(items: [i1])
        let b = ItemCollection(items: [i2])
        let c = a + b
        XCTAssertEqual(c.count, 2)
    }

    func test_iteration() throws {
        let i1 = try Item(id: "1", geometry: nil, bbox: nil, datetime: Date(timeIntervalSince1970: 0), properties: [:])
        let i2 = try Item(id: "2", geometry: nil, bbox: nil, datetime: Date(timeIntervalSince1970: 0), properties: [:])
        let ic = ItemCollection(items: [i1, i2])
        let ids = ic.map(\.id)
        XCTAssertEqual(ids, ["1", "2"])
    }

    func test_toDict() throws {
        let i1 = try Item(id: "1", geometry: nil, bbox: nil, datetime: Date(timeIntervalSince1970: 0), properties: [:])
        let ic = ItemCollection(items: [i1], extraFields: ["count": .int(1)])
        let d = try ic.toDict()
        XCTAssertEqual(d["type"], .string("FeatureCollection"))
        XCTAssertEqual(d["count"], .int(1))
        if case let .array(features)? = d["features"] {
            XCTAssertEqual(features.count, 1)
        } else { XCTFail("features should be an array") }
    }

    func test_isItemCollection_true() {
        let d: [String: JSONValue] = [
            "type": .string("FeatureCollection"),
            "stac_version": .string("1.1.0"),
            "features": .array([]),
        ]
        XCTAssertTrue(ItemCollection.isItemCollection(d))
    }

    func test_isItemCollection_falseForOtherTypes() {
        let d: [String: JSONValue] = ["type": .string("Catalog")]
        XCTAssertFalse(ItemCollection.isItemCollection(d))
    }

    func test_fromDict_sampleFixture() throws {
        let dict = try Fixtures.jsonDict("item-collection/sample-item-collection.json")
        let ic = try ItemCollection.fromDict(dict)
        XCTAssertGreaterThan(ic.count, 0)
    }
}
