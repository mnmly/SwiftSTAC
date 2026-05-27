import XCTest
@testable import SwiftSTAC

/// Tests for the extension framework + the EO and Projection accessors.
/// Patterned after pystac's extension test suites (`test_eo.py`,
/// `test_projection.py`).
final class ExtensionsTests: XCTestCase {

    private func makeItem() throws -> Item {
        try Item(
            id: "x",
            geometry: nil, bbox: nil,
            datetime: Date(timeIntervalSince1970: 0),
            properties: [:]
        )
    }

    // MARK: - EO on Item

    func test_eo_setCloudCover_registersSchema() throws {
        let item = try makeItem()
        item.eo.cloudCover = 12.5
        XCTAssertEqual(item.eo.cloudCover, 12.5)
        XCTAssertEqual(item.properties["eo:cloud_cover"], .double(12.5))
        XCTAssertTrue(item.stacExtensions.contains(EOExtension.schemaURI))
    }

    func test_eo_setSnowCover() throws {
        let item = try makeItem()
        item.eo.snowCover = 5.0
        XCTAssertEqual(item.properties["eo:snow_cover"], .double(5.0))
    }

    func test_eo_bands_roundTrip() throws {
        let item = try makeItem()
        let bands = [
            EOBand(name: "B01", commonName: "blue", centerWavelength: 0.49),
            EOBand(name: "B02", commonName: "green", centerWavelength: 0.56),
        ]
        item.eo.bands = bands
        let readBack = item.eo.bands
        XCTAssertEqual(readBack?.count, 2)
        XCTAssertEqual(readBack?[0].name, "B01")
        XCTAssertEqual(readBack?[0].commonName, "blue")
        XCTAssertEqual(readBack?[1].centerWavelength, 0.56)
    }

    func test_eo_clearCloudCover_removesProperty() throws {
        let item = try makeItem()
        item.eo.cloudCover = 1.0
        item.eo.cloudCover = nil
        XCTAssertNil(item.properties["eo:cloud_cover"])
    }

    // MARK: - EO on Asset (registers on owner)

    func test_eo_onAsset_registersOnOwner() throws {
        let item = try makeItem()
        let asset = Asset(href: "./x.tif")
        item.addAsset(key: "data", asset: asset)
        asset.eo.cloudCover = 7.0
        XCTAssertEqual(asset.extraFields["eo:cloud_cover"], .double(7.0))
        // Schema should have been registered on the owning item.
        XCTAssertTrue(item.stacExtensions.contains(EOExtension.schemaURI))
    }

    // MARK: - Projection

    func test_projection_setEPSG_andRead() throws {
        let item = try makeItem()
        item.proj.epsg = 32633
        XCTAssertEqual(item.proj.epsg, 32633)
        XCTAssertEqual(item.properties["proj:epsg"], .int(32633))
        XCTAssertTrue(item.stacExtensions.contains(ProjectionExtension.schemaURI))
    }

    func test_projection_code() throws {
        let item = try makeItem()
        item.proj.code = "EPSG:32633"
        XCTAssertEqual(item.properties["proj:code"], .string("EPSG:32633"))
    }

    func test_projection_bbox() throws {
        let item = try makeItem()
        item.proj.bbox = [0, 0, 1000, 1000]
        XCTAssertEqual(item.proj.bbox, [0, 0, 1000, 1000])
    }

    func test_projection_shape_andTransform() throws {
        let item = try makeItem()
        item.proj.shape = [1024, 2048]
        item.proj.transform = [10, 0, 100_000, 0, -10, 1_000_000]
        XCTAssertEqual(item.proj.shape, [1024, 2048])
        XCTAssertEqual(item.proj.transform, [10, 0, 100_000, 0, -10, 1_000_000])
    }

    func test_projection_centroid() throws {
        let item = try makeItem()
        item.proj.centroid = ["lat": 45.0, "lon": -120.0]
        let read = item.proj.centroid
        XCTAssertEqual(read?["lat"], 45.0)
        XCTAssertEqual(read?["lon"], -120.0)
    }

    // MARK: - Cross-extension on the same item

    func test_eoAndProj_coexist_andRegisterBothSchemas() throws {
        let item = try makeItem()
        item.eo.cloudCover = 3.0
        item.proj.epsg = 4326
        XCTAssertTrue(item.stacExtensions.contains(EOExtension.schemaURI))
        XCTAssertTrue(item.stacExtensions.contains(ProjectionExtension.schemaURI))
        XCTAssertEqual(item.stacExtensions.count, 2)
    }

    // MARK: - JSON round-trip preserves extension fields

    func test_eo_roundTripsThroughJSON() throws {
        let item = try makeItem()
        item.eo.cloudCover = 12.5
        item.eo.bands = [EOBand(name: "B01")]
        let dict = try item.toDict()
        let restored = try Item.fromDict(dict)
        XCTAssertEqual(restored.eo.cloudCover, 12.5)
        XCTAssertEqual(restored.eo.bands?.first?.name, "B01")
        XCTAssertTrue(restored.stacExtensions.contains(EOExtension.schemaURI))
    }
}
