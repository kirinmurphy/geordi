import GeordiVisualization
import SwiftUI

/// \(AppBrand.displayName)'s complete semantic type scale. Views should use these roles instead of
/// selecting raw point sizes or SwiftUI's smaller caption variants.
extension Font {
  static let display: Font = .system(size: TypeSize.display)
  static let heading: Font = .system(size: TypeSize.twoXL)
  static let section: Font = .system(size: TypeSize.xl)
  static let subsection: Font = .system(size: TypeSize.large)
  static let rowTitle: Font = .system(size: TypeSize.large)
  static let paragraph: Font = .system(size: TypeSize.base)
  static let secondary: Font = .system(size: TypeSize.base)

  /// The minimum text size used by \(AppBrand.displayName). Footnote is intentionally larger than
  /// the caption and caption2 styles previously used for secondary copy.
  static let small: Font = .system(size: TypeSize.sm)
}
