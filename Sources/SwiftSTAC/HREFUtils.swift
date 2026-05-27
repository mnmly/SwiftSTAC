import Foundation

/// HREF (href / URL / file path) utilities.
///
/// Ported from `pystac.utils`. The functions here treat hrefs uniformly whether
/// they are local POSIX file paths or URLs with a scheme (`http`, `https`,
/// `file`, `s3`, etc.). Windows paths are not supported — pystac uses
/// `os.path.relpath` for that, which has no portable cross-platform equivalent.
public enum HREFUtils {

    /// Converts backslashes to forward slashes. POSIX style is canonical inside
    /// SwiftSTAC; mirrors `pystac.utils.make_posix_style`.
    public static func makePosixStyle(_ href: String) -> String {
        href.replacingOccurrences(of: "\\\\", with: "/")
            .replacingOccurrences(of: "\\", with: "/")
    }

    // MARK: - Parsed URL helper

    /// A simplified urlparse result that distinguishes "scheme + netloc + path"
    /// triples without losing fidelity for the operations we need.
    struct Parsed {
        var scheme: String
        var netloc: String
        var path: String
        var query: String
        var fragment: String

        var hasScheme: Bool { !scheme.isEmpty }
    }

    /// Parse an href into scheme / netloc / path / query / fragment.
    static func parse(_ href: String) -> Parsed {
        var scheme = ""
        var netloc = ""
        var rest = href
        var query = ""
        var fragment = ""

        // Fragment
        if let hashIdx = rest.firstIndex(of: "#") {
            fragment = String(rest[rest.index(after: hashIdx)...])
            rest = String(rest[..<hashIdx])
        }
        // Query
        if let qIdx = rest.firstIndex(of: "?") {
            query = String(rest[rest.index(after: qIdx)...])
            rest = String(rest[..<qIdx])
        }

        // Scheme detection: scheme://...  or scheme:opaque (rare; we treat as URL)
        // A scheme matches /^[A-Za-z][A-Za-z0-9+\-.]*:/
        if let colonIdx = rest.firstIndex(of: ":") {
            let candidate = rest[..<colonIdx]
            if let first = candidate.first, first.isLetter,
               candidate.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "+" || $0 == "-" || $0 == "." }),
               !candidate.isEmpty
            {
                let afterColon = rest.index(after: colonIdx)
                let remainder = rest[afterColon...]
                // pystac treats `scheme:\\path` and `scheme:/path` (not `scheme://`)
                // as a file path with a drive letter — see `safe_urlparse`. We do
                // the same conservatively: only treat as URL when followed by `//`.
                if remainder.hasPrefix("//") {
                    scheme = String(candidate)
                    let afterSlashes = rest.index(afterColon, offsetBy: 2)
                    let afterAuthority = rest[afterSlashes...]
                    if let slash = afterAuthority.firstIndex(of: "/") {
                        netloc = String(afterAuthority[..<slash])
                        rest = String(afterAuthority[slash...])
                    } else {
                        netloc = String(afterAuthority)
                        rest = ""
                    }
                }
                // else: leave as a path (Windows drive style fallback)
            }
        }

        return Parsed(scheme: scheme, netloc: netloc, path: rest, query: query, fragment: fragment)
    }

    static func unparse(_ p: Parsed) -> String {
        var out = ""
        if !p.scheme.isEmpty {
            out += p.scheme + "://" + p.netloc
        }
        out += p.path
        if !p.query.isEmpty { out += "?" + p.query }
        if !p.fragment.isEmpty { out += "#" + p.fragment }
        return out
    }

    // MARK: - Absolute / relative tests

    /// `true` if the href is absolute. URLs with a non-empty, non-`file` scheme
    /// are always absolute; `/vsi…` GDAL paths are treated as absolute; local
    /// paths are absolute when they start with `/`.
    public static func isAbsolute(_ href: String, startHref: String? = nil) -> Bool {
        let parsed = parse(href)
        if !parsed.scheme.isEmpty, parsed.scheme != "file" { return true }
        if parsed.path.hasPrefix("/vsi") { return true }
        let startScheme = startHref.map { parse($0).scheme } ?? ""
        let startIsLocal = startScheme.isEmpty || startScheme == "file"
        return startIsLocal && parsed.path.hasPrefix("/")
    }

    // MARK: - Absolute href construction

    /// Build an absolute href out of `sourceHref`, relative to `startHref` if
    /// necessary. If `startHref` is nil, uses the current working directory.
    public static func makeAbsolute(
        _ sourceHref: String,
        startHref: String? = nil,
        startIsDir: Bool = false
    ) -> String {
        var startIsDir = startIsDir
        let start: String
        if let startHref {
            start = makePosixStyle(startHref)
        } else {
            start = FileManager.default.currentDirectoryPath
            startIsDir = true
        }

        let source = makePosixStyle(sourceHref)
        let parsedSource = parse(source)
        let parsedStart = parse(start)

        let sourceIsURL = !parsedSource.scheme.isEmpty && parsedSource.scheme != "file"
        let startIsURL = !parsedStart.scheme.isEmpty && parsedStart.scheme != "file"
        if sourceIsURL || startIsURL {
            return absoluteURL(parsedSource: parsedSource, parsedStart: parsedStart, startIsDir: startIsDir)
        } else {
            return absolutePath(parsedSource: parsedSource, parsedStart: parsedStart, startIsDir: startIsDir)
        }
    }

    private static func absoluteURL(parsedSource: Parsed, parsedStart: Parsed, startIsDir: Bool) -> String {
        // Already absolute (scheme present) — return as-is, or /vsi path
        if !parsedSource.scheme.isEmpty || parsedSource.path.hasPrefix("/vsi") {
            return unparse(parsedSource)
        }
        let startDir: String
        if startIsDir {
            startDir = parsedStart.path.hasSuffix("/") ? parsedStart.path : parsedStart.path + "/"
        } else {
            startDir = parentDir(parsedStart.path) + "/"
        }
        let joined = urljoin(base: startDir, ref: parsedSource.path).replacingOccurrences(of: "\\", with: "/")
        var out = Parsed(
            scheme: parsedStart.scheme,
            netloc: parsedStart.netloc,
            path: joined,
            query: parsedSource.query,
            fragment: parsedSource.fragment
        )
        if out.scheme.isEmpty { out.scheme = parsedStart.scheme }
        return unparse(out)
    }

    private static func absolutePath(parsedSource: Parsed, parsedStart: Parsed, startIsDir: Bool) -> String {
        if parsedSource.path.hasPrefix("/") {
            return unparse(parsedSource)
        }
        let startDir = startIsDir ? parsedStart.path : parentDir(parsedStart.path)
        let joined = normalize(joining: startDir, parsedSource.path)
        if !parsedSource.scheme.isEmpty || !parsedStart.scheme.isEmpty {
            return "file://" + joined
        }
        return joined
    }

    // MARK: - Relative href construction

    /// Build a relative href representing `sourceHref` relative to `startHref`.
    /// If they don't share a scheme/netloc, returns `sourceHref` unchanged.
    public static func makeRelative(
        _ sourceHref: String,
        startHref: String,
        startIsDir: Bool = false
    ) -> String {
        let source = makePosixStyle(sourceHref)
        let start = makePosixStyle(startHref)
        let parsedSource = parse(source)
        let parsedStart = parse(start)

        guard parsedSource.scheme == parsedStart.scheme,
              parsedSource.netloc == parsedStart.netloc else {
            return source
        }
        return relativePath(parsedSource: parsedSource, parsedStart: parsedStart, startIsDir: startIsDir)
    }

    private static func relativePath(parsedSource: Parsed, parsedStart: Parsed, startIsDir: Bool) -> String {
        var startDir = startIsDir ? parsedStart.path : parentDir(parsedStart.path)
        startDir = trimLeadingSlashes(startDir)
        let sourcePath = trimLeadingSlashes(parsedSource.path)

        let rel = relpath(target: sourcePath, base: startDir)
        var out = rel
        if parsedSource.path.hasSuffix("/"), !out.hasSuffix("/") {
            out += "/"
        }
        if out != "./" && !out.hasPrefix("../") {
            out = "./" + out
        }
        return out
    }

    // MARK: - POSIX path manipulation

    /// POSIX `dirname` analogue. Returns the parent directory of a path string,
    /// dropping the final component.
    public static func parentDir(_ path: String) -> String {
        if path.isEmpty { return "" }
        if let idx = path.lastIndex(of: "/") {
            // Preserve the root "/"
            if idx == path.startIndex { return "/" }
            return String(path[..<idx])
        }
        return ""
    }

    static func trimLeadingSlashes(_ s: String) -> String {
        var idx = s.startIndex
        while idx < s.endIndex && s[idx] == "/" { idx = s.index(after: idx) }
        return String(s[idx...])
    }

    /// Compute a relative path from `base` to `target` using POSIX semantics.
    static func relpath(target: String, base: String) -> String {
        let targetParts = splitPath(target)
        let baseParts = splitPath(base)
        var common = 0
        while common < targetParts.count, common < baseParts.count, targetParts[common] == baseParts[common] {
            common += 1
        }
        var parts: [String] = []
        if common < baseParts.count {
            parts.append(contentsOf: Array(repeating: "..", count: baseParts.count - common))
        }
        parts.append(contentsOf: targetParts[common...])
        if parts.isEmpty { return "." }
        return parts.joined(separator: "/")
    }

    static func splitPath(_ s: String) -> [String] {
        s.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
    }

    /// Normalize `base/ref` against `..` and `.` segments. Behaves like
    /// `posixpath.normpath(os.path.join(base, ref))`.
    static func normalize(joining base: String, _ ref: String) -> String {
        let joined: String
        if ref.hasPrefix("/") {
            joined = ref
        } else if base.isEmpty {
            joined = ref
        } else if base.hasSuffix("/") {
            joined = base + ref
        } else {
            joined = base + "/" + ref
        }
        let absolute = joined.hasPrefix("/")
        var stack: [String] = []
        for part in joined.split(separator: "/", omittingEmptySubsequences: true) {
            if part == "." { continue }
            if part == ".." {
                if let last = stack.last, last != ".." { stack.removeLast() }
                else if !absolute { stack.append("..") }
            } else {
                stack.append(String(part))
            }
        }
        let joinedNorm = stack.joined(separator: "/")
        if absolute { return "/" + joinedNorm }
        return joinedNorm.isEmpty ? "." : joinedNorm
    }

    /// Minimal RFC 3986 `urljoin` for the subset of behavior pystac relies on.
    /// Handles: absolute ref returns ref; otherwise normalizes against the
    /// directory of the base path.
    static func urljoin(base: String, ref: String) -> String {
        if ref.hasPrefix("/") { return normalize(joining: "", ref) }
        if ref.isEmpty { return base }
        let baseDir: String
        if base.hasSuffix("/") {
            baseDir = base
        } else if let slash = base.lastIndex(of: "/") {
            baseDir = String(base[...slash])
        } else {
            baseDir = ""
        }
        return normalize(joining: baseDir, ref)
    }

    // MARK: - Datetime

    /// Convert a `Date` to an RFC 3339 string with millisecond precision and a
    /// trailing `Z`. Matches `datetime_to_str(dt)` for the common timespec.
    public static func datetimeToString(_ date: Date) -> String {
        ISO8601Formatters.shared.format(date)
    }

    /// Parse an RFC 3339 / ISO 8601 string into a `Date`.
    public static func stringToDate(_ s: String) -> Date? {
        ISO8601Formatters.shared.parse(s)
    }

    public static func nowInUTC() -> Date { Date() }

    public static func nowToRFC3339() -> String { datetimeToString(nowInUTC()) }
}

