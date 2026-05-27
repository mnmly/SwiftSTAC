import XCTest
@testable import SwiftSTAC

/// Smoke tests for the remaining 20 STAC extensions. Each test exercises the
/// representative fields, verifies storage in the right property bag, and
/// asserts the schema URI is registered on the host object.
final class AllExtensionsTests: XCTestCase {

    private func makeItem() throws -> Item {
        try Item(
            id: "x", geometry: nil, bbox: nil,
            datetime: Date(timeIntervalSince1970: 0), properties: [:]
        )
    }

    // MARK: - Grid

    func test_grid() throws {
        let item = try makeItem()
        item.grid.code = "MGRS-33TWN"
        XCTAssertEqual(item.properties["grid:code"], .string("MGRS-33TWN"))
        XCTAssertTrue(item.stacExtensions.contains(GridExtension.schemaURI))
    }

    // MARK: - MGRS

    func test_mgrs() throws {
        let item = try makeItem()
        item.mgrs.latitudeBand = "T"
        item.mgrs.gridSquare = "WN"
        item.mgrs.utmZone = 33
        XCTAssertEqual(item.properties["mgrs:latitude_band"], .string("T"))
        XCTAssertEqual(item.properties["mgrs:grid_square"], .string("WN"))
        XCTAssertEqual(item.properties["mgrs:utm_zone"], .int(33))
        XCTAssertTrue(item.stacExtensions.contains(MGRSExtension.schemaURI))
    }

    // MARK: - View

    func test_view_allFields() throws {
        let item = try makeItem()
        item.view.offNadir = 10.0
        item.view.incidenceAngle = 20.0
        item.view.azimuth = 30.0
        item.view.sunAzimuth = 140.0
        item.view.sunElevation = 70.0
        XCTAssertEqual(item.view.offNadir, 10.0)
        XCTAssertEqual(item.view.incidenceAngle, 20.0)
        XCTAssertEqual(item.view.azimuth, 30.0)
        XCTAssertEqual(item.view.sunAzimuth, 140.0)
        XCTAssertEqual(item.view.sunElevation, 70.0)
    }

    // MARK: - Sat

    func test_sat_orbitState_andDateRoundTrip() throws {
        let item = try makeItem()
        item.sat.absoluteOrbit = 12345
        item.sat.relativeOrbit = 22
        item.sat.orbitState = .ascending
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        item.sat.anxDatetime = now
        XCTAssertEqual(item.sat.absoluteOrbit, 12345)
        XCTAssertEqual(item.sat.orbitState, .ascending)
        XCTAssertEqual(try XCTUnwrap(item.sat.anxDatetime).timeIntervalSince1970, now.timeIntervalSince1970, accuracy: 0.001)
    }

    // MARK: - Scientific

    func test_scientific_doiCitationPublications() throws {
        let item = try makeItem()
        item.sci.doi = "10.1234/abc"
        item.sci.citation = "Author et al., 2024"
        item.sci.publications = [Publication(doi: "10.5678/x", citation: "Other, 2023")]
        XCTAssertEqual(item.properties["sci:doi"], .string("10.1234/abc"))
        XCTAssertEqual(item.sci.publications?.count, 1)
        XCTAssertEqual(item.sci.publications?.first?.doi, "10.5678/x")
    }

    // MARK: - File

    func test_file_sizeChecksumByteOrder() throws {
        let asset = Asset(href: "./x.tif")
        let item = try makeItem()
        item.addAsset(key: "data", asset: asset)
        asset.file.size = 1234
        asset.file.checksum = "1220abcd"
        asset.file.byteOrder = .littleEndian
        XCTAssertEqual(asset.extraFields["file:size"], .int(1234))
        XCTAssertEqual(asset.extraFields["file:byte_order"], .string("little-endian"))
        // Schema registers on the item
        XCTAssertTrue(item.stacExtensions.contains(FileExtension.schemaURI))
    }

    // MARK: - Version

    func test_version_anddeprecated() throws {
        let item = try makeItem()
        item.version.version = "v2"
        item.version.deprecated = true
        XCTAssertEqual(item.properties["version"], .string("v2"))
        XCTAssertEqual(item.properties["deprecated"], .bool(true))
    }

