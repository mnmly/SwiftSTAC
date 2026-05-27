import XCTest
@testable import SwiftSTAC

final class ProviderTests: XCTestCase {

    // Round-trip JSON
    func test_provider_decodeMinimal() throws {
        let json = #"{"name":"Acme"}"#.data(using: .utf8)!
        let p = try JSONDecoder().decode(Provider.self, from: json)
        XCTAssertEqual(p.name, "Acme")
        XCTAssertNil(p.description)
        XCTAssertNil(p.roles)
        XCTAssertNil(p.url)
        XCTAssertTrue(p.extraFields.isEmpty)
    }

    func test_provider_decodeFull() throws {
        let json = #"""
        {
          "name": "Acme",
          "description": "An imagery provider",
          "roles": ["producer","host"],
          "url": "https://acme.example",
          "vendor_id": 42
        }
        """#.data(using: .utf8)!
        let p = try JSONDecoder().decode(Provider.self, from: json)
        XCTAssertEqual(p.name, "Acme")
        XCTAssertEqual(p.description, "An imagery provider")
        XCTAssertEqual(p.roles, [.producer, .host])
        XCTAssertEqual(p.url, "https://acme.example")
        XCTAssertEqual(p.extraFields["vendor_id"], .int(42))
    }

    func test_provider_roundTrip_preservesExtras() throws {
        let p = Provider(
            name: "Acme",
            description: "An imagery provider",
            roles: [.licensor],
            url: "https://acme.example",
            extraFields: ["vendor_id": .int(42), "tier": "gold"]
        )
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        let data = try enc.encode(p)
        let p2 = try JSONDecoder().decode(Provider.self, from: data)
        XCTAssertEqual(p, p2)
    }

    func test_provider_missingName_throws() {
        let json = #"{"description":"x"}"#.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(Provider.self, from: json))
    }

    // pystac: Provider.to_dict() omits None fields
    func test_provider_encodeOmitsNilFields() throws {
        let p = Provider(name: "Acme")
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        let data = try enc.encode(p)
        let s = String(data: data, encoding: .utf8)!
        XCTAssertEqual(s, #"{"name":"Acme"}"#)
    }
}
