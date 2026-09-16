import AppKit
import SwiftUI

/// Subtle rounded highlight shown while the pointer is over a control —
/// the shared hover affordance for ALL buttons, plus the pointing-hand
/// cursor. Apply to every clickable button; never to inline text links
/// (those use `hoverUnderline`).
struct HoverHighlight: ViewModifier {
  var hPadding: CGFloat = 6
  var vPadding: CGFloat = 4
  var cornerRadius: CGFloat = 6
  @State private var hovering = false

  func body(content: Content) -> some View {
    content
      .padding(.horizontal, hPadding)
      .padding(.vertical, vPadding)
      .background(
        hovering ? Color.primary.opacity(0.08) : Color.clear,
        in: RoundedRectangle(cornerRadius: cornerRadius)
      )
      .onHover { hovering = $0 }
      .pointerStyle(.link)
  }
}

/// Underline hover affordance for standalone text links (no background),
/// plus the pointing-hand cursor. Applies to Text content; use
/// `hoverHighlight` for buttons instead.
struct HoverUnderline: ViewModifier {
  @State private var hovering = false

  func body(content: Content) -> some View {
    content
      .underline(hovering)
      .onHover { hovering = $0 }
      .pointerStyle(.link)
  }
}

/// Pointing-hand cursor while the pointer is over the view — for
/// controls that already manage their own hover background (list rows,
/// selectable cards) so they get the cursor affordance without a second
/// highlight layer.
struct PointerCursor: ViewModifier {
  func body(content: Content) -> some View {
    content.pointerStyle(.link)
  }
}

extension View {
  func hoverHighlight(
    hPadding: CGFloat = 6,
    vPadding: CGFloat = 4,
    cornerRadius: CGFloat = 6
  ) -> some View {
    modifier(
      HoverHighlight(hPadding: hPadding, vPadding: vPadding, cornerRadius: cornerRadius))
  }

  func hoverUnderline() -> some View {
    modifier(HoverUnderline())
  }

  func pointerCursor() -> some View {
    modifier(PointerCursor())
  }
}
