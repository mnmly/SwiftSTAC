import Foundation

/// Allowed values for the Provider `roles` field.
public enum ProviderRole: String, Sendable, Codable, CaseIterable {
    case licensor
    case producer
    case processor
    case host
}
