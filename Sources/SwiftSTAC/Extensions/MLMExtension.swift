import Foundation

/// Machine Learning Model (MLM) STAC extension. Mirrors
/// `pystac.extensions.mlm`.
///
/// The MLM schema is large; this port surfaces the top-level model metadata
/// fields and exposes `inputs`, `outputs`, and `hyperparameters` as
/// property-bag JSON. Add typed wrappers for those sub-objects as needed.

public enum MLMAcceleratorType: String, Sendable, Codable {
    case amd64, cuda, xla, ampleMTL = "amd-ml", tpu, mps, rocm, npu
}

public struct MLMExtension: STACExtension, PropertiesExtensionAccessor {
    public static let schemaURIPattern = "https://stac-extensions.github.io/mlm/v{version}/schema.json"
    public static let schemaURI = "https://stac-extensions.github.io/mlm/v1.4.0/schema.json"
    public static let prefix = "mlm:"

    public let host: ExtensionHost
    public init(_ item: Item) { self.host = .item(item) }
    public init(_ asset: Asset) { self.host = .asset(asset) }

    // MARK: - Property constants

    public static let nameProp = prefix + "name"
    public static let architectureProp = prefix + "architecture"
    public static let tasksProp = prefix + "tasks"
    public static let frameworkProp = prefix + "framework"
    public static let frameworkVersionProp = prefix + "framework_version"
    public static let memorySizeProp = prefix + "memory_size"
    public static let totalParametersProp = prefix + "total_parameters"
    public static let pretrainedProp = prefix + "pretrained"
    public static let pretrainedSourceProp = prefix + "pretrained_source"
    public static let batchSizeSuggestionProp = prefix + "batch_size_suggestion"
    public static let acceleratorProp = prefix + "accelerator"
    public static let acceleratorConstrainedProp = prefix + "accelerator_constrained"
    public static let acceleratorSummaryProp = prefix + "accelerator_summary"
    public static let acceleratorCountProp = prefix + "accelerator_count"
    public static let inputProp = prefix + "input"
    public static let outputProp = prefix + "output"
    public static let hyperparametersProp = prefix + "hyperparameters"
    public static let artifactTypeProp = prefix + "artifact_type"
    public static let compileMethodProp = prefix + "compile_method"
    public static let entrypointProp = prefix + "entrypoint"

    // MARK: - Top-level fields

