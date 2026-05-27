import XCTest
@testable import SwiftSTAC

/// Tests ported from `pystac/tests/test_common_metadata.py`.
final class CommonMetadataTests: XCTestCase {

    func test_item_titleAndDescription_readWrite() throws {
        let item = try Item(
            id: "x", geometry: nil, bbox: nil,
            datetime: Date(timeIntervalSince1970: 0),
            properties: ["title": .string("Hello"), "description": .string("World")]
        )
        XCTAssertEqual(item.commonMetadata.title, "Hello")
        XCTAssertEqual(item.commonMetadata.commonMetadataDescription, "World")

        item.commonMetadata.title = "Updated"
        XCTAssertEqual(item.properties["title"], .string("Updated"))

        item.commonMetadata.title = nil
        XCTAssertNil(item.properties["title"])
    }

    func test_item_datetimes_roundTrip() throws {
        let item = try Item(
            id: "x", geometry: nil, bbox: nil,
            datetime: Date(timeIntervalSince1970: 0),
            properties: [:]
        )
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        item.commonMetadata.created = now
        item.commonMetadata.updated = now
        XCTAssertEqual(try XCTUnwrap(item.commonMetadata.created).timeIntervalSince1970, now.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(item.commonMetadata.updated).timeIntervalSince1970, now.timeIntervalSince1970, accuracy: 0.001)
    }

    func test_item_providers_readWrite() throws {
        let item = try Item(
            id: "x", geometry: nil, bbox: nil,
            datetime: Date(timeIntervalSince1970: 0),
            properties: [:]
        )
        item.commonMetadata.providers = [Provider(name: "Acme", roles: [.producer])]
        XCTAssertEqual(item.commonMetadata.providers?.count, 1)
        XCTAssertEqual(item.commonMetadata.providers?.first?.name, "Acme")
    }

    func test_item_instrumentsAndPlatform() throws {
        let item = try Item(
            id: "x", geometry: nil, bbox: nil,
            datetime: Date(timeIntervalSince1970: 0),
            properties: [:]
        )
        item.commonMetadata.platform = "sat-1"
        item.commonMetadata.instruments = ["msi", "pan"]
        item.commonMetadata.constellation = "constellation-a"
        item.commonMetadata.mission = "mission-x"
        item.commonMetadata.gsd = 10.0

        XCTAssertEqual(item.commonMetadata.platform, "sat-1")
        XCTAssertEqual(item.commonMetadata.instruments, ["msi", "pan"])
        XCTAssertEqual(item.commonMetadata.constellation, "constellation-a")
        XCTAssertEqual(item.commonMetadata.mission, "mission-x")
        XCTAssertEqual(item.commonMetadata.gsd, 10.0)
    }

    // CommonMetadata on Asset stores into extraFields
    func test_asset_commonMetadata_writesToExtraFields() {
        let asset = Asset(href: "./x.tif")
        asset.commonMetadata.gsd = 0.5
        XCTAssertEqual(asset.extraFields["gsd"], .double(0.5))
    }

    func test_itemAssetDefinition_accessors() {
        var def = ItemAssetDefinition(title: "T", mediaType: "image/tiff", roles: ["data"], extraFields: ["gsd": .double(0.5)])
        XCTAssertEqual(def.title, "T")
        XCTAssertEqual(def.mediaType, "image/tiff")
        XCTAssertEqual(def.roles, ["data"])
        XCTAssertEqual(def.properties["gsd"], .double(0.5))

        def.title = nil
        XCTAssertNil(def.properties["title"])

        let asset = def.createAsset(href: "./x.tif")
        XCTAssertEqual(asset.href, "./x.tif")
        XCTAssertEqual(asset.mediaType, "image/tiff")
        XCTAssertEqual(asset.roles, ["data"])
        XCTAssertEqual(asset.extraFields["gsd"], .double(0.5))
    }
}
