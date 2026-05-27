import Foundation

/// Errors raised by SwiftSTAC. Mirrors the exception hierarchy in `pystac.errors`.
public enum STACError: Error, CustomStringConvertible, Sendable {
    /// General STAC error (invalid format, missing required info, etc.).
    case generic(String)

    /// JSON did not represent the expected STAC entity.
    case typeMismatch(id: String?, expected: String, extra: String?)

    /// A duplicate key was found while deserializing a JSON object.
    case duplicateObjectKey(String)

    /// Required property is missing from an object.
    case requiredPropertyMissing(object: String, property: String)

    /// A template string could not be converted into data.
    case templateError(String)

    /// Extension does not apply to the object it was used against.
    case extensionTypeError(String)

    /// Extension hooks already registered for an extension id.
    case extensionAlreadyExists(String)

    /// STAC object does not implement the requested extension.
    case extensionNotImplemented(String)

    /// Validation schema unavailable locally.
    case localValidation(String)

    /// Validation error.
    case validation(String)

    public var description: String {
        switch self {
        case let .generic(msg): return msg
        case let .typeMismatch(id, expected, extra):
            var msg = "JSON (id = \(id ?? "unknown")) does not represent a \(expected) instance."
            if let extra, !extra.isEmpty { msg += " \(extra)" }
            return msg
        case let .duplicateObjectKey(key): return "Duplicate object key: \(key)"
        case let .requiredPropertyMissing(obj, prop):
            return "\(obj) does not have required property \(prop)"
        case let .templateError(msg): return msg
        case let .extensionTypeError(msg): return msg
        case let .extensionAlreadyExists(msg): return msg
        case let .extensionNotImplemented(msg): return msg
        case let .localValidation(msg): return msg
        case let .validation(msg): return msg
        }
    }
}