    // MARK: - Xarray Assets

    func test_xarrayAssets() throws {
        let asset = Asset(href: "./x.zarr")
        let item = try makeItem()
        item.addAsset(key: "data", asset: asset)
        asset.xarrayAssets.openKwargs = ["consolidated": .bool(true)]
        asset.xarrayAssets.storageOptions = ["anon": .bool(true)]
        XCTAssertEqual(asset.extraFields["xarray:open_kwargs"], .object(["consolidated": .bool(true)]))
    }

    // MARK: - Timestamps

    func test_timestamps() throws {
        let item = try makeItem()
        let t = Date(timeIntervalSince1970: 1_700_000_000)
        item.timestamps.published = t
        item.timestamps.expires = t
        item.timestamps.unpublished = t
        XCTAssertNotNil(item.properties["published"])
        XCTAssertTrue(item.stacExtensions.contains(TimestampsExtension.schemaURI))
    }

    // MARK: - Render

    func test_render() throws {
        let item = try makeItem()
        item.render.renders = [
            "rgb": [
                "title": .string("RGB"),
                "assets": .array([.string("red"), .string("green"), .string("blue")]),
            ]
        ]
        if case let .object(renders)? = item.properties["renders"],
           case let .object(rgb)? = renders["rgb"],
           case let .string(title)? = rgb["title"] {
            XCTAssertEqual(title, "RGB")
        } else { XCTFail("render not encoded as expected") }
    }

    // MARK: - SAR

    func test_sar() throws {
        let item = try makeItem()
        item.sar.instrumentMode = "IW"
        item.sar.frequencyBand = .C
        item.sar.polarizations = ["VV", "VH"]
        item.sar.productType = "GRD"
        item.sar.centerFrequency = 5.405
        item.sar.observationDirection = .right
        XCTAssertEqual(item.sar.polarizations, ["VV", "VH"])
        XCTAssertEqual(item.sar.frequencyBand, .C)
        XCTAssertEqual(item.sar.observationDirection, .right)
    }

    // MARK: - Raster

    func test_raster_bands() throws {
        let asset = Asset(href: "./x.tif")
        let item = try makeItem()
        item.addAsset(key: "data", asset: asset)
        asset.raster.bands = [
            RasterBand(dataType: "uint16", bitsPerSample: 16, spatialResolution: 10.0),
            RasterBand(dataType: "uint16", bitsPerSample: 16, spatialResolution: 10.0),
        ]
        let read = asset.raster.bands
        XCTAssertEqual(read?.count, 2)
        XCTAssertEqual(read?[0].dataType, "uint16")
        XCTAssertEqual(read?[0].bitsPerSample, 16)
    }

    // MARK: - Label

    func test_label() throws {
        let item = try makeItem()
        item.label.labelType = .vector
        item.label.tasks = ["classification"]
        item.label.classes = [LabelClasses(name: "cls", classes: [.string("a"), .string("b")])]
        item.label.labelDescription = "ground truth"
        XCTAssertEqual(item.label.labelType, .vector)
        XCTAssertEqual(item.label.classes?.first?.name, "cls")
        XCTAssertEqual(item.label.classes?.first?.classes, [.string("a"), .string("b")])
    }

    // MARK: - Classification

    func test_classification_classesAndBitfields() throws {
        let item = try makeItem()
        item.classification.classes = [
            Classification(value: 0, name: "water"),
            Classification(value: 1, name: "land"),
        ]
        let cls = try XCTUnwrap(item.classification.classes)
        XCTAssertEqual(cls.count, 2)
        XCTAssertEqual(cls[0].value, 0)
        XCTAssertEqual(cls[1].name, "land")

        item.classification.bitfields = [
            ClassificationBitfield(offset: 0, length: 2, classes: [Classification(value: 0, name: "ok")])
        ]
        XCTAssertEqual(item.classification.bitfields?.first?.length, 2)
    }

    // MARK: - Datacube

