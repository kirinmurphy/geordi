import { readFile, writeFile, rename, unlink, access, constants } from 'node:fs/promises'
import { validateLegacyManifest, validateCatalog, validateManifest } from './manifest.js'

// One-time migration: a legacy combined manifest (schema v2, items + inventory
// in one file) becomes (a) item definitions merged into the repo catalog and
// (b) a machine manifest holding the user's registered items + inventory.
// The catalog copy only adds items the catalog does not already have: upstream
// definitions never mutate. Nothing is deleted; the source file is left intact
// until the user removes it.
export async function migrateManifest(legacyPath, catalogPath, machinePath, deps = {}) {
  const read = deps.readFile ?? readFile
  const legacy = validateLegacyManifest(JSON.parse(await read(legacyPath, 'utf8')))
  let catalog
  try {
    catalog = validateCatalog(JSON.parse(await read(catalogPath, 'utf8')))
  } catch (e) {
    if (e.code !== 'ENOENT') throw e
    catalog = { schemaVersion: 1, items: [] }
  }
  const existing = await (deps.exists ?? (async path => {
    try { await access(path, constants.F_OK); return true } catch { return false }
  }))(machinePath)
  if (existing && !deps.overwriteExisting) {
    throw new Error(`Machine manifest already exists: ${machinePath}. Remove it or pass --force to replace it.`)
  }
  const catalogIds = new Set(catalog.items.map(i => i.id))
  const contributed = legacy.items.filter(i => !catalogIds.has(i.id))
  const nextCatalog = validateCatalog({ schemaVersion: 1, items: [...catalog.items, ...contributed] })
  const machine = validateManifest({
    schemaVersion: 3,
    inventoryConfig: legacy.inventoryConfig,
    items: legacy.items,
    inventory: legacy.inventory
  })
  await (deps.writeCatalog ?? writeAtomic)(catalogPath, JSON.stringify(nextCatalog, null, 2) + '\n')
  await (deps.writeMachine ?? writeAtomic)(machinePath, JSON.stringify(machine, null, 2) + '\n')
  return { registered: legacy.items.length, catalogContributed: contributed.length, catalogTotal: nextCatalog.items.length }
}

export async function writeAtomic(path, text) {
  const tmp = `${path}.${process.pid}.tmp`
  try { await writeFile(tmp, text, { flag: 'wx' }); await rename(tmp, path) }
  finally { await unlink(tmp).catch(e => { if (e.code !== 'ENOENT') throw e }) }
}
