import GeordiVisualization
import Testing

@Suite("Shell PATH visualizer")
struct ShellPathAnalyzerTests {
  @Test("Manifest and parser preserve startup order and PATH mutations")
  func parsesDeterministicMutations() throws {
    let configuration = try ShellPathConfiguration.bundled()
    #expect(
      configuration.startupFiles.map(\.id) == [
        "zprofile", "zshrc", "bash-profile", "bashrc",
      ])

    let analysis = ShellPathAnalyzer().analyze(
      """
      export PATH="$HOME/bin:$PATH"
      source "$HOME/.tooling/path.sh"
      PATH="$PATH:/opt/example/bin"
      """,
      maximumLines: configuration.maximumLines
    )

    #expect(analysis.operations.map(\.kind) == [.prepend, .source, .append])
    #expect(
      analysis.resultingDirectories == [
        "$HOME/bin", "Inherited system PATH", "/opt/example/bin",
      ])
  }

  @Test("Replacement and unresolved variables remain explicit")
  func preservesUncertainty() {
    let analysis = ShellPathAnalyzer().analyze(
      "PATH=\"$CUSTOM/bin:/usr/bin\"",
      maximumLines: 10
    )
    #expect(analysis.operations.map(\.kind) == [.replace])
    #expect(analysis.resultingDirectories == ["$CUSTOM/bin", "/usr/bin"])
  }
}
