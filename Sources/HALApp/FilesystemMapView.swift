import HALDomain
import HALVisualization
import SwiftUI

struct FilesystemMapView: View {
  let model: AppModel
  @State private var selectedSystem = "applications"
  @State private var selectedNodeID: String?

  private var nodes: [FilesystemNode] { model.filesystemNodes }

  private var systems: [String] {
    Array(Set(nodes.map(\.system))).sorted { systemTitle($0) < systemTitle($1) }
  }

  private var systemNodes: [FilesystemNode] {
    nodes.filter { $0.system == selectedSystem }
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        VStack(alignment: .leading, spacing: 6) {
          Text("The functional anatomy of this Mac").font(.halSection.bold())
          Text(
            "Folders are evidence, not the organizing idea. Start with a computer system, learn its job, then see where your observed software and data ride through it."
          )
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        }

        systemOverview

        HStack(alignment: .top, spacing: 18) {
          VStack(alignment: .leading, spacing: 12) {
            Text(systemTitle(selectedSystem)).font(.halSection.bold())
            Text(systemExplanation(selectedSystem)).foregroundStyle(.secondary)
            ForEach(systemNodes) { node in
              locationNode(node)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)

          inspector
            .frame(minWidth: 290, idealWidth: 340, maxWidth: 400)
        }
      }
      .padding(24)
    }
    .scrollIndicators(.visible)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .accessibilityLabel("Computer systems map")
  }

  private var systemOverview: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Systems working together").font(.halSubsection.bold())
      Text(
        "Select a system. Lines converge on shared services because applications, startup behavior, caches, and personal data meet there."
      )
      .font(.halSecondary).foregroundStyle(.secondary)
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 12)], spacing: 12) {
        ForEach(systems, id: \.self) { system in
          Button {
            selectedSystem = system
            selectedNodeID = nodes.first { $0.system == system }?.id
          } label: {
            VStack(alignment: .leading, spacing: 8) {
              Image(systemName: systemSymbol(system)).font(.halSection).foregroundStyle(.blue)
              Text(systemTitle(system)).font(.halRowTitle)
              Text(systemExplanation(system)).font(.halSmall).foregroundStyle(.secondary).lineLimit(
                3)
              Text(
                "\(nodes.filter { $0.system == system && !$0.entityIDs.isEmpty }.count) observed locations"
              )
              .font(.halSmall.bold()).foregroundStyle(.blue)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
            .background(
              selectedSystem == system
                ? Color.blue.opacity(0.12) : Color(nsColor: .controlBackgroundColor),
              in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay {
              RoundedRectangle(cornerRadius: 14).stroke(
                selectedSystem == system ? .blue : .secondary.opacity(0.2))
            }
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  private func locationNode(_ node: FilesystemNode) -> some View {
    Button {
      selectedNodeID = node.id
    } label: {
      HStack(spacing: 14) {
        Image(systemName: node.symbol).font(.halSubsection).foregroundStyle(.blue).frame(width: 28)
        VStack(alignment: .leading, spacing: 4) {
          Text(node.label).font(.halRowTitle)
          Text(node.purpose).font(.halSecondary).foregroundStyle(.secondary)
          Text(node.path).font(.halSmall.monospaced()).foregroundStyle(.tertiary).lineLimit(1)
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 4) {
          Text(node.entityIDs.isEmpty ? "Reference" : "\(node.entityIDs.count) observed")
            .font(.halSmall.bold())
            .foregroundStyle(node.entityIDs.isEmpty ? Color.secondary : Color.blue)
          Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
      }
      .padding(14)
      .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
      .overlay {
        RoundedRectangle(cornerRadius: 12).stroke(
          selectedNodeID == node.id ? .blue : .secondary.opacity(0.18))
      }
    }
    .buttonStyle(.plain)
  }

  private var inspector: some View {
    let node = selectedNodeID.flatMap { id in nodes.first { $0.id == id } } ?? systemNodes.first
    return VStack(alignment: .leading, spacing: 14) {
      if let node {
        Label("ROLE IN THE SYSTEM", systemImage: node.symbol).font(.halSmall.bold())
          .foregroundStyle(.blue)
        Text(node.label).font(.halSection.bold())
        Text(node.purpose)
        PathActionMenu(path: node.path)
        Divider()
        Text("Your data riding here").font(.halRowTitle)
        if node.entityIDs.isEmpty {
          Text(
            "\(AppBrand.displayName) has no associated observation here. The location is shown to explain the system, not to claim the folder is empty."
          )
          .font(.halSecondary).foregroundStyle(.secondary)
        } else {
          ForEach(node.entityIDs, id: \.rawValue) { id in
            if let entity = model.fixture.entity(id) {
              Button {
                model.focus(entity)
              } label: {
                Label(entity.name, systemImage: entity.presentation?.symbol ?? "circle")
                  .frame(maxWidth: .infinity, alignment: .leading)
              }
              .buttonStyle(.bordered)
            }
          }
        }
      }
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    .overlay { RoundedRectangle(cornerRadius: 16).stroke(.secondary.opacity(0.2)) }
  }

  private func systemTitle(_ id: String) -> String {
    id.replacingOccurrences(of: "-", with: " ").capitalized
  }

  private func systemSymbol(_ id: String) -> String {
    switch id {
    case "platform": "lock.shield"
    case "applications": "app.badge"
    case "shared-services": "gearshape.2"
    case "personal-data": "person.crop.circle"
    case "developer-tools": "terminal"
    default: "square.grid.2x2"
    }
  }

  private func systemExplanation(_ id: String) -> String {
    switch id {
    case "platform":
      "The protected operating foundation that boots, secures, and coordinates everything else."
    case "applications": "Programs you launch, plus their bundles and identity."
    case "shared-services":
      "The connective tissue: support data, configuration, caches, and startup declarations."
    case "personal-data":
      "The user-owned environment where documents, preferences, and private app state live."
    case "developer-tools":
      "Package stores, runtimes, commands, and aliases used to build or automate work."
    default: "A functional part of the computer."
    }
  }
}
