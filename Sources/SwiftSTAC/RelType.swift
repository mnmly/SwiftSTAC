import Foundation

/// A list of common rel types that can be used in STAC Link metadata.
///
/// Mirrors `pystac.rel_type.RelType`. The raw string value should be used whenever
/// a STAC document carries a rel type outside this enumeration.
public enum RelType: String, Sendable, Codable, CaseIterable {
    case alternate
    case canonical
    case child
    case collection
    case item
    case items
    case license
    case derivedFrom = "derived_from"
    case next
    case parent
    case prev
    case preview
    case root
    case `self`
    case via
}

extension RelType {
    /// Hierarchical links that provide structure to STAC catalogs.
    public static let hierarchical: Set<RelType> = [
        .root, .child, .parent, .collection, .item, .items,
    ]
}
