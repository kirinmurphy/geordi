import { createInterface } from 'node:readline/promises'
import { stdin, stdout } from 'node:process'
import { parseArgs, help } from './args.js'
import { loadManifest, saveInventory, validateManifest, validateCatalog } from './manifest.js'
import { migrateManifest } from './migrate.js'
import { collectBrew } from './brew.js'
import { collectInventory } from './inventory.js'
import { buildReport, observeItem } from './plan.js'
import { formatReport } from './status.js'
import { installItems } from './install.js'
import { createSystemInstaller } from './installers/system.js'
import { readFile } from 'node:fs/promises'
import { fileURLToPath } from 'node:url'

export async function confirm(question, input = stdin, output = stdout) {
  const rl = createInterface({ input, output })
  try { return /^y(es)?$/i.test((await rl.question(`${question} [y/N] `)).trim()) }
  finally { rl.close() }
}
export async function authorize(options, deps = {}) {
  if (options.yes) return true
  if (!(deps.isTTY ?? stdin.isTTY)) throw new Error('--apply requires --yes when stdin is not a TTY')
  return (deps.confirm ?? confirm)('Install the missing items shown above?')
}
export async function runCli(args, deps = {}) {
  const options = await parseArgs(args, deps.env), log = deps.log ?? console.log
  if (options.help) { log(help); return 0 }
  if (options.migrate) return runMigrate(options, deps, log)
  let manifest
  try {
    manifest = validateManifest(await (deps.loadManifest ?? loadManifest)(options.manifestPath))
  } catch (error) {
    if (error?.code === 'ENOENT') {
      log(`No machine manifest found at ${options.manifestPath}. Run 'geordi setup mac migrate --yes' to split a legacy manifest, or pass --manifest PATH to an existing machine manifest.`)
      return 2
    }
    throw error
  }
  if (options.command === 'validate' || options.command === 'list') {
    log(options.json ? JSON.stringify(options.command === 'validate' ? { valid: true, schemaVersion: manifest.schemaVersion } : manifest.items, null, 2)
      : options.command === 'validate' ? `Manifest valid (schema v${manifest.schemaVersion}).` : manifest.items.map(i => `${i.id}  ${i.label}${i.enabled === false ? ' (disabled)' : ''}`).join('\n'))
    return 0
  }
  if (options.sync) {
    const inventory = await (deps.collectInventory ?? collectInventory)(manifest)
    const changed = await (deps.saveInventory ?? saveInventory)(options.manifestPath, manifest, inventory)
    log(`${changed ? 'Updated' : 'Unchanged'} inventory: ${inventory.brew.formulae.length} formulae, ${inventory.brew.casks.length} casks, ${inventory.apps.length} third-party apps (${inventory.apps.filter(a => a.source === 'unverified').length} unverified/manual).`)
    inventory.warnings.forEach(w => log(`Warning: ${w}`))
    return 0
  }
  const collect = () => (deps.collectBrew ?? collectBrew)(manifest.inventoryConfig)
  const report = await buildReport(manifest, await collect(), options.target, deps.detectContext)
  report.mode = options.check || options.json ? 'check' : options.apply ? 'apply' : 'preview'
  log(options.json ? JSON.stringify(report, null, 2) : formatReport(report))
  if (options.apply && report.actions.length) {
    if (!await authorize(options, deps)) { log('Cancelled.'); return 1 }
    const installer = deps.installer ?? createSystemInstaller(manifest.inventoryConfig)
    const observe = async item => observeItem(item, await collect(), deps.detectContext)
    const installed = await installItems(report.results, installer, observe)
    log(`Verified ${installed.length} installations. No packages removed or upgraded explicitly.`)
  }
  if (options.check || options.json) return report.summary.missing || Object.values(report.drift).some(v => v.length) ? 1 : 0
  return 0
}

async function runMigrate(options, deps, log) {
  const catalogPath = fileURLToPath(new URL('../catalog.json', import.meta.url))
  const legacyPreview = JSON.parse(await (deps.readFile ?? readFile)(options.legacyPath, 'utf8'))
  if (!await (deps.authorizeMigrate ?? authorizeMigrate)(options, deps, legacyPreview)) { log('Cancelled.'); return 1 }
  const result = await (deps.migrateManifest ?? migrateManifest)(options.legacyPath, catalogPath, options.manifestPath, { overwriteExisting: options.force })
  log(`Migrated ${result.registered} registered items to ${options.manifestPath}; catalog now has ${result.catalogTotal} definitions (${result.catalogContributed} contributed from the legacy manifest). The legacy file was left unchanged; remove it when done.`)
  return 0
}

export async function authorizeMigrate(options, deps = {}, legacyPreview) {
  if (options.yes) return true
  if (!(deps.isTTY ?? stdin.isTTY)) throw new Error('migrate requires --yes when stdin is not a TTY')
  const catalog = JSON.parse(await (deps.readFile ?? readFile)(fileURLToPath(new URL('../catalog.json', import.meta.url)), 'utf8')).catch?.(() => ({ items: [] }))
  const items = legacyPreview.items ?? []
  return (deps.confirm ?? confirm)(`Split ${items.length} items into the machine manifest and merge new definitions into the catalog?`)
}
