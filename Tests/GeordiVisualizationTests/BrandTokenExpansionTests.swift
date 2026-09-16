import Foundation
import GeordiManifestKit
import GeordiVisualization
import Testing

/// {{productName}} tokens in bundled display copy must be expanded at
/// resource-load time. These tests fail if any loaded presentation
/// manifest still carries a raw template — the bug that rendered
/// "{{productName}} could not connect…" in the startup page.
@Suite("Brand token expansion")
struct BrandTokenExpansionTests {
  @Test("Bundled presentation manifests carry no raw templates")
  func bundledManifestsAreExpanded() throws {
    try assertNoTemplates(ExplorationContextConfiguration.bundled())
    try assertNoTemplates(ReferenceCatalogConfiguration.bundled())
    try assertNoTemplates(Glossary.bundled())
    try assertNoTemplates(GuidedProofConfiguration.bundled())
  }

  @Test("expandingTokens replaces the productName placeholder")
  func expansionReplacesToken() throws {
    let data = Data(#"{"text":"{{productName}} could not connect"}"#.utf8)
    let expanded = String(
      decoding: try ProductBrand.current.expandingTokens(in: data), as: UTF8.self)
    #expect(expanded.contains(ProductBrand.displayName))
    #expect(!expanded.contains("{{productName}}"))
  }

  private func assertNoTemplates(_ value: some Any) {
    let text = allStrings(of: value).joined(separator: "\n")
    #expect(!text.contains("{{"), "raw template token leaked into display copy")
  }

  /// Reflection over the decoded manifest so new string fields are
  /// covered without keeping a hand-written field list in sync.
  private func allStrings(of value: Any, depth: Int = 0) -> [String] {
    guard depth < 12 else { return [] }
    switch value {
    case let string as String: return [string]
    case let array as [Any]: return array.flatMap { allStrings(of: $0, depth: depth + 1) }
    case let dictionary as [String: Any]:
      return (dictionary.values.flatMap { allStrings(of: $0, depth: depth + 1) })
    default:
      let mirror = Mirror(reflecting: value)
      var collected: [String] = []
      for child in mirror.children {
        collected += allStrings(of: child.value, depth: depth + 1)
      }
      if let superMirror = mirror.superclassMirror {
        collected += allStrings(of: superMirror, depth: depth + 1)
      }
      return collected
    }
  }
}
