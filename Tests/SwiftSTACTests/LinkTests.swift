import XCTest
@testable import SwiftSTAC

/// Tests ported from `pystac/tests/test_link.py`. Object-target tests that
/// require Item/Catalog/Collection are deferred until those land.
final class LinkTests: XCTestCase {

    // Stand-in STAC object for object-target tests.
    final class FakeSTAC: STACObject {
        var autoTitle: String?
        init(id: String, selfHref: String? = nil, autoTitle: String? = nil) {
            self.autoTitle = autoTitle
            super.init(id: id)
            if let selfHref { self.setSelfHref(selfHref) }
        }
        override class var stacObjectType: STACObjectType { .collection }
        override var linkAutoTitle: String? { autoTitle }
    }

    // MARK: - Minimal (pystac: test_minimal)

    func test_minimal_hrefRoundTrip() {
        let link = Link(rel: "my rel", target: "https://example.com/a/b")
        XCTAssertEqual(link.getHref(), "https://example.com/a/b")
        XCTAssertEqual(link.getAbsoluteHref(), "https://example.com/a/b")
        XCTAssertFalse(link.isResolved())
    }

    func test_minimal_description() {
        let link = Link(rel: "my rel", target: "https://example.com/a/b")
        XCTAssertEqual(link.description, "<Link rel=my rel target=https://example.com/a/b>")
    }

    func test_minimal_toDict() throws {
        let link = Link(rel: "my rel", target: "https://example.com/a/b")
        let dict = try jsonObject(link)
        XCTAssertEqual(dict.count, 2)
        XCTAssertEqual(dict["rel"] as? String, "my rel")
        XCTAssertEqual(dict["href"] as? String, "https://example.com/a/b")
    }

    func test_minimal_clone_isIndependent() {
        let link = Link(rel: "my rel", target: "https://example.com/a/b")
        let clone = link.clone()
        XCTAssertFalse(link === clone)
        XCTAssertEqual(clone.getHref(), link.getHref())
        clone.rel = "other"
        XCTAssertEqual(link.rel, "my rel")
    }

    func test_minimal_setOwner() {
        let link = Link(rel: "r", target: "/t")
        XCTAssertNil(link.owner)
        let owner = FakeSTAC(id: "x", selfHref: "/a")
        link.setOwner(owner)
        XCTAssertTrue(link.owner === owner)
        link.setOwner(nil)
        XCTAssertNil(link.owner)
    }

    // MARK: - Relative (pystac: test_relative)

    func test_relative_toDict_includesAllFields() throws {
        let link = Link(
            rel: "my rel",
            target: "../elsewhere",
            mediaType: "example/stac_thing",
            title: "a title",
            extraFields: ["a": "b"]
        )
        let dict = try jsonObject(link)
        XCTAssertEqual(dict["rel"] as? String, "my rel")
        XCTAssertEqual(dict["href"] as? String, "../elsewhere")
        XCTAssertEqual(dict["type"] as? String, "example/stac_thing")
        XCTAssertEqual(dict["title"] as? String, "a title")
        XCTAssertEqual(dict["a"] as? String, "b")
    }

    // MARK: - Serialize (pystac: test_serialize_link)

    func test_serialize_link() throws {
        let href = "https://some-domain/path/to/item.json"
        let title = "A Test Link"
        let link = Link(rel: RelType.`self`.rawValue, target: href, mediaType: MediaType.json.rawValue, title: title)
        let dict = try jsonObject(link)
        XCTAssertEqual(dict["rel"] as? String, "self")
        XCTAssertEqual(dict["type"] as? String, "application/json")
        XCTAssertEqual(dict["title"] as? String, title)
        XCTAssertEqual(dict["href"] as? String, href)
    }

    // MARK: - from_dict round-trip (pystac: test_static_from_dict_round_trip)

    func test_fromDict_roundTrip_emptyStrings() throws {
        let json = #"{"rel":"","href":""}"#.data(using: .utf8)!
        let link = try JSONDecoder().decode(Link.self, from: json)
        XCTAssertEqual(link.rel, "")
        XCTAssertEqual(link.getHref(), "")
        let dict = try jsonObject(link)
        XCTAssertEqual(dict["rel"] as? String, "")
        XCTAssertEqual(dict["href"] as? String, "")
    }

    func test_fromDict_roundTrip_simple() throws {
        let json = #"{"rel":"r","href":"t"}"#.data(using: .utf8)!
        let link = try JSONDecoder().decode(Link.self, from: json)
        XCTAssertEqual(link.rel, "r")
        XCTAssertEqual(link.getHref(), "t")
    }

    func test_fromDict_roundTrip_full() throws {
        let json = #"{"rel":"r","href":"t","type":"a/b","title":"t","c":"d","1":2}"#.data(using: .utf8)!
        let link = try JSONDecoder().decode(Link.self, from: json)
        XCTAssertEqual(link.rel, "r")
        XCTAssertEqual(link.getHref(), "t")
        XCTAssertEqual(link.mediaType, "a/b")
        XCTAssertEqual(link.title, "t")
        XCTAssertEqual(link.extraFields["c"], .string("d"))
        XCTAssertEqual(link.extraFields["1"], .int(2))
    }

