import Foundation

/// I/O abstraction for reading and writing STAC documents. Mirrors
/// `pystac.stac_io.StacIO`.
///
/// Implementations are responsible for resolving `file://`, http(s) and
/// arbitrary URI schemes to raw text. JSON parsing and STAC-object dispatch
/// are handled by the default protocol extension.
public protocol StacIO {
    /// Read text from `source`.
    func readText(_ source: String) throws -> String

    /// Write `text` to `dest`.
    func writeText(_ text: String, to dest: String) throws
}

extension StacIO {
    /// Parse JSON from a URI.
    public func readJSON(_ source: String) throws -> [String: JSONValue] {
        let text = try readText(source)
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
    public func saveJSON(_ dict: [String: JSONValue], to dest: String) throws {
        let enc = JSONEncoder()
        enc.outputFormatting = [.withoutEscapingSlashes, .prettyPrinted, .sortedKeys]
        let data = try enc.encode(JSONValue.object(dict))
        guard let s = String(data: data, encoding: .utf8) else {
            throw STACError.generic("Failed to decode encoded JSON as UTF-8")
        }
        try writeText(s, to: dest)
    }

    /// Read a STAC document and return the matching Catalog / Collection / Item.
    public func readSTACObject(_ source: String, root: Catalog? = nil) throws -> STACObject {
        let dict = try readJSON(source)
        return try stacObject(from: dict, href: source, root: root)
    }

    /// Build a STACObject from a parsed dict, with the appropriate concrete
    /// type chosen by the `type` discriminator (and `stac_version` presence).
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
/// `file://` URLs) and `http`/`https` (via synchronous URLSession). Other
/// schemes throw ``STACError/generic(_:)``.
public struct DefaultStacIO: StacIO, Sendable {

    public var headers: [String: String]
    public var urlSession: URLSession

    public init(headers: [String: String] = [:], urlSession: URLSession = .shared) {
        self.headers = headers
        self.urlSession = urlSession
    }

    public func readText(_ source: String) throws -> String {
        if HREFUtils.isURL(source) {
            return try fetchURL(source)
        }
        let path = filePath(source)
        return try String(contentsOf: URL(fileURLWithPath: path), encoding: .utf8)
    }

    public func writeText(_ text: String, to dest: String) throws {
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

    private func fetchURL(_ source: String) throws -> String {
        guard let url = URL(string: source) else {
            throw STACError.generic("Invalid URL: \(source)")
        }
        var req = URLRequest(url: url)
        for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }

        let semaphore = DispatchSemaphore(value: 0)
        var resultData: Data?
        var resultError: Error?
        var resultStatus: Int = 0

        let task = urlSession.dataTask(with: req) { data, response, error in
            resultData = data
            resultError = error
            if let http = response as? HTTPURLResponse { resultStatus = http.statusCode }
            semaphore.signal()
        }
        task.resume()
        semaphore.wait()

        if let error = resultError { throw error }
        guard let resultData else { throw STACError.generic("No data returned for \(source)") }
        if resultStatus >= 400 {
            throw STACError.generic("HTTP \(resultStatus) for \(source)")
        }
        guard let text = String(data: resultData, encoding: .utf8) else {
            throw STACError.generic("Failed to decode response as UTF-8 from \(source)")
        }
        return text
    }
}

// MARK: - StacIO.default registry

extension StacIO where Self == DefaultStacIO {
    /// Convenience for `DefaultStacIO()`.
    public static var `default`: DefaultStacIO { DefaultStacIO() }
}

/// Global default StacIO instance. Mirrors `pystac.StacIO.default()`.
public enum StacIORegistry {
    nonisolated(unsafe) private static var _default: StacIO = DefaultStacIO()

    public static func currentDefault() -> StacIO { _default }
    public static func setDefault(_ io: StacIO) { _default = io }
}