/// Lock-guarded `ISO8601DateFormatter` cache. `ISO8601DateFormatter` is
/// documented thread-safe for parse/format, but the type itself isn't
/// `Sendable`, so we explicitly serialize access to keep strict
/// concurrency happy without ceremony at the call site.
private final class ISO8601Formatters: @unchecked Sendable {
    static let shared = ISO8601Formatters()

    private let lock = NSLock()
    private let withFraction: ISO8601DateFormatter
    private let noFraction: ISO8601DateFormatter

    private init() {
        let f1 = ISO8601DateFormatter()
        f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.withFraction = f1
        let f2 = ISO8601DateFormatter()
        f2.formatOptions = [.withInternetDateTime]
        self.noFraction = f2
    }

    func format(_ date: Date) -> String {
        lock.lock(); defer { lock.unlock() }
        return withFraction.string(from: date)
    }

    func parse(_ s: String) -> Date? {
        lock.lock(); defer { lock.unlock() }
        if let d = withFraction.date(from: s) { return d }
        return noFraction.date(from: s)
    }
}

extension HREFUtils {
    // MARK: - Misc

    /// True if the href has a file extension on its path. Mirrors
    /// `pystac.utils.is_file_path` (no filesystem touch).
    public static func isFilePath(_ href: String) -> Bool {
        let parsed = parse(href)
        let path = parsed.path
        guard let lastSlash = path.lastIndex(of: "/") else {
            return path.contains(".")
        }
        let basename = path[path.index(after: lastSlash)...]
        return basename.contains(".")
    }

    /// True if the href is a URL (scheme other than "" or "file").
    public static func isURL(_ href: String) -> Bool {
        let scheme = parse(href).scheme
        return !scheme.isEmpty && scheme != "file"
    }
}
