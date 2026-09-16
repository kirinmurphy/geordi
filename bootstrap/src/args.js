import { fileURLToPath } from 'node:url'
import { defaultMachineManifestPath } from './paths.js'
export const help = `Usage: geordi setup mac [item] [options]
  mac / no arguments     Preview missing registered defaults and recorded inventory
  --check                Read-only status; exit 1 for missing items or brew drift
  --json                 Read-only JSON status (never installs or syncs)
  --apply                Install missing items after confirmation
  --yes                  Confirm --apply in scripts (required without a TTY)
  --sync                 Refresh inventory from installed Homebrew + app metadata
  migrate                One-time split of a legacy combined manifest into
                         catalog + machine manifest; requires --legacy PATH
  --legacy PATH          Legacy schema-v2 manifest to migrate (default: the
                         bundled manifest.json)
  --force                Replace an existing machine manifest during migrate
  --manifest PATH        Use another machine manifest
  --help                 Show help
Internal aliases: check, list, validate, sync; install is still preview without --apply.
Exit codes: 0 success/preview, 1 drift/missing/declined, 2 invalid input or operation failure.`
export async function parseArgs(args, env = process.env) {
  const options = { command: 'mac', manifestPath: await defaultMachineManifestPath(env),
    legacyPath: fileURLToPath(new URL('../manifest.json', import.meta.url)) }
  const words = []
  for (let n = 0; n < args.length; n++) {
    const arg = args[n]
    if (arg === '--manifest' || arg.startsWith('--manifest=')) {
      const value = arg === '--manifest' ? args[++n] : arg.slice('--manifest='.length)
      if (!value || value.startsWith('--')) throw new Error('--manifest requires a path')
      options.manifestPath = value
    } else if (arg === '--legacy' || arg.startsWith('--legacy=')) {
      const value = arg === '--legacy' ? args[++n] : arg.slice('--legacy='.length)
      if (!value || value.startsWith('--')) throw new Error('--legacy requires a path')
      options.legacyPath = value
    } else if (['--help', '--check', '--json', '--apply', '--yes', '--sync', '--force'].includes(arg)) options[arg.slice(2)] = true
    else if (arg.startsWith('-')) throw new Error(`Unknown option: ${arg}`)
    else words.push(arg)
  }
  if (['mac', 'check', 'list', 'validate', 'sync', 'install', 'migrate'].includes(words[0])) options.command = words.shift()
  if (words.length > 1) throw new Error('Only one item target is supported')
  options.target = words[0]
  if (options.command === 'check') options.check = true
  if (options.command === 'sync') options.sync = true
  if (options.command === 'migrate') options.migrate = true
  if (options.json && (options.apply || options.sync || options.migrate)) throw new Error('--json is read-only; cannot combine with --apply, --sync, or migrate')
  if (options.sync && (options.apply || options.check || options.yes || options.target || options.migrate)) throw new Error('--sync cannot combine with apply/check/yes or an item target')
  if (options.apply && options.check) throw new Error('--apply cannot combine with --check')
  if (options.yes && !options.apply && !options.migrate) throw new Error('--yes requires --apply or migrate')
  if (options.migrate && (options.apply || options.check || options.sync || options.target)) throw new Error('migrate cannot combine with apply/check/sync or an item target')
  if (options.command !== 'migrate' && options.force) throw new Error('--force requires migrate')
  if (['list', 'validate'].includes(options.command) && (options.apply || options.sync || options.check || options.target)) throw new Error('Invalid options for list/validate')
  return options
}
