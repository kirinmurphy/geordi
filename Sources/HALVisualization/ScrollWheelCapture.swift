import AppKit
import SwiftUI

struct ScrollWheelCapture: NSViewRepresentable {
  let onScroll: (CGSize, Bool) -> Void

  func makeNSView(context: Context) -> ScrollView {
    let view = ScrollView()
    view.onScroll = onScroll
    return view
  }

  func updateNSView(_ nsView: ScrollView, context: Context) {
    nsView.onScroll = onScroll
  }

  final class ScrollView: NSView {
    var onScroll: ((CGSize, Bool) -> Void)?

    override func scrollWheel(with event: NSEvent) {
      onScroll?(
        CGSize(width: event.scrollingDeltaX, height: event.scrollingDeltaY),
        event.modifierFlags.contains(.command)
      )
    }
  }
}
