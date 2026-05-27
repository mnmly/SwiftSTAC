import Foundation

/// Layout style of a Catalog. Mirrors `pystac.catalog.CatalogType`.
public enum CatalogType: String, Sendable, Codable, CaseIterable {
    /// Portable, all relative links.
    case selfContained = "SELF_CONTAINED"
    /// All absolute links, including assets.
    case absolutePublished = "ABSOLUTE_PUBLISHED"
    /// Relative links with an absolute self link at the root.
    case relativePublished = "RELATIVE_PUBLISHED"
}

extension CatalogType {
    /// Determine the catalog type from a parsed STAC JSON dict by inspecting
    /// the `links` array. Returns `nil` when the type cannot be determined.
    public static func determine(from d: [String: JSONValue]) -> CatalogType? {
        guard case let .array(links)? = d["links"] else { return nil }
        var hasSelf = false
        var hasRelative = false
        for link in links {
            guard case let .object(l) = link,
                  case let .string(rel)? = l["rel"] else { continue }
            if rel == RelType.`self`.rawValue {
                hasSelf = true
            } else if case let .string(href)? = l["href"], !HREFUtils.isAbsolute(href) {
                hasRelative = true
            }
        }
        switch (hasSelf, hasRelative) {
        case (true, true): return .relativePublished
        case (true, false): return .absolutePublished
        case (false, true): return .selfContained
        case (false, false): return nil
        }
    }
}
