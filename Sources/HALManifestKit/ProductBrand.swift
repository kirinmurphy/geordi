import Foundation

/// The canonical, manifest-backed identity used in product-facing copy.
///
/// Change `Resources/product-brand.json` to rename the product. Build target,
/// module, executable, and bundle identifiers are intentionally separate stable
/// implementation identifiers.
public struct ProductBrand: Codable, Hashable, Sendable {
  public static let currentVersion = 1
  static let manifestName = "product-brand"

  public let schemaVersion: Int
  public let displayName: String
  public let dataDirectoryName: String

  public static var displayName: String { current.displayName }
  public static var dataDirectoryName: String { current.dataDirectoryName }

  public static let current: Self = {
    do {
      return try BundledManifestResource<Self>(
        manifestName: manifestName,
        schemaName: "product-brand.schema",
        bundle: .module
      ).load { brand in
        guard brand.schemaVersion == currentVersion else {
          throw ProductBrandError.unsupportedVersion(brand.schemaVersion)
        }
      }
    } catch {
      preconditionFailure("Required product brand failed validation: \(error)")
    }
  }()

  public func expandingTokens(in data: Data) throws -> Data {
    guard var text = String(data: data, encoding: .utf8) else {
      throw ProductBrandError.nonUTF8Manifest
    }
    text = text.replacingOccurrences(of: "{{productName}}", with: displayName)
    return Data(text.utf8)
  }
}

public enum ProductBrandError: Error, Equatable, Sendable {
  case unsupportedVersion(Int)
  case nonUTF8Manifest
}
