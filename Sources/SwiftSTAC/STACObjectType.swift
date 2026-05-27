import Foundation

/// The "type" discriminator for a STAC document at the top level.
public enum STACObjectType: String, Sendable, Codable, CaseIterable {
    case catalog = "Catalog"
    case collection = "Collection"
    case item = "Feature"
}
