import Foundation
import JSONSchema

public enum DeclarativeManifestValidator {
  public static func validate(instance: Data, against schema: Data) throws {
    do {
      let schemaText = String(decoding: schema, as: UTF8.self)
      let instanceText = String(decoding: instance, as: UTF8.self)
      let compiledSchema = try Schema(instance: schemaText)
      let result = try compiledSchema.validate(instance: instanceText)
      guard result.isValid else {
        throw ManifestValidationError.invalid(String(describing: result.errors))
      }
    } catch let error as ManifestValidationError {
      throw error
    } catch {
      throw ManifestValidationError.invalid(String(describing: error))
    }
  }
}

public struct BundledManifestResource<Manifest: Decodable> {
  public let manifestName: String
  public let schemaName: String
  public let bundle: Bundle

  public init(
    manifestName: String,
    schemaName: String,
    bundle: Bundle
  ) {
    self.manifestName = manifestName
    self.schemaName = schemaName
    self.bundle = bundle
  }

  public func load(
    decoder: JSONDecoder = JSONDecoder(),
    validateSemantics: (Manifest) throws -> Void = { _ in }
  ) throws -> Manifest {
    guard
      let manifestURL = bundle.url(forResource: manifestName, withExtension: "json"),
      let schemaURL = bundle.url(forResource: schemaName, withExtension: "json")
    else {
      throw BundledManifestResourceError.resourceUnavailable(
        manifest: manifestName,
        schema: schemaName
      )
    }
    do {
      let rawData = try Data(contentsOf: manifestURL)
      let data =
        manifestName == ProductBrand.manifestName
        ? rawData
        : try ProductBrand.current.expandingTokens(in: rawData)
      let rawSchema = try Data(contentsOf: schemaURL)
      let schema =
        schemaName == "product-brand.schema"
        ? rawSchema
        : try ProductBrand.current.expandingTokens(in: rawSchema)
      try DeclarativeManifestValidator.validate(instance: data, against: schema)
      let manifest = try decoder.decode(Manifest.self, from: data)
      try validateSemantics(manifest)
      return manifest
    } catch let error as BundledManifestResourceError {
      throw error
    } catch {
      throw BundledManifestResourceError.invalid(
        manifest: manifestName,
        diagnostic: String(describing: error)
      )
    }
  }

  public func schemaData() throws -> Data {
    guard let schemaURL = bundle.url(forResource: schemaName, withExtension: "json") else {
      throw BundledManifestResourceError.resourceUnavailable(
        manifest: manifestName,
        schema: schemaName
      )
    }
    return try Data(contentsOf: schemaURL)
  }
}

public enum BundledManifestResourceError: Error, Equatable, Sendable {
  case resourceUnavailable(manifest: String, schema: String)
  case invalid(manifest: String, diagnostic: String)
}

extension BundledManifestResourceError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .resourceUnavailable(let manifest, let schema):
      "Required bundled manifest \(manifest).json or schema \(schema).json is unavailable."
    case .invalid(let manifest, let diagnostic):
      "Bundled manifest \(manifest).json is invalid: \(diagnostic)"
    }
  }
}

public enum ManifestValidationError: Error, Equatable, Sendable {
  case invalid(String)
}
