import { readFile, writeFile, rename, unlink } from 'node:fs/promises'
import { validateSchema } from '../schema/validate.js'
import machineSchema from '../schema/machine-v3.schema.json' with { type: 'json' }
import catalogSchema from '../schema/catalog-v1.schema.json' with { type: 'json' }
import legacySchema from '../schema/manifest-v2.schema.json' with { type: 'json' }

export const machineManifestSchema = machineSchema
export const catalogManifestSchema = catalogSchema
export const legacyManifestSchema = legacySchema

// Generic schema-backed validation over the constrained interpreter. Schemas
// are the sole structural contract; code adds only semantic checks JSON Schema
// cannot express (repository central-schema rule).
export function validateAgainst(schema, value) {
  const errors = validateSchema(value, schema)
  if (errors.length) throw new Error(errors.join('\n'))
  return value
}

// Semantic checks shared by catalog and machine manifest: unique ids and
// installer targets, resolvable acyclic dependsOn edges, no enabled item
// depending on a disabled one.
const itemSemanticErrors = (items, path) => {
  const errors = []
  const unique = (values, key, label) => {
    const seen = new Set()
    values.forEach((v, n) => {
      if (seen.has(key(v))) errors.push(`${path}.items[${n}]: duplicate ${label}`)
      seen.add(key(v))
    })
  }
  unique(items, i => i.id, 'item id')
  unique(items.filter(i => i.install.package), i => `${i.install.type}:${i.install.package}`, 'install target')
  const byId = new Map(items.map(i => [i.id, i]))
  const visit = (item, chain = []) => {
    if (chain.includes(item.id)) { errors.push(`${path}.items.${item.id}.dependsOn: cycle ${[...chain, item.id].join(' -> ')}`); return }
    for (const id of item.dependsOn ?? []) {
      if (!byId.has(id)) errors.push(`${path}.items.${item.id}.dependsOn: unknown dependency ${id}`)
      else if (byId.get(id).enabled === false && item.enabled !== false) errors.push(`${path}.items.${item.id}.dependsOn: disabled dependency ${id}`)
      else visit(byId.get(id), [...chain, item.id])
    }
  }
  items.forEach(i => visit(i))
  return errors
}

const inventorySemanticErrors = manifest => {
  const errors = []
  const unique = (values, key, path) => {
    const seen = new Set()
    values.forEach((v, n) => {
      if (seen.has(key(v))) errors.push(`${path}[${n}]: duplicate ${key(v)}`)
      seen.add(key(v))
    })
  }
  for (const kind of ['formulae', 'casks']) unique(manifest.inventory.brew[kind], i => i.name, `$.inventory.brew.${kind}`)
  unique(manifest.inventory.apps, i => i.path, '$.inventory.apps')
  const formulaNames = new Set(manifest.inventory.brew.formulae.map(f => f.name))
  for (const [n, formula] of manifest.inventory.brew.formulae.entries()) {
    for (const dependency of formula.dependencies) {
      if (!formulaNames.has(dependency)) errors.push(`$.inventory.brew.formulae[${n}].dependencies: unknown dependency ${dependency}`)
      if (dependency === formula.name) errors.push(`$.inventory.brew.formulae[${n}].dependencies: self dependency`)
    }
  }
  for (const [n, app] of manifest.inventory.apps.entries()) {
    if (app.source === 'unverified' && (!app.install || app.casks.length)) errors.push(`$.inventory.apps[${n}]: unverified apps require manual install and no casks`)
    if (app.source === 'homebrew' && (!app.casks.length || app.install)) errors.push(`$.inventory.apps[${n}]: Homebrew apps require casks and no manual install`)
    for (const name of app.casks) if (!manifest.inventory.brew.casks.some(c => c.name === name)) errors.push(`$.inventory.apps[${n}].casks: unknown cask ${name}`)
  }
  return errors
}

export function validateCatalog(catalog) {
  validateAgainst(catalogSchema, catalog)
  const errors = itemSemanticErrors(catalog.items, '$')
  if (errors.length) throw new Error(errors.join('\n'))
  return catalog
}

export function validateManifest(manifest) {
  validateAgainst(machineSchema, manifest)
  const errors = [
    ...itemSemanticErrors(manifest.items, '$'),
    ...inventorySemanticErrors(manifest)
  ]
  if (errors.length) throw new Error(errors.join('\n'))
  return manifest
}

// Legacy combined manifests (schemaVersion 2) are migration input only.
export function validateLegacyManifest(manifest) {
  validateAgainst(legacySchema, manifest)
  const errors = [
    ...itemSemanticErrors(manifest.items, '$'),
    ...inventorySemanticErrors(manifest)
  ]
  if (errors.length) throw new Error(errors.join('\n'))
  return manifest
}

export const loadManifest = async path => validateManifest(JSON.parse(await readFile(path, 'utf8')))
export const loadCatalogFile = async path => validateCatalog(JSON.parse(await readFile(path, 'utf8')))
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
