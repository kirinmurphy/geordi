import AppKit
import GeordiCollectors
import GeordiDataSource
import GeordiDomain
import GeordiVisualization
import SwiftUI

struct CurrentActivityView: View {
  private let metrics: [ActivityMetric] = [
    ActivityMetric(
      title: "CPU", value: "38%", context: "Docker is using the most", symbol: "cpu", tint: .orange),
    ActivityMetric(
      title: "Memory", value: "12.9 GB", context: "Pressure is normal", symbol: "memorychip",
      tint: .green),
    ActivityMetric(
      title: "Running apps", value: "5", context: "All are recognized", symbol: "app.badge",
      tint: .blue),
    ActivityMetric(
      title: "Background activity", value: "9", context: "Processes and helpers",
      symbol: "gearshape.2", tint: .cyan),
  ]

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .firstTextBaseline) {
        Label("Current activity", systemImage: "waveform.path.ecg")
          .font(.section.bold())
        Spacer()
      }
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 12)], spacing: 12) {
        ForEach(metrics) { metric in
          VStack(alignment: .leading, spacing: 7) {
            Label(metric.title, systemImage: metric.symbol)
              .font(.secondary.weight(.semibold))
              .foregroundStyle(metric.tint)
            Text(metric.value)
              .font(.section.bold())
            Text(metric.context)
              .font(.small)
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
          .padding(14)
          .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
          .overlay {
            RoundedRectangle(cornerRadius: 14).stroke(metric.tint.opacity(0.18))
          }
        }
      }
    }
  }

  private struct ActivityMetric: Identifiable {
    var id: String { title }
    let title: String
    let value: String
    let context: String
    let symbol: String
    let tint: Color
  }
}

struct WelcomePrompt: View {
  let linkAction: () -> Void
  let dismissAction: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Label("Welcome to \(AppBrand.displayName)", systemImage: "sparkles")
          .font(.section.bold())
        Spacer()
        Button(action: dismissAction) {
          Image(systemName: "xmark")
        }
        .buttonStyle(.plain)
        .hoverHighlight(hPadding: 4, vPadding: 2)
        .accessibilityLabel("Dismiss welcome")
      }
      Text(
        "\(AppBrand.displayName) explains the software and activity on a Mac while keeping observations, evidence, and uncertainty visible."
      )
      Text(
        "You are currently exploring a fictional operating system. Link your Mac when you are ready to collect a read-only application inventory."
      )
      .foregroundStyle(.secondary)
      Button("Link to your Mac", action: linkAction)
        .buttonStyle(.borderedProminent)
    }
    .padding(18)
    .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    .overlay {
      RoundedRectangle(cornerRadius: 16).stroke(Color.accentColor.opacity(0.3))
    }
    .accessibilityIdentifier("syntheticWelcomePrompt")
  }
}

struct InitialLinkOverlay: View {
  let cancelAction: () -> Void

  var body: some View {
    ZStack {
      Color.black.opacity(0.28)
        .ignoresSafeArea()

      VStack(alignment: .leading, spacing: 18) {
        HStack(spacing: 12) {
          ProgressView()
            .controlSize(.regular)
          VStack(alignment: .leading, spacing: 3) {
            Text("Linking this Mac")
              .font(.section.bold())
            Text("\(AppBrand.displayName) is building a read-only application atlas.")
              .foregroundStyle(.secondary)
          }
        }

        HStack(spacing: 8) {
          setupStage("Connect", complete: true)
          Image(systemName: "chevron.right")
          setupStage("Observe applications", active: true)
          Image(systemName: "chevron.right")
          setupStage("Build your atlas")
          Image(systemName: "chevron.right")
          setupStage("Ready")
        }
        .font(.small)

        Text(
          "\(AppBrand.displayName) is reading application bundles, signing facts, conventional related locations, current processes, and startup declarations. It will not modify applications or machine data."
        )
        .font(.secondary)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

        HStack {
          Spacer()
          Button("Cancel and keep exploring the fictional Mac", action: cancelAction)
        }
      }
      .padding(24)
      .frame(maxWidth: 620)
      .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
      .shadow(radius: 24, y: 10)
      .padding(30)
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("initialLinkOverlay")
  }

  private func setupStage(
    _ title: String,
    complete: Bool = false,
    active: Bool = false
  ) -> some View {
    Label(
      title,
      systemImage: complete ? "checkmark.circle.fill" : (active ? "circle.fill" : "circle")
    )
    .foregroundStyle(complete ? .green : (active ? Color.accentColor : .secondary))
  }
}

struct LiveCoverageNotice: View {
  let model: AppModel
  let exportAction: () -> Void
  @State private var moreInfoPresented = false

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: "checkmark.shield")
        .font(.section)
        .foregroundStyle(.green)
      VStack(alignment: .leading, spacing: 5) {
        Text("This Mac is linked")
          .font(.rowTitle)
        Text(
          "\(AppBrand.displayName) found your installed software and built a read-only map. Start exploring, or check the observation details."
        )
        .foregroundStyle(.secondary)
        if model.collectionActivity == .refresh {
          ProgressView("Checking the same read-only sources again…")
            .controlSize(.small)
        } else {
          Button("Explore installed applications") {
            model.exploreLinkedApplications()
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.small)
          HStack(spacing: 10) {
            Button("Check this Mac again") { model.refreshLiveData() }
              .buttonStyle(.bordered)
              .controlSize(.small)
            Button("Export redacted diagnostics…") {
              exportAction()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            Button("More Info") { moreInfoPresented = true }
              .buttonStyle(.bordered)
              .controlSize(.small)
            Button("Dismiss") { model.dismissLinkedCompletion() }
              .buttonStyle(.plain)
              .hoverHighlight(hPadding: 6, vPadding: 3)
              .controlSize(.small)
          }
        }
      }
      Spacer()
    }
    .padding(16)
    .background(Color.green.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
    .overlay {
      RoundedRectangle(cornerRadius: 16).stroke(Color.green.opacity(0.25))
    }
    .popover(isPresented: $moreInfoPresented) {
      CollectionHealthPanel(model: model, exportAction: exportAction)
    }
  }

  private var groupedIssues: [GroupedCollectionIssue] {
    Dictionary(
      grouping: model.scanContext.collectorRuns.flatMap(\.issues).filter {
        $0.severity != .information
      },
      by: \.summary
    )
    .map { summary, issues in
      GroupedCollectionIssue(
        summary: summary,
        severity: issues.contains { $0.severity == .error } ? .error : .warning,
        count: issues.count
      )
    }
    .sorted { $0.summary < $1.summary }
  }

  private struct GroupedCollectionIssue {
    let summary: String
    let severity: CollectionIssue.Severity
    let count: Int

    var displayText: String {
      if summary == "A persistence property list did not declare a launchd label.", count > 1 {
        return "\(count) startup property lists did not declare launchd labels."
      }
      return summary + (count > 1 ? " (\(count) occurrences)" : "")
    }
  }

  private func refreshSummary(
    result: AppModel.RefreshResult,
    completedAt: Date
  ) -> String {
    let changeSummary = result == .changed ? "Updates found." : "No displayed changes."
    let duration =
      model.lastRefreshDuration.map { String(format: "%.1f seconds", $0) } ?? "duration unavailable"
    let checkedAt = completedAt.formatted(date: .omitted, time: .shortened)
    return "Checked \(checkedAt) · \(changeSummary) · \(duration)"
  }
}
