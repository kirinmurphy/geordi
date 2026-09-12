import Foundation
import Testing

@testable import GeordiManifestKit

@Test func bundledProductBrandIsValidAndExpandsManifestCopy() throws {
  let brand = ProductBrand.current

  #expect(!brand.displayName.isEmpty)
  #expect(!brand.dataDirectoryName.isEmpty)

  let expanded = try brand.expandingTokens(
    in: Data("{\"message\":\"Hello, {{productName}}\"}".utf8)
  )
  #expect(
    String(decoding: expanded, as: UTF8.self)
      == "{\"message\":\"Hello, \(brand.displayName)\"}"
  )
}
