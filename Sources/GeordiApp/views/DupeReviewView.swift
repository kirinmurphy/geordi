import GeordiDomain
import SwiftUI

/// Read-only duplicate report (plan slice B): group cards over the
/// sidekick's --json output. Synthetic-first: scanning is offered only
/// when the Mac is linked. Deletion is deliberately absent — destructive
/// actions are a separately designed surface (plan decision).
struct DupeReviewView: View {
  @Bindable var model: AppModel

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      if model.isSynthetic {
        syntheticGate
      } else {
        liveScanArea
      }
    }
    .padding(20)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .accessibilityIdentifier("dupeReviewView")
  }

  private var syntheticGate: some View {
    VStack(alignment: .leading, spacing: 10) {
      Label {
        Text("Duplicate review needs this Mac")
          .font(.rowTitle.weight(.semibold))
      } icon: {
        Image(systemName: "link")
      }
      Text(
        "Duplicate review reads real files, so it is available only after linking. While \(AppBrand.displayName) is on the fictional profile, nothing on this Mac is scanned."
      )
      .font(.small)
      .foregroundStyle(.secondary)
      Button("Link this Mac") { model.linkToMac() }
        .disabled(model.isCollecting)
    }
    .padding(16)
    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
  }

  @ViewBuilder private var liveScanArea: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(spacing: 12) {
        Button("Scan for duplicates") {
          Task { await model.runDupeScan() }
        }
        .disabled(model.dupeScanState == .running)
        if case .running = model.dupeScanState {
          ProgressView()
            .controlSize(.small)
          Text("Scanning home directory (read-only)…")
            .font(.small)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Text("Read-only — nothing is deleted from this view")
          .font(.small)
          .foregroundStyle(.tertiary)
      }

      switch model.dupeScanState {
      case .idle:
        Text("Run a scan to group duplicate files by confidence.")
          .font(.small)
          .foregroundStyle(.secondary)
      case .failed(let message):
        Text(message)
          .font(.small)
          .foregroundStyle(.red)
      case .running:
        EmptyView()
      case .loaded(let document):
        loadedGroups(document)
      }
    }
  }

  @ViewBuilder private func loadedGroups(_ document: DupeScanDocument) -> some View {
    if document.groups.isEmpty {
      Text("No duplicate groups found under \(document.scanRoot).")
        .font(.small)
        .foregroundStyle(.secondary)
    } else {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          ForEach(document.tiersOrdered, id: \.tier) { section in
            tierSection(section.tier, groups: section.groups)
          }
        }
        .padding(.bottom, 20)
      }
    }
  }

  private func tierSection(_ tier: String, groups: [DupeScanDocument.Group]) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(tierLabel(tier))
        .font(.small.bold())
        .foregroundStyle(.secondary)
      ForEach(groups) { group in
        groupCard(group)
      }
    }
  }

  private func groupCard(_ group: DupeScanDocument.Group) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      ForEach(group.files) { file in
        HStack(spacing: 8) {
          Text(file.fileName)
            .font(.system(size: 13, design: .monospaced))
            .textSelection(.enabled)
          if file.temp {
            Text("TEMP")
              .font(.small.bold())
              .foregroundStyle(.orange)
          }
          Spacer()
          if let size = file.size {
            Text(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
              .font(.small)
              .foregroundStyle(.secondary)
          }
        }
        Text(file.path)
          .font(.small)
          .foregroundStyle(.tertiary)
          .textSelection(.enabled)
      }
    }
    .padding(10)
    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Duplicate group with \(group.count) files")
  }

  private func tierLabel(_ tier: String) -> String {
    switch tier {
    case "byte-identical": "Exact copies — identical bytes"
    case "same-audio-payload": "Same audio, different tags/metadata"
    case "same-name-different-bytes": "Same name, different bytes — check manually"
    default: tier
    }
  }
}
