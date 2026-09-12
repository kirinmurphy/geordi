import { detectItem, expandHome } from './detect.js'
import { enabledItems } from './manifest.js'
import { brewDrift } from './inventory.js'

export function selectItems(manifest, target) {
  const selected = [], seen = new Set()
  const visit = item => {
    if (seen.has(item.id)) return
    seen.add(item.id)
    for (const id of item.dependsOn ?? []) visit(manifest.items.find(i => i.id === id))
    selected.push(item)
  }
  if (target) {
    const item = manifest.items.find(i => i.id === target)
    if (!item) throw new Error(`Unknown item: ${target}`)
    visit(item)
  } else enabledItems(manifest).forEach(visit)
  if (target) return selected
  const packages = new Set(selected.map(i => `${i.install.type}:${i.install.package}`))
  for (const [kind, type] of [['formulae', 'brewFormula'], ['casks', 'brewCask']]) {
    for (const pkg of manifest.inventory.brew[kind]) {
      if (packages.has(`${type}:${pkg.name}`)) continue
      selected.push({ id: `${type}:${pkg.name}`, label: pkg.name, origin: 'inventory',
        detect: [], install: { type, package: pkg.name } })
    }
  }
  const paths = new Set(selected.flatMap(i => i.detect.filter(c => c.type === 'app').map(c => expandHome(c.value, process.env.HOME ?? ''))))
  for (const app of manifest.inventory.apps.filter(a => a.source === 'unverified')) {
    if (paths.has(expandHome(app.path, process.env.HOME ?? ''))) continue
    selected.push({ id: `app:${app.path}`, label: app.name, origin: 'inventory',
      detect: [{ type: 'app', value: app.path }], install: app.install })
  }
  return selected
}
export async function observeItem(item, brew, context) {
  const detected = item.detect.length ? await detectItem(item, context) : { ...item, installed: false, checks: [] }
  const kind = item.install.type === 'brewFormula' ? 'formulae' : item.install.type === 'brewCask' ? 'casks' : null
  const managed = kind ? brew[kind].some(p => p.name === item.install.package) : false
  return { ...detected, origin: item.origin ?? 'default', installed: managed || detected.installed,
    provenance: managed ? 'homebrew' : detected.installed ? 'detected-source-unverified' : 'absent' }
}
export async function buildReport(manifest, brew, target, context) {
  const results = await Promise.all(selectItems(manifest, target).map(i => observeItem(i, brew, context)))
  const drift = brewDrift(manifest.inventory.brew, brew)
  const declaredNotBrew = manifest.items.filter(i => i.install.type.startsWith('brew') &&
    !brew[i.install.type === 'brewFormula' ? 'formulae' : 'casks'].some(p => p.name === i.install.package)).map(i => i.id)
  return { mode: 'preview', summary: { total: results.length, installed: results.filter(i => i.installed).length,
    missing: results.filter(i => !i.installed).length, formulae: brew.formulae.length, casks: brew.casks.length,
    inventoryApps: manifest.inventory.apps.length }, drift, declaredNotBrew, results,
    actions: results.filter(i => !i.installed).map(i => ({ id: i.id, label: i.label, install: i.install })) }
}
