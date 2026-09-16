import SwiftUI

/// Simulated terminal block for CLI command listings: near-black screen,
/// Courier command lines, dim descriptions, optional `# GROUP` headers.
/// Shared by the CLI Actions popup (category-grouped) and the Home
/// onboarding card's success state, so both always render identically.
struct TerminalCommandList: View {
  struct Item: Identifiable {
    let id: String
    let usage: String
    let summary: String
  }

  struct Group: Identifiable {
    let id: String
    let entries: [Item]
  }

  let groups: [Group]

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
        if index > 0 {
          Divider()
            .overlay(Color.white.opacity(0.08))
            .padding(.vertical, 8)
        }
        if !group.id.isEmpty {
          Text("# \(group.id)")
            .font(.custom("Courier New", size: 12).bold())
            .foregroundStyle(Color(red: 0.42, green: 0.62, blue: 0.82))
            .padding(.bottom, 4)
        }
        ForEach(group.entries) { item in
          VStack(alignment: .leading, spacing: 2) {
            Text("$ \(item.usage)")
              .font(.custom("Courier New", size: 13).weight(.medium))
              .foregroundStyle(Color(white: 0.93))
              .textSelection(.enabled)
            Text(item.summary)
              .font(.custom("Courier New", size: 12))
              .foregroundStyle(Color(white: 0.6))
              .textSelection(.enabled)
          }
          .padding(.vertical, 3)
        }
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      Color(red: 0.07, green: 0.08, blue: 0.09),
      in: RoundedRectangle(cornerRadius: 10)
    )
    .overlay {
      RoundedRectangle(cornerRadius: 10)
        .stroke(Color.white.opacity(0.12))
    }
  }
}
