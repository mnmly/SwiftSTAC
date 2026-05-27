import XCTest
@testable import SwiftSTAC

/// Asset tests ported from `pystac/tests/test_asset.py`.
///
/// The filesystem `move/copy/delete` cases and the cases that build an Asset
/// via Catalog/Item loading are deferred until Item is implemented — those
/// will be added to `AssetItemIntegrationTests` once Item exists.
final class AssetTests: XCTestCase {

    /// Stand-in `AssetOwner` used purely to anchor `getSelfHref()`.
    final class FakeOwner: AssetOwner {
        var selfHref: String?
        var assets: [String: Asset] = [:]
        init(selfHref: String?) { self.selfHref = selfHref }
        func getSelfHref() -> String? { selfHref }
    }

    // MARK: - get_absolute_href (parametrised in pystac)

    func test_asset_get_absolute_href_urlBase_relativeAsset() {
        let owner = FakeOwner(selfHref: "http://test.com/stac/catalog/myitem.json")
        let asset = Asset(href: "asset.data")
        owner.addAsset(key: "data", asset: asset)
        XCTAssertEqual(asset.getAbsoluteHref(), "http://test.com/stac/catalog/asset.data")
    }

    func test_asset_get_absolute_href_urlBase_rootRelativeAsset() {
        let owner = FakeOwner(selfHref: "http://test.com/stac/catalog/myitem.json")
        let asset = Asset(href: "/asset.data")
        owner.addAsset(key: "data", asset: asset)
        XCTAssertEqual(asset.getAbsoluteHref(), "http://test.com/asset.data")
    }

    func test_asset_get_absolute_href_localBase_relativeAsset() {
        let owner = FakeOwner(selfHref: "/local/myitem.json")
        let asset = Asset(href: "asset.data")
        owner.addAsset(key: "data", asset: asset)
        XCTAssertEqual(asset.getAbsoluteHref(), "/local/asset.data")
    }

    func test_asset_get_absolute_href_localBase_subdirRelativeAsset() {
        let owner = FakeOwner(selfHref: "/local/myitem.json")
        let asset = Asset(href: "subdir/asset.data")
        owner.addAsset(key: "data", asset: asset)
        XCTAssertEqual(asset.getAbsoluteHref(), "/local/subdir/asset.data")
    }

    func test_asset_get_absolute_href_localBase_absoluteAsset() {
        let owner = FakeOwner(selfHref: "/local/myitem.json")
        let asset = Asset(href: "/absolute/asset.data")
        owner.addAsset(key: "data", asset: asset)
        XCTAssertEqual(asset.getAbsoluteHref(), "/absolute/asset.data")
    }

    func test_asset_get_absolute_href_relativeAsset_noOwner_returnsNil() {
        let asset = Asset(href: "asset.data")
        XCTAssertNil(asset.getAbsoluteHref())
    }

    func test_asset_get_absolute_href_absoluteAsset_noOwner_returnsHref() {
        let asset = Asset(href: "/already/absolute.data")
        XCTAssertEqual(asset.getAbsoluteHref(), "/already/absolute.data")
    }

    // MARK: - has_role

    func test_asset_hasRole_true() {
        let asset = Asset(href: "x.tif", roles: ["data", "overview"])
        XCTAssertTrue(asset.hasRole("data"))
        XCTAssertTrue(asset.hasRole("overview"))
    }

    func test_asset_hasRole_falseAndNilRoles() {
        XCTAssertFalse(Asset(href: "x.tif").hasRole("data"))
        XCTAssertFalse(Asset(href: "x.tif", roles: []).hasRole("data"))
    }

    // MARK: - JSON round-trip / shape

    func test_asset_decode_minimal() throws {
        let json = #"{"href":"./data.tif"}"#.data(using: .utf8)!
        let a = try JSONDecoder().decode(Asset.self, from: json)
        XCTAssertEqual(a.href, "./data.tif")
        XCTAssertNil(a.mediaType)
        XCTAssertNil(a.title)
        XCTAssertNil(a.assetDescription)
        XCTAssertNil(a.roles)
        XCTAssertTrue(a.extraFields.isEmpty)
    }

    func test_asset_decode_full_preservesExtras() throws {
        let json = #"""
        {
          "href": "./data.tif",
          "type": "image/tiff",
          "title": "RGB",
          "description": "natural color",
          "roles": ["data"],
          "eo:bands": [{"name":"red"}],
          "gsd": 1.5
        }
        """#.data(using: .utf8)!
        let a = try JSONDecoder().decode(Asset.self, from: json)
        XCTAssertEqual(a.href, "./data.tif")
        XCTAssertEqual(a.mediaType, "image/tiff")
        XCTAssertEqual(a.title, "RGB")
        XCTAssertEqual(a.assetDescription, "natural color")
        XCTAssertEqual(a.roles, ["data"])
        XCTAssertEqual(a.extraFields["gsd"], .double(1.5))
        if case .array(let bands)? = a.extraFields["eo:bands"] {
            XCTAssertEqual(bands.count, 1)
            XCTAssertEqual(bands[0]["name"], .string("red"))
        } else {
            XCTFail("eo:bands should decode as array")
        }
    }

    func test_asset_roundTrip() throws {
        let a = Asset(
            href: "./data.tif",
            title: "RGB",
            description: "natural color",
            mediaType: "image/tiff",
            roles: ["data"],
            extraFields: ["gsd": .double(1.5)]
        )
        let data = try JSONEncoder().encode(a)
        let b = try JSONDecoder().decode(Asset.self, from: data)
        XCTAssertEqual(a, b)
    }

    func test_asset_encode_minimalOmitsOptional() throws {
        let a = Asset(href: "./data.tif")
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try enc.encode(a)
        XCTAssertEqual(String(data: data, encoding: .utf8), #"{"href":"./data.tif"}"#)
    }

    // MARK: - clone

    func test_asset_clone() {
        let a = Asset(href: "./x", title: "t", roles: ["data"], extraFields: ["k": "v"])
        let c = a.clone()
        XCTAssertEqual(a, c)
        // mutating clone doesn't affect original
        c.href = "./y"
        XCTAssertEqual(a.href, "./x")
    }

    // MARK: - makeAssetHrefsRelative / Absolute

    func test_makeAssetHrefsRelative() throws {
        let owner = FakeOwner(selfHref: "/a/b/item.json")
        owner.addAsset(key: "d", asset: Asset(href: "/a/b/data.tif"))
        try owner.makeAssetHrefsRelative()
        XCTAssertEqual(owner.assets["d"]!.href, "./data.tif")
    }

    func test_makeAssetHrefsAbsolute() throws {
        let owner = FakeOwner(selfHref: "/a/b/item.json")
        owner.addAsset(key: "d", asset: Asset(href: "./data.tif"))
        try owner.makeAssetHrefsAbsolute()
        XCTAssertEqual(owner.assets["d"]!.href, "/a/b/data.tif")
    }

    func test_makeAssetHrefsRelative_throwsWithoutSelfHref() {
        let owner = FakeOwner(selfHref: nil)
        owner.addAsset(key: "d", asset: Asset(href: "/a/b/data.tif"))
        XCTAssertThrowsError(try owner.makeAssetHrefsRelative())
    }
}
