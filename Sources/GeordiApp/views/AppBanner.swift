import AppKit
import GeordiCollectors
import GeordiDataSource
import GeordiDomain
import GeordiVisualization
import SwiftUI

struct AppBanner: View {
  enum Severity {
    case success
    case info
    case warning
    case alert

    var color: Color {
      switch self {
      case .success: .green
      case .info: .blue
      case .warning: .orange
      case .alert: .red
      }
    }

    var symbol: String {
      switch self {
      case .success: "checkmark.circle.fill"
      case .info: "info.circle.fill"
      case .warning: "exclamationmark.triangle.fill"
      case .alert: "exclamationmark.octagon.fill"
      }
    }
  }

  let severity: Severity
  let title: String
  let message: String
  let allowsDismissal: Bool
  let actionTitle: String?
  let action: (() -> Void)?
  @State private var isVisible = true

  init(
    severity: Severity,
    title: String,
    message: String,
    allowsDismissal: Bool = false,
    actionTitle: String? = nil,
    action: (() -> Void)? = nil
  ) {
    self.severity = severity
    self.title = title
    self.message = message
    self.allowsDismissal = allowsDismissal
    self.actionTitle = actionTitle
    self.action = action
  }

  var body: some View {
    if isVisible {
      HStack(spacing: 10) {
        Image(systemName: severity.symbol)
          .foregroundStyle(severity.color)
        Text(title.uppercased())
          .font(.small.bold())
        Text(message)
          .font(.small)
          .foregroundStyle(.secondary)
        Spacer()
        if let actionTitle, let action {
          Button(actionTitle, action: action)
            .controlSize(.small)
        }
        if allowsDismissal {
          Button {
            withAnimation(.easeInOut(duration: 0.18)) {
              isVisible = false
            }
          } label: {
            Image(systemName: "xmark")
              .font(.small.bold())
          }
          .buttonStyle(.plain)
          .help("Dismiss notification")
          .accessibilityLabel("Dismiss \(title)")
        }
      }
      .padding(.horizontal, 14)
      .frame(maxWidth: .infinity, minHeight: 34)
      .background(severity.color.opacity(0.1))
      .overlay(alignment: .leading) {
        Rectangle()
          .fill(severity.color)
          .frame(width: 3)
      }
      .overlay(alignment: .bottom) {
        Divider()
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 5)
      .transition(.move(edge: .top).combined(with: .opacity))
      .accessibilityElement(children: .combine)
      .accessibilityLabel("\(title). \(message)")
    }
  }
}
