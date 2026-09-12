import { readFile, writeFile, rename, unlink } from 'node:fs/promises'
import { validateSchema } from '../schema/validate.js'

export function validateManifest(manifest) {
  const errors = validateSchema(manifest)
  if (errors.length) throw new Error(errors.join('\n'))
  const unique = (values, key, path) => {
    const seen = new Set()
    values.forEach((v, n) => {
      if (seen.has(key(v))) errors.push(`${path}[${n}]: duplicate ${key(v)}`)
      seen.add(key(v))
    })
  }
  unique(manifest.items, i => i.id, '$.items')
  unique(manifest.items.filter(i => i.install.package), i => `${i.install.type}:${i.install.package}`, '$.items.install')
  for (const kind of ['formulae', 'casks']) unique(manifest.inventory.brew[kind], i => i.name, `$.inventory.brew.${kind}`)
  unique(manifest.inventory.apps, i => i.path, '$.inventory.apps')
  const formulaNames = new Set(manifest.inventory.brew.formulae.map(f => f.name))
  for (const [n, formula] of manifest.inventory.brew.formulae.entries()) {
    for (const dependency of formula.dependencies) {
      if (!formulaNames.has(dependency)) errors.push(`$.inventory.brew.formulae[${n}].dependencies: unknown dependency ${dependency}`)
      if (dependency === formula.name) errors.push(`$.inventory.brew.formulae[${n}].dependencies: self dependency`)
    }
  }
  const byId = new Map(manifest.items.map(i => [i.id, i]))
  const visit = (item, chain = []) => {
    if (chain.includes(item.id)) { errors.push(`$.items.${item.id}.dependsOn: cycle ${[...chain, item.id].join(' -> ')}`); return }
    for (const id of item.dependsOn ?? []) {
      if (!byId.has(id)) errors.push(`$.items.${item.id}.dependsOn: unknown dependency ${id}`)
      else if (byId.get(id).enabled === false && item.enabled !== false) errors.push(`$.items.${item.id}.dependsOn: disabled dependency ${id}`)
      else visit(byId.get(id), [...chain, item.id])
    }
  }
  manifest.items.forEach(i => visit(i))
  for (const [n, app] of manifest.inventory.apps.entries()) {
    if (app.source === 'unverified' && (!app.install || app.casks.length)) errors.push(`$.inventory.apps[${n}]: unverified apps require manual install and no casks`)
    if (app.source === 'homebrew' && (!app.casks.length || app.install)) errors.push(`$.inventory.apps[${n}]: Homebrew apps require casks and no manual install`)
    for (const name of app.casks) if (!manifest.inventory.brew.casks.some(c => c.name === name)) errors.push(`$.inventory.apps[${n}].casks: unknown cask ${name}`)
  }
  if (errors.length) throw new Error(errors.join('\n'))
  return manifest
}

export const loadManifest = async path => validateManifest(JSON.parse(await readFile(path, 'utf8')))
export const enabledItems = manifest => manifest.items.filter(item => item.enabled !== false)
export const findItem = (manifest, id) => manifest.items.find(item => item.id === id)
export async function saveInventory(path, manifest, inventory) {
  const next = validateManifest({ ...manifest, inventory })
  const text = JSON.stringify(next, null, 2) + '\n'
  if (await readFile(path, 'utf8') === text) return false
  const tmp = `${path}.${process.pid}.tmp`
  try { await writeFile(tmp, text, { flag: 'wx' }); await rename(tmp, path) }
  finally { await unlink(tmp).catch(e => { if (e.code !== 'ENOENT') throw e }) }
  return true
}
