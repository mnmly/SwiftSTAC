import Foundation
import XCTest
@testable import SwiftSTAC

/// Locate a fixture file inside the `Fixtures/` resource bundle.
enum Fixtures {
    static func url(_ relative: String) throws -> URL {
        let comps = relative.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        let subdir = comps.dropLast().joined(separator: "/")
        let name = (comps.last as NSString?)?.deletingPathExtension ?? ""
        let ext = (comps.last as NSString?)?.pathExtension ?? ""
        let bundle = Bundle.module
        let searchSubdir = subdir.isEmpty ? "Fixtures" : "Fixtures/\(subdir)"
        guard let url = bundle.url(forResource: name, withExtension: ext, subdirectory: searchSubdir) else {
            throw XCTSkip("Fixture not found: \(relative)")
        }
        return url
    }

    static func data(_ relative: String) throws -> Data {
        try Data(contentsOf: try url(relative))
    }

    /// Parse a fixture as `[String: JSONValue]`.
    static func jsonDict(_ relative: String) throws -> [String: JSONValue] {
        let data = try Self.data(relative)
        let value = try JSONDecoder().decode(JSONValue.self, from: data)
        guard case let .object(o) = value else {
            throw NSError(domain: "Fixtures", code: 1, userInfo: [NSLocalizedDescriptionKey: "Expected JSON object"])
        }
        return o
    }
}
