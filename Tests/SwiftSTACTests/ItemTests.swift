import XCTest
@testable import SwiftSTAC

/// Tests ported from `pystac/tests/test_item.py`. Cases that require Catalog
/// walking or filesystem IO are deferred to phase 3.
final class ItemTests: XCTestCase {

    // MARK: - sample-item.json round-trip (pystac: test_to_from_dict)

    func test_fromDict_sampleItem_idAndAssetExtras() throws {
        let dict = try Fixtures.jsonDict("item/sample-item.json")
        let item = try Item.fromDict(dict)
        XCTAssertEqual(item.id, "CS3-20160503_132131_05")

        // analytic asset has a 'product' extra field
        let analytic = try XCTUnwrap(item.assets["analytic"])
        XCTAssertEqual(analytic.extraFields["product"], .string("http://cool-sat.com/catalog/products/analytic.json"))

        // thumbnail asset has no extras
        let thumbnail = try XCTUnwrap(item.assets["thumbnail"])
        XCTAssertTrue(thumbnail.extraFields.isEmpty)
    }

    func test_toDict_sampleItem_roundTripsKeyFields() throws {
        let dict = try Fixtures.jsonDict("item/sample-item.json")
        let item = try Item.fromDict(dict)
        let out = try item.toDict()
        XCTAssertEqual(out["type"], .string("Feature"))
        XCTAssertEqual(out["id"], .string("CS3-20160503_132131_05"))
        XCTAssertEqual(out["collection"], .string("CS3"))

        // properties.datetime preserved as the original string (modulo formatting)
        if case let .object(props)? = out["properties"], case let .string(dt)? = props["datetime"] {
            XCTAssertTrue(dt.hasPrefix("2016-05-03T13:22:30"))
        } else {
            XCTFail("Expected properties.datetime to round-trip")
        }

        // assets preserved
        if case let .object(assets)? = out["assets"] {
            XCTAssertNotNil(assets["analytic"])
            XCTAssertNotNil(assets["thumbnail"])
        } else {
            XCTFail("assets missing from output")
        }
    }

    func test_fromDict_preservesProvidedDict() throws {
        var dict = try Fixtures.jsonDict("item/sample-item.json")
        let before = dict
        _ = try Item.fromDict(dict)
        XCTAssertEqual(dict, before) // We never pass the dict by reference in Swift
    }

    // MARK: - datetime required logic

    func test_init_missingDatetime_andNoStartEnd_throws() {
        XCTAssertThrowsError(try Item(
            id: "x",
            geometry: nil, bbox: nil,
            datetime: nil,
            properties: [:]
        ))
    }

    func test_init_missingDatetime_butStartAndEnd_ok() throws {
        let item = try Item(
            id: "x",
            geometry: nil, bbox: nil,
            datetime: nil,
            properties: [:],
            startDatetime: Date(timeIntervalSince1970: 0),
            endDatetime: Date(timeIntervalSince1970: 60)
        )
        XCTAssertNil(item.datetime)
        XCTAssertNotNil(item.properties["start_datetime"])
        XCTAssertNotNil(item.properties["end_datetime"])
    }

    // MARK: - set_self_href / asset relative href anchoring

    func test_setSelfHref_keepsRelativeAssetsValid() throws {
        let item = try Item(
            id: "x", geometry: nil, bbox: nil,
            datetime: Date(timeIntervalSince1970: 0),
            properties: [:]
        )
        item.setSelfHrefKeepingAssetHrefs("/a/b/item.json")
        item.addAsset(key: "d", asset: Asset(href: "./data.tif"))
        // Absolute href should anchor on item's self href
        XCTAssertEqual(item.assets["d"]?.getAbsoluteHref(), "/a/b/data.tif")
    }

    // MARK: - asset getAbsoluteHref with item owner

