import SwiftUI

/// HAL's complete semantic type scale. Views should use these roles instead of
/// selecting raw point sizes or SwiftUI's smaller caption variants.
extension Font {
  static let halDisplay: Font = Font.largeTitle
  static let halTitle: Font = Font.title
  static let halSection: Font = Font.title2
  static let halSubsection: Font = Font.title3
  static let halRowTitle: Font = Font.headline
  static let halBody: Font = Font.body
  static let halSecondary: Font = Font.callout

  /// The minimum text size used by HAL. Footnote is intentionally larger than
  /// the caption and caption2 styles previously used for secondary copy.
  static let halSmall: Font = Font.footnote
}
