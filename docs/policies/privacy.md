# geordi Privacy Requirements

## Default posture

geordi is local-first. Collection, analysis, storage, and visualization remain on
the Mac by default.

No account, cloud service, advertising identifier, or remote telemetry is
required for core operation.

## Potentially sensitive information

geordi may encounter:

- Application names
- File and folder names
- Usernames embedded in paths
- Process arguments
- Project names
- Recent activity
- Network destinations
- Installed security software
- Login and persistence configuration
- Resource-use patterns

Collection does not imply permission to retain or display all available data.

## Defaults

- Do not collect full process arguments unless explicitly enabled.
- Redact likely secrets, tokens, credentials, and query parameters.
- Do not inspect file contents for ordinary ownership or reclaimability.
- Do not collect network destinations in V1.
- Do not record active-window or user-interaction history in V1.
- Do not transmit hashes to third-party reputation services automatically.
- Keep raw telemetry retention short and configurable.
- Export only on explicit user action.

## Permission design

For every requested macOS permission, geordi must explain:

- What capability needs it
- What additional data becomes visible
- What remains unavailable without it
- Whether the feature can work in reduced mode
- How to revoke it

Permission prompts should occur in context, not at first launch as a blanket
request.

## Database and logs

- Store data in documented application-support locations.
- Apply retention and aggregation.
- Avoid secrets in logs.
- Provide data-size reporting.
- Provide export and delete/reset controls.
- Make schema migrations safe and testable.

## Future telemetry

Installation observation, filesystem event monitoring, process history,
network context, and user activity require separate product review. The
availability of an API is not sufficient justification for collection.

## External services

Any future reputation, update, crash-reporting, or analytics service must be:

- Optional or separately justified
- Documented
- Minimal
- Consent-aware
- Configurable
- Excluded from local-only mode
