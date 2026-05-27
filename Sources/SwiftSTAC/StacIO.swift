import Foundation

/// I/O abstraction for reading and writing STAC documents. Mirrors
/// `pystac.stac_io.StacIO` with one important difference: all operations are
/// `async throws`, so consumers integrate cleanly with structured
/// concurrency and never block a thread on I/O.
///
/// Implementations are responsible for resolving `file://`, `http(s)://`, or
/// other URI schemes to raw text. JSON parsing and STAC-object dispatch are
/// supplied by the default protocol extension.
public protocol StacIO: Sendable {
    /// Read text from `source`.
    func readText(_ source: String) async throws -> String

    /// Write `text` to `dest`.
    func writeText(_ text: String, to dest: String) async throws
}

extension StacIO {
    /// Parse JSON from a URI.
    public func readJSON(_ source: String) async throws -> [String: JSONValue] {
        let text = try await readText(source)
        guard let data = text.data(using: .utf8) else {
            throw STACError.generic("Failed to encode JSON text as UTF-8")
        }
        let value = try JSONDecoder().decode(JSONValue.self, from: data)
        guard case let .object(o) = value else {
            throw STACError.generic("Top-level JSON value is not an object")
        }
        return o
    }

    /// Encode and write a STAC dict to `dest`.
    public func saveJSON(_ dict: [String: JSONValue], to dest: String) async throws {
        let enc = JSONEncoder()
        enc.outputFormatting = [.withoutEscapingSlashes, .prettyPrinted, .sortedKeys]
        let data = try enc.encode(JSONValue.object(dict))
        guard let s = String(data: data, encoding: .utf8) else {
            throw STACError.generic("Failed to decode encoded JSON as UTF-8")
        }
        try await writeText(s, to: dest)
    }

    /// Read a STAC document and return the matching Catalog / Collection / Item.
    public func readSTACObject(_ source: String, root: Catalog? = nil) async throws -> STACObject {
        let dict = try await readJSON(source)
        return try stacObject(from: dict, href: source, root: root)
    }

    /// Build a STACObject from a parsed dict, with the appropriate concrete
    /// type chosen by the `type` discriminator.
    public func stacObject(
        from d: [String: JSONValue],
        href: String? = nil,
        root: Catalog? = nil
    ) throws -> STACObject {
        let typ = d["type"]?.stringValue
        switch typ {
        case STACObjectType.item.rawValue:
            let item = try Item.fromDict(d)
            if let href { item.setSelfHref(href) }
            if let root { item.setRoot(root) }
            return item
        case STACObjectType.collection.rawValue:
            let c = try Collection.parse(d)
            if let href { c.setSelfHref(href) }
            if let root { c.setRoot(root) }
            return c
        case STACObjectType.catalog.rawValue:
            let c = try Catalog.fromDict(d)
            if let href { c.setSelfHref(href) }
            if let root { c.setRoot(root) }
            return c
        default:
            throw STACError.typeMismatch(
                id: d["id"]?.stringValue,
                expected: "STACObject",
                extra: "Unknown 'type' \(typ ?? "<missing>")."
            )
        }
    }
}

// MARK: - Default implementation

/// Default ``StacIO`` implementation. Supports local files (including
/// `file://` URLs) and `http(s)://` URLs via `URLSession`. Other schemes
/// throw ``STACError/generic(_:)``.
public struct DefaultStacIO: StacIO, Sendable {

    public var headers: [String: String]
    public var urlSession: URLSession

    public init(headers: [String: String] = [:], urlSession: URLSession = .shared) {
        self.headers = headers
        self.urlSession = urlSession
    }

    public func readText(_ source: String) async throws -> String {
        if HREFUtils.isURL(source) {
            return try await fetchURL(source)
        }
        let path = filePath(source)
        return try String(contentsOf: URL(fileURLWithPath: path), encoding: .utf8)
    }

    public func writeText(_ text: String, to dest: String) async throws {
        if HREFUtils.isURL(dest) {
            throw STACError.generic("DefaultStacIO does not support writing to URLs (\(dest)).")
        }
        let path = filePath(dest)
        let url = URL(fileURLWithPath: path)
        let dir = url.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - Helpers

    private func filePath(_ href: String) -> String {
        if href.hasPrefix("file://") {
            return String(href.dropFirst("file://".count))
        }
        return href
    }

    private func fetchURL(_ source: String) async throws -> String {
        guard let url = URL(string: source) else {
            throw STACError.generic("Invalid URL: \(source)")
        }
        var req = URLRequest(url: url)
        for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }

        let (data, response) = try await urlSession.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            throw STACError.generic("HTTP \(http.statusCode) for \(source)")
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw STACError.generic("Failed to decode response as UTF-8 from \(source)")
        }
        return text
    }
}

// MARK: - Default-instance shorthand

extension StacIO where Self == DefaultStacIO {
    /// Shorthand for `DefaultStacIO()`. Use as a `StacIO`-typed argument
    /// default: `func foo(io: some StacIO = .default)`.
    public static var `default`: DefaultStacIO { DefaultStacIO() }
}

/// Process-wide default ``StacIO``. Backed by an actor so concurrent reads
/// and writes are safe. Mirrors `pystac.StacIO.default()`.
public actor StacIORegistry {
    private static let shared = StacIORegistry()
    private var current: any StacIO = DefaultStacIO()

    private init() {}

    /// Resolve the currently registered default.
    public static func currentDefault() async -> any StacIO {
        await shared.current
    }

    /// Override the process-wide default.
    public static func setDefault(_ io: any StacIO) async {
        await shared.set(io)
    }

    private func set(_ io: any StacIO) { self.current = io }
}
