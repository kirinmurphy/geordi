import { fileURLToPath } from 'node:url'
export const help = `Usage: geordi setup mac [item] [options]
  mac / no arguments     Preview missing defaults and recorded inventory
  --check                Read-only status; exit 1 for missing items or brew drift
  --json                 Read-only JSON status (never installs or syncs)
  --apply                Install missing items after confirmation
  --yes                  Confirm --apply in scripts (required without a TTY)
  --sync                 Refresh inventory from installed Homebrew + app metadata
  --manifest PATH        Use another schema-v2 manifest
  --help                 Show help
Internal aliases: check, list, validate, sync; install is still preview without --apply.
Exit codes: 0 success/preview, 1 drift/missing/declined, 2 invalid input or operation failure.`
export function parseArgs(args) {
  const options = { command: 'mac', manifestPath: fileURLToPath(new URL('../manifest.json', import.meta.url)) }
  const words = []
  for (let n = 0; n < args.length; n++) {
    const arg = args[n]
    if (arg === '--manifest' || arg.startsWith('--manifest=')) {
      const value = arg === '--manifest' ? args[++n] : arg.slice('--manifest='.length)
      if (!value || value.startsWith('--')) throw new Error('--manifest requires a path')
      options.manifestPath = value
    } else if (['--help', '--check', '--json', '--apply', '--yes', '--sync'].includes(arg)) options[arg.slice(2)] = true
    else if (arg.startsWith('-')) throw new Error(`Unknown option: ${arg}`)
    else words.push(arg)
  }
  if (['mac', 'check', 'list', 'validate', 'sync', 'install'].includes(words[0])) options.command = words.shift()
  if (words.length > 1) throw new Error('Only one item target is supported')
  options.target = words[0]
  if (options.command === 'check') options.check = true
  if (options.command === 'sync') options.sync = true
  if (options.json && (options.apply || options.sync)) throw new Error('--json is read-only; cannot combine with --apply or --sync')
  if (options.sync && (options.apply || options.check || options.yes || options.target)) throw new Error('--sync cannot combine with apply/check/yes or an item target')
  if (options.apply && options.check) throw new Error('--apply cannot combine with --check')
  if (options.yes && !options.apply) throw new Error('--yes requires --apply')
  if (['list', 'validate'].includes(options.command) && (options.apply || options.sync || options.check || options.target)) throw new Error('Invalid options for list/validate')
  return options
}
