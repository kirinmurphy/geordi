# HAL Security and Safety Requirements

## Threat model

HAL observes sensitive system structure and may eventually offer remediation.
Its principal risks include:

- Incorrectly deleting user or shared data
- Misclassifying legitimate software
- Being tricked by symlinks or path substitution
- Exposing sensitive inventory or process information
- Privileged helper compromise
- Database tampering that changes recommendations
- Excessive permissions
- Unsafe command execution
- Supply-chain compromise

## Safety invariants

- Read-only by default.
- No automatic deletion.
- No automatic process termination or throttling.
- Unrecognized is not malicious.
- Never remove shared or ambiguous data automatically.
- Never remove protected system paths.
- Revalidate identity, path, ownership, and symlink state immediately before an
  action.
- Prefer Trash or an application-provided uninstaller.
- Show a complete action preview.
- Record authorized actions and recovery information.

## Path safety

Cleanup implementation must:

- Use canonical, validated targets.
- Reject home, root, volume roots, and broad Library directories.
- Avoid unresolved environment variables and globs.
- Refuse symlink traversal outside the approved target.
- Detect mount and filesystem boundary changes.
- Protect user-created documents by default.
- Treat shared containers as ambiguous until ownership is proven.
- Recheck targets after confirmation to reduce time-of-check/time-of-use risk.

## Code identity

HAL should record signing evidence but avoid treating signatures as a complete
security verdict. Apple signatures, third-party Team IDs, notarization,
receipts, and hashes are evidence with different meanings.

## Privilege

- Use least privilege.
- Keep privileged code minimal and isolated.
- Authenticate IPC.
- Validate every request in the privileged component.
- Never let the UI pass arbitrary shell commands or paths.
- Sign all components consistently.
- Preserve a nonprivileged operating mode.
- Add Endpoint Security or a privileged helper only after formal review.

## Command execution

Prefer native APIs. When subprocesses are necessary:

- Use fixed executables and structured arguments.
- Never invoke an interpolated shell command.
- Bound execution time and output.
- Record tool versions.
- Parse defensively.
- Treat command output as untrusted input.

## Dependencies

- Prefer Apple and Swift standard libraries.
- Minimize third-party dependencies.
- Pin and audit dependencies.
- Document why each dependency exists.
- Keep update mechanisms explicit.

## Testing

Safety tests must cover:

- Protected broad paths
- Symlinks and path races
- Shared files
- Missing targets
- Permission changes
- Malformed collector data
- Corrupted databases
- Unexpected signature changes
- Interrupted cleanup
- Recovery and audit behavior

## Reporting

Before public distribution, add a vulnerability-reporting process and supported
version policy. Do not claim antivirus, malware detection, or forensic
completeness without the evidence and operational capability to support those
claims.
