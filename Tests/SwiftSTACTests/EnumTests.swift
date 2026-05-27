import XCTest
@testable import SwiftSTAC

final class EnumTests: XCTestCase {

    // MARK: MediaType

    func test_mediaType_rawValues() {
        XCTAssertEqual(MediaType.geojson.rawValue, "application/geo+json")
        XCTAssertEqual(MediaType.cog.rawValue, "image/tiff; application=geotiff; profile=cloud-optimized")
        XCTAssertEqual(MediaType.json.rawValue, "application/json")
    }

    func test_mediaType_codable() throws {
        let enc = JSONEncoder()
        enc.outputFormatting = .withoutEscapingSlashes
        let data = try enc.encode(MediaType.png)
        XCTAssertEqual(String(data: data, encoding: .utf8), "\"image/png\"")
        let decoded = try JSONDecoder().decode(MediaType.self, from: data)
        XCTAssertEqual(decoded, .png)
    }

    func test_mediaType_stacJSON() {
        // pystac.STAC_JSON == [None, GEOJSON, JSON]
        XCTAssertEqual(MediaType.stacJSON.count, 3)
        XCTAssertTrue(MediaType.stacJSON.contains(nil))
        XCTAssertTrue(MediaType.stacJSON.contains(.geojson))
        XCTAssertTrue(MediaType.stacJSON.contains(.json))
    }

    // MARK: RelType

    func test_relType_rawValues() {
        XCTAssertEqual(RelType.derivedFrom.rawValue, "derived_from")
        XCTAssertEqual(RelType.`self`.rawValue, "self")
        XCTAssertEqual(RelType.root.rawValue, "root")
    }

    func test_relType_hierarchical() {
        // pystac.link.HIERARCHICAL_LINKS
        let expected: Set<RelType> = [.root, .child, .parent, .collection, .item, .items]
        XCTAssertEqual(RelType.hierarchical, expected)
        XCTAssertFalse(RelType.hierarchical.contains(.`self`))
        XCTAssertFalse(RelType.hierarchical.contains(.canonical))
    }

    // MARK: STACObjectType

    func test_stacObjectType_rawValues() {
        XCTAssertEqual(STACObjectType.catalog.rawValue, "Catalog")
        XCTAssertEqual(STACObjectType.collection.rawValue, "Collection")
        XCTAssertEqual(STACObjectType.item.rawValue, "Feature")
    }

    // MARK: ProviderRole

    func test_providerRole_rawValues() {
        XCTAssertEqual(ProviderRole.licensor.rawValue, "licensor")
        XCTAssertEqual(ProviderRole.producer.rawValue, "producer")
        XCTAssertEqual(ProviderRole.processor.rawValue, "processor")
        XCTAssertEqual(ProviderRole.host.rawValue, "host")
    }
}