    // MARK: - from_dict failures (pystac: test_static_from_dict_failures)

    func test_fromDict_missingRel_throws() {
        let json = #"{"href":"t"}"#.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(Link.self, from: json))
    }

    func test_fromDict_missingHref_throws() {
        let json = #"{"rel":"r"}"#.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(Link.self, from: json))
    }

    func test_fromDict_empty_throws() {
        let json = "{}".data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(Link.self, from: json))
    }

    // MARK: - Hierarchical / non-hierarchical

    func test_isHierarchical_true_forHierarchicalRels() {
        for rel in RelType.hierarchical {
            XCTAssertTrue(Link(rel: rel.rawValue, target: "x").isHierarchical(), "expected \(rel) to be hierarchical")
        }
    }

    func test_isHierarchical_false_forOtherRels() {
        for rel in ["canonical", "derived_from", "alternate", "via", "prev", "next", "preview"] {
            XCTAssertFalse(Link(rel: rel, target: "x").isHierarchical(), "expected \(rel) to NOT be hierarchical")
        }
    }

    // MARK: - Static factories (pystac: test_static_collection / child / canonical_item)

    func test_static_collection_unresolved_hrefIsNull() throws {
        let target = FakeSTAC(id: "c", selfHref: nil)
        let link = Link.collection(target)
        let dict = try jsonObject(link)
        XCTAssertEqual(dict["rel"] as? String, "collection")
        XCTAssertEqual(dict["type"] as? String, "application/json")
        XCTAssertTrue(dict["href"] is NSNull)
    }

    func test_static_child_unresolved_hrefIsNull() throws {
        let target = FakeSTAC(id: "c", selfHref: nil)
        let link = Link.child(target)
        let dict = try jsonObject(link)
        XCTAssertEqual(dict["rel"] as? String, "child")
        XCTAssertEqual(dict["type"] as? String, "application/json")
        XCTAssertTrue(dict["href"] is NSNull)
    }

    func test_static_canonical_object_unresolved_hrefIsNull() throws {
        let target = FakeSTAC(id: "c", selfHref: nil)
        let link = Link.canonical(target)
        let dict = try jsonObject(link)
        XCTAssertEqual(dict["rel"] as? String, "canonical")
        XCTAssertEqual(dict["type"] as? String, "application/json")
        XCTAssertTrue(dict["href"] is NSNull)
    }

    // MARK: - Item link media type (pystac: test_item_link_type)

    func test_item_link_mediaType_isGeoJSON() {
        let target = FakeSTAC(id: "i", selfHref: nil)
        let link = Link.item(target)
        XCTAssertEqual(link.mediaType, "application/geo+json")
    }

    // MARK: - Auto title from resolved target (pystac: test_auto_title_when_resolved)

    func test_autoTitle_from_resolvedTarget() {
        let target = FakeSTAC(id: "c", autoTitle: "Collection Title")
        let link = Link(rel: "my rel", target: target)
        XCTAssertEqual(link.title, "Collection Title")
    }

    func test_autoTitle_explicitTitleWins() {
        let target = FakeSTAC(id: "c", autoTitle: "Collection Title")
        let link = Link(rel: "my rel", target: target, title: "Override")
        XCTAssertEqual(link.title, "Override")
    }

    func test_autoTitle_unresolvedTarget_nilByDefault() {
        let link = Link(rel: "my rel", target: "https://example.com/x")
        XCTAssertNil(link.title)
    }

    // MARK: - target getter/setter (pystac: test_target_getter_setter, simplified)

    func test_target_swap_hrefToObject_andBack() throws {
        let link = Link(rel: "my rel", target: "./foo/bar.json")
        if case .href(let h) = try link.getTarget() { XCTAssertEqual(h, "./foo/bar.json") }
        else { XCTFail("expected href target") }
        XCTAssertEqual(link.getTargetString(), "./foo/bar.json")

        let target = FakeSTAC(id: "x", selfHref: "/items/x.json")
        link.setTarget(object: target)
        if case .object(let o) = try link.getTarget() { XCTAssertTrue(o === target) }
        else { XCTFail("expected object target") }
        XCTAssertEqual(link.getTargetString(), "/items/x.json")

        link.setTarget(href: "./bar/foo.json")
        if case .href(let h) = try link.getTarget() { XCTAssertEqual(h, "./bar/foo.json") }
        else { XCTFail("expected href target") }
    }

    // MARK: - helpers

    /// Encode a link to JSON, then re-parse as a Foundation object so we can
    /// assert against `[String: Any]` shape (matching pystac's `to_dict`).
    private func jsonObject(_ link: Link) throws -> [String: Any] {
        let enc = JSONEncoder()
        enc.outputFormatting = [.withoutEscapingSlashes]
        let data = try enc.encode(link)
        let obj = try JSONSerialization.jsonObject(with: data, options: [])
        return obj as! [String: Any]
    }
}