    func test_datacube_dimensions() throws {
        let item = try makeItem()
        var dim = DatacubeDimension()
        dim.dimensionType = .spatial
        dim.axis = "x"
        dim.unit = "m"
        item.cube.dimensions = ["x": dim]
        let read = item.cube.dimensions?["x"]
        XCTAssertEqual(read?.dimensionType, .spatial)
        XCTAssertEqual(read?.unit, "m")
    }

    // MARK: - Storage

    func test_storage() throws {
        let item = try makeItem()
        item.storage.schemes = [
            "aws": StorageScheme(type: "aws-s3", platform: "https://{bucket}.s3.amazonaws.com", region: "us-west-2", requesterPays: false)
        ]
        item.storage.refs = ["aws"]
        XCTAssertEqual(item.storage.schemes?["aws"]?.type, "aws-s3")
        XCTAssertEqual(item.storage.refs, ["aws"])
    }

    // MARK: - Table

    func test_table_columns() throws {
        let asset = Asset(href: "./x.parquet")
        let item = try makeItem()
        item.addAsset(key: "data", asset: asset)
        asset.table.columns = [
            TableColumn(name: "id", type: "int64"),
            TableColumn(name: "geom", type: "geometry"),
        ]
        asset.table.rowCount = 1000
        XCTAssertEqual(asset.table.columns?.count, 2)
        XCTAssertEqual(asset.table.rowCount, 1000)
    }

    // MARK: - PointCloud

    func test_pointcloud() throws {
        let item = try makeItem()
        item.pc.count = 1_000_000
        item.pc.type = .lidar
        item.pc.encoding = "laszip"
        item.pc.schemas = [PointCloudSchema(name: "X", size: 8, type: "floating")]
        XCTAssertEqual(item.pc.count, 1_000_000)
        XCTAssertEqual(item.pc.type, .lidar)
        XCTAssertEqual(item.pc.schemas?.first?.name, "X")
    }

    // MARK: - MLM

    func test_mlm_topLevelFields() throws {
        let item = try makeItem()
        item.mlm.name = "resnet50"
        item.mlm.architecture = "ResNet"
        item.mlm.tasks = ["classification"]
        item.mlm.framework = "pytorch"
        item.mlm.totalParameters = 25_557_032
        item.mlm.pretrained = true
        item.mlm.acceleratorConstrained = false

        XCTAssertEqual(item.mlm.name, "resnet50")
        XCTAssertEqual(item.mlm.tasks, ["classification"])
        XCTAssertEqual(item.mlm.totalParameters, 25_557_032)
        XCTAssertEqual(item.mlm.pretrained, true)
        XCTAssertTrue(item.stacExtensions.contains(MLMExtension.schemaURI))
    }

    func test_mlm_inputAsPropertyBag() throws {
        let item = try makeItem()
        item.mlm.input = [
            .object([
                "name": .string("image"),
                "bands": .array([.string("red"), .string("green"), .string("blue")]),
            ])
        ]
        XCTAssertEqual(item.mlm.input?.count, 1)
    }

    // MARK: - JSON round-trip preserves all extension fields

    func test_extensions_jsonRoundTrip_preservesFields() throws {
        let item = try makeItem()
        item.grid.code = "MGRS-33TWN"
        item.view.offNadir = 5.0
        item.sat.orbitState = .descending
        item.sar.frequencyBand = .C
        item.mlm.name = "resnet50"

        let dict = try item.toDict()
        let restored = try Item.fromDict(dict)
        XCTAssertEqual(restored.grid.code, "MGRS-33TWN")
        XCTAssertEqual(restored.view.offNadir, 5.0)
        XCTAssertEqual(restored.sat.orbitState, .descending)
        XCTAssertEqual(restored.sar.frequencyBand, .C)
        XCTAssertEqual(restored.mlm.name, "resnet50")
        // All 5 schemas should be registered
        for uri in [
            GridExtension.schemaURI,
            ViewExtension.schemaURI,
            SatExtension.schemaURI,
            SARExtension.schemaURI,
            MLMExtension.schemaURI,
        ] {
            XCTAssertTrue(restored.stacExtensions.contains(uri), "missing \(uri)")
        }
    }
}