    func test_assetAbsoluteHref_withItemOwner() throws {
        let item = try Item(
            id: "x", geometry: nil, bbox: nil,
            datetime: Date(timeIntervalSince1970: 0),
            properties: [:],
            href: "/a/b/item.json"
        )
        let asset = Asset(href: "./data.geojson")
        item.addAsset(key: "d", asset: asset)
        XCTAssertEqual(asset.getAbsoluteHref(), "/a/b/data.geojson")
    }

    func test_assetAbsoluteHref_noItemSelf_isNil() throws {
        let item = try Item(
            id: "x", geometry: nil, bbox: nil,
            datetime: Date(timeIntervalSince1970: 0),
            properties: [:]
        )
        let asset = Asset(href: "./data.geojson")
        item.addAsset(key: "d", asset: asset)
        XCTAssertNil(asset.getAbsoluteHref())
    }

    // MARK: - JSON round-trip via Codable

    func test_codable_roundTrip_preservesEquivalentDict() throws {
        let dict = try Fixtures.jsonDict("item/sample-item.json")
        let item = try Item.fromDict(dict)
        let enc = JSONEncoder()
        enc.outputFormatting = [.withoutEscapingSlashes]
        let data = try enc.encode(item)
        let item2 = try JSONDecoder().decode(Item.self, from: data)
        XCTAssertEqual(item.id, item2.id)
        XCTAssertEqual(item.collectionID, item2.collectionID)
        XCTAssertEqual(item.bbox, item2.bbox)
        XCTAssertEqual(item.stacExtensions, item2.stacExtensions)
        XCTAssertEqual(item.assets.keys.sorted(), item2.assets.keys.sorted())
    }

    // MARK: - setCollection

    func test_setCollection_addsLinkAndId() throws {
        let item = try Item(
            id: "x", geometry: nil, bbox: nil,
            datetime: Date(timeIntervalSince1970: 0),
            properties: [:]
        )
        let coll = Collection(
            id: "my-coll",
            description: "d",
            extent: Extent(spatial: SpatialExtent(bboxes: [[-180, -90, 180, 90]]), temporal: TemporalExtent(intervals: [[nil, nil]]))
        )
        item.setCollection(coll)
        XCTAssertEqual(item.collectionID, "my-coll")
        XCTAssertNotNil(item.getSingleLink(rel: .collection))

        item.setCollection(nil)
        XCTAssertNil(item.collectionID)
        XCTAssertNil(item.getSingleLink(rel: .collection))
    }

    // MARK: - STACObject link helpers (also exercised by Item)

    func test_addLinks_andFilter() throws {
        let item = try Item(
            id: "x", geometry: nil, bbox: nil,
            datetime: Date(timeIntervalSince1970: 0),
            properties: [:]
        )
        item.addLink(Link(rel: "alternate", target: "a.json"))
        item.addLink(Link(rel: "alternate", target: "b.json"))
        item.addLink(Link(rel: "canonical", target: "c.json"))
        XCTAssertEqual(item.getLinks(rel: "alternate").count, 2)
        XCTAssertEqual(item.getLinks(rel: "canonical").count, 1)
        item.removeLinks(rel: "alternate")
        XCTAssertEqual(item.getLinks(rel: "alternate").count, 0)
    }

    func test_removeHierarchicalLinks_addsCanonical() throws {
        let item = try Item(
            id: "x", geometry: nil, bbox: nil,
            datetime: Date(timeIntervalSince1970: 0),
            properties: [:],
            href: "/a/b/item.json"
        )
        item.addLink(Link(rel: "child", target: "child.json"))
        item.addLink(Link(rel: "alternate", target: "alt.json"))
        let removed = item.removeHierarchicalLinks(addCanonical: true)
        XCTAssertEqual(removed.count, 1)
        XCTAssertEqual(item.getLinks(rel: "canonical").count, 1)
        XCTAssertEqual(item.getLinks(rel: "child").count, 0)
        XCTAssertEqual(item.getLinks(rel: "alternate").count, 1)
    }
}
