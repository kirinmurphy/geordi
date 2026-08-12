import HALVisualization
import SwiftUI

/// \(AppBrand.displayName)'s complete semantic type scale. Views should use these roles instead of
/// selecting raw point sizes or SwiftUI's smaller caption variants.
extension Font {
  static let halDisplay: Font = .system(size: HALTypeSize.display)
  static let halTitle: Font = .system(size: HALTypeSize.twoXL)
  static let halSection: Font = .system(size: HALTypeSize.xl)
  static let halSubsection: Font = .system(size: HALTypeSize.large)
  static let halRowTitle: Font = .system(size: HALTypeSize.large)
  static let halBody: Font = .system(size: HALTypeSize.base)
  static let halSecondary: Font = .system(size: HALTypeSize.base)

  /// The minimum text size used by \(AppBrand.displayName). Footnote is intentionally larger than
  /// the caption and caption2 styles previously used for secondary copy.
  static let halSmall: Font = .system(size: HALTypeSize.sm)
}