    public var name: String? {
        get { get(Self.nameProp)?.stringValue }
        nonmutating set { set(Self.nameProp, newValue.map(JSONValue.string)); registerSchema(Self.schemaURI) }
    }
    public var architecture: String? {
        get { get(Self.architectureProp)?.stringValue }
        nonmutating set { set(Self.architectureProp, newValue.map(JSONValue.string)); registerSchema(Self.schemaURI) }
    }
    public var tasks: [String]? {
        get {
            guard case let .array(arr)? = get(Self.tasksProp) else { return nil }
            return arr.compactMap { $0.stringValue }
        }
        nonmutating set {
            set(Self.tasksProp, newValue.map { .array($0.map(JSONValue.string)) })
            registerSchema(Self.schemaURI)
        }
    }
    public var framework: String? {
        get { get(Self.frameworkProp)?.stringValue }
        nonmutating set { set(Self.frameworkProp, newValue.map(JSONValue.string)); registerSchema(Self.schemaURI) }
    }
    public var frameworkVersion: String? {
        get { get(Self.frameworkVersionProp)?.stringValue }
        nonmutating set { set(Self.frameworkVersionProp, newValue.map(JSONValue.string)); registerSchema(Self.schemaURI) }
    }
    public var memorySize: Int64? {
        get { get(Self.memorySizeProp)?.intValue }
        nonmutating set { set(Self.memorySizeProp, newValue.map(JSONValue.int)); registerSchema(Self.schemaURI) }
    }
    public var totalParameters: Int64? {
        get { get(Self.totalParametersProp)?.intValue }
        nonmutating set { set(Self.totalParametersProp, newValue.map(JSONValue.int)); registerSchema(Self.schemaURI) }
    }
    public var pretrained: Bool? {
        get { get(Self.pretrainedProp)?.boolValue }
        nonmutating set { set(Self.pretrainedProp, newValue.map(JSONValue.bool)); registerSchema(Self.schemaURI) }
    }
    public var pretrainedSource: String? {
        get { get(Self.pretrainedSourceProp)?.stringValue }
        nonmutating set { set(Self.pretrainedSourceProp, newValue.map(JSONValue.string)); registerSchema(Self.schemaURI) }
    }
    public var batchSizeSuggestion: Int? {
        get { get(Self.batchSizeSuggestionProp)?.intValue.map(Int.init) }
        nonmutating set { set(Self.batchSizeSuggestionProp, newValue.map { .int(Int64($0)) }); registerSchema(Self.schemaURI) }
    }
    public var accelerator: String? {
        get { get(Self.acceleratorProp)?.stringValue }
        nonmutating set { set(Self.acceleratorProp, newValue.map(JSONValue.string)); registerSchema(Self.schemaURI) }
    }
    public var acceleratorConstrained: Bool? {
        get { get(Self.acceleratorConstrainedProp)?.boolValue }
        nonmutating set { set(Self.acceleratorConstrainedProp, newValue.map(JSONValue.bool)); registerSchema(Self.schemaURI) }
    }
    public var acceleratorSummary: String? {
        get { get(Self.acceleratorSummaryProp)?.stringValue }
        nonmutating set { set(Self.acceleratorSummaryProp, newValue.map(JSONValue.string)); registerSchema(Self.schemaURI) }
    }
    public var acceleratorCount: Int? {
        get { get(Self.acceleratorCountProp)?.intValue.map(Int.init) }
        nonmutating set { set(Self.acceleratorCountProp, newValue.map { .int(Int64($0)) }); registerSchema(Self.schemaURI) }
    }

    /// Model inputs. Each input is a property bag (see the MLM spec); kept as
    /// JSONValue arrays for portability — typed wrappers can be layered on.
    public var input: [JSONValue]? {
        get { if case let .array(arr)? = get(Self.inputProp) { return arr }; return nil }
        nonmutating set { set(Self.inputProp, newValue.map(JSONValue.array)); registerSchema(Self.schemaURI) }
    }

    /// Model outputs (analogous to `input`).
    public var output: [JSONValue]? {
        get { if case let .array(arr)? = get(Self.outputProp) { return arr }; return nil }
        nonmutating set { set(Self.outputProp, newValue.map(JSONValue.array)); registerSchema(Self.schemaURI) }
    }

    /// Model hyperparameters.
    public var hyperparameters: [String: JSONValue]? {
        get {
            if case let .object(o)? = get(Self.hyperparametersProp) { return o }
            return nil
        }
        nonmutating set { set(Self.hyperparametersProp, newValue.map(JSONValue.object)); registerSchema(Self.schemaURI) }
    }

    // MARK: - Asset-only

    public var artifactType: String? {
        get { get(Self.artifactTypeProp)?.stringValue }
        nonmutating set { set(Self.artifactTypeProp, newValue.map(JSONValue.string)); registerSchema(Self.schemaURI) }
    }
    public var compileMethod: String? {
        get { get(Self.compileMethodProp)?.stringValue }
        nonmutating set { set(Self.compileMethodProp, newValue.map(JSONValue.string)); registerSchema(Self.schemaURI) }
    }
    public var entrypoint: String? {
        get { get(Self.entrypointProp)?.stringValue }
        nonmutating set { set(Self.entrypointProp, newValue.map(JSONValue.string)); registerSchema(Self.schemaURI) }
    }
}
public extension Item { var mlm: MLMExtension { MLMExtension(self) } }
public extension Asset { var mlm: MLMExtension { MLMExtension(self) } }
