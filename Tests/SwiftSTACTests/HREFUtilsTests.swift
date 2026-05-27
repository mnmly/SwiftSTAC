import XCTest
@testable import SwiftSTAC

/// Tests ported from `pystac/tests/test_utils.py`. The pystac suite is
/// parameterized — we expand each case into an individual XCTest assertion
/// for readability and fine-grained failure reporting.
final class HREFUtilsTests: XCTestCase {

    // MARK: - make_posix_style

    func test_makePosixStyle_replacesBackslashes() {
        XCTAssertEqual(HREFUtils.makePosixStyle("a\\b\\c"), "a/b/c")
        XCTAssertEqual(HREFUtils.makePosixStyle("a/b/c"), "a/b/c")
    }

    // MARK: - is_absolute_href

    func test_isAbsoluteHref_localPaths() {
        XCTAssertTrue(HREFUtils.isAbsolute("/a/b/c.json"))
        XCTAssertFalse(HREFUtils.isAbsolute("a/b/c.json"))
        XCTAssertFalse(HREFUtils.isAbsolute("./b/c.json"))
        XCTAssertFalse(HREFUtils.isAbsolute("../c.json"))
    }

    func test_isAbsoluteHref_urls() {
        XCTAssertTrue(HREFUtils.isAbsolute("http://example.com/a"))
        XCTAssertTrue(HREFUtils.isAbsolute("https://example.com/a"))
        XCTAssertTrue(HREFUtils.isAbsolute("s3://bucket/key"))
    }

    func test_isAbsoluteHref_vsiPath() {
        XCTAssertTrue(HREFUtils.isAbsolute("/vsizip//data/foo.zip/foo.tif"))
    }

    // MARK: - make_relative_href
    // Mirrors the parameterized cases in pystac/tests/test_utils.py.

    private func assertRelative(_ source: String, _ start: String, _ expected: String, line: UInt = #line) {
        XCTAssertEqual(HREFUtils.makeRelative(source, startHref: start), expected, line: line)
    }

    func test_makeRelative_localPaths() {
        assertRelative("/a/b/c/d/catalog.json", "/a/b/c/catalog.json", "./d/catalog.json")
        assertRelative("/a/b/catalog.json", "/a/b/c/catalog.json", "../catalog.json")
        assertRelative("/a/catalog.json", "/a/b/c/catalog.json", "../../catalog.json")
    }

    func test_makeRelative_dotfile() {
        assertRelative("/a/b/c/d/.dotfile", "/a/b/c/d/catalog.json", "./.dotfile")
    }

    func test_makeRelative_fileURLs() {
        assertRelative("file:///a/b/c/d/catalog.json", "file:///a/b/c/catalog.json", "./d/catalog.json")
    }

    func test_makeRelative_httpURLs() {
        assertRelative("http://stacspec.org/a/b/c/d/catalog.json",
                       "http://stacspec.org/a/b/c/catalog.json",
                       "./d/catalog.json")
        assertRelative("http://stacspec.org/a/b/catalog.json",
                       "http://stacspec.org/a/b/c/catalog.json",
                       "../catalog.json")
    }

    func test_makeRelative_differentSchemes_returnsSource() {
        XCTAssertEqual(
            HREFUtils.makeRelative("http://example.com/a", startHref: "/local/path"),
            "http://example.com/a"
        )
    }

    // MARK: - make_absolute_href

    func test_makeAbsolute_alreadyAbsolute() {
        XCTAssertEqual(
            HREFUtils.makeAbsolute("/a/b/c.json", startHref: "/x/y.json"),
            "/a/b/c.json"
        )
        XCTAssertEqual(
            HREFUtils.makeAbsolute("https://example.com/a", startHref: "/x/y.json"),
            "https://example.com/a"
        )
    }

    func test_makeAbsolute_relativeLocal() {
        XCTAssertEqual(
            HREFUtils.makeAbsolute("./d/catalog.json", startHref: "/a/b/c/catalog.json"),
            "/a/b/c/d/catalog.json"
        )
        XCTAssertEqual(
            HREFUtils.makeAbsolute("../catalog.json", startHref: "/a/b/c/catalog.json"),
            "/a/b/catalog.json"
        )
    }

    func test_makeAbsolute_relativeURL() {
        XCTAssertEqual(
            HREFUtils.makeAbsolute("./d/catalog.json", startHref: "http://example.com/a/b/c/catalog.json"),
            "http://example.com/a/b/c/d/catalog.json"
        )
        XCTAssertEqual(
            HREFUtils.makeAbsolute("../catalog.json", startHref: "http://example.com/a/b/c/catalog.json"),
            "http://example.com/a/b/catalog.json"
        )
    }

    // MARK: - is_file_path

    func test_isFilePath() {
        XCTAssertTrue(HREFUtils.isFilePath("foo.json"))
        XCTAssertTrue(HREFUtils.isFilePath("/a/b/c.json"))
        XCTAssertTrue(HREFUtils.isFilePath("http://example.com/foo.tif"))
        XCTAssertFalse(HREFUtils.isFilePath("/a/b/c"))
        XCTAssertFalse(HREFUtils.isFilePath("http://example.com/some/path"))
    }

    // MARK: - datetime round-trip

    func test_datetime_roundTrip() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let s = HREFUtils.datetimeToString(now)
        let parsed = try XCTUnwrap(HREFUtils.stringToDate(s))
        XCTAssertEqual(parsed.timeIntervalSince1970, now.timeIntervalSince1970, accuracy: 0.001)
    }
}
