import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile, writeFile, mkdir, rm } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { migrateManifest } from '../src/migrate.js'

const sandbox = async () => {
  const dir = join(tmpdir(), `geordi-migrate-${process.pid}-${Math.random().toString(36).slice(2)}`)
  await mkdir(dir, { recursive: true })
  return dir
}
const legacyManifest = items => JSON.stringify({
  schemaVersion: 2,
  inventoryConfig: { appRoots: ['/Applications'], excludedBundlePrefixes: ['com.apple.'], brewPaths: [] },
  items,
  inventory: { brew: { formulae: [], casks: [], taps: [] }, apps: [], warnings: [] }
}, null, 2)
const twoItems = [
  { id: 'alpha', label: 'Alpha', group: 'cli', detect: [{ type: 'command', value: 'alpha' }], install: { type: 'manual', instructions: 'install alpha manually' } },
  { id: 'beta', label: 'Beta', group: 'apps', detect: [{ type: 'app', value: '/Applications/Beta.app' }], install: { type: 'brewCask', package: 'beta' } }
]

test('migrate writes machine manifest and contributes new items to the catalog', async () => {
  const dir = await sandbox()
  const legacyPath = join(dir, 'legacy.json'), catalogPath = join(dir, 'catalog.json'), machinePath = join(dir, 'machine.json')
  await writeFile(legacyPath, legacyManifest(twoItems))
  const result = await migrateManifest(legacyPath, catalogPath, machinePath)
  assert.deepEqual(result, { registered: 2, catalogContributed: 2, catalogTotal: 2 })
  const machine = JSON.parse(await readFile(machinePath, 'utf8'))
  assert.equal(machine.schemaVersion, 3)
  assert.equal(machine.items.length, 2)
  assert.deepEqual(machine.inventory.brew.formulae, [])
  const catalog = JSON.parse(await readFile(catalogPath, 'utf8'))
  assert.equal(catalog.schemaVersion, 1)
  assert.equal(catalog.items.length, 2)
  await rm(dir, { recursive: true, force: true })
})

test('existing catalog definitions are never mutated; unknown ids are added', async () => {
  const dir = await sandbox()
  const legacyPath = join(dir, 'legacy.json'), catalogPath = join(dir, 'catalog.json'), machinePath = join(dir, 'machine.json')
  await writeFile(legacyPath, legacyManifest(twoItems))
  const existingDefinition = { ...twoItems[0], label: 'Alpha (upstream wording)' }
  await writeFile(catalogPath, JSON.stringify({ schemaVersion: 1, items: [existingDefinition] }))
  const result = await migrateManifest(legacyPath, catalogPath, machinePath)
  assert.deepEqual(result, { registered: 2, catalogContributed: 1, catalogTotal: 2 })
  const catalog = JSON.parse(await readFile(catalogPath, 'utf8'))
  assert.equal(catalog.items.find(i => i.id === 'alpha').label, 'Alpha (upstream wording)')
  await rm(dir, { recursive: true, force: true })
})

test('refuses to overwrite an existing machine manifest without force', async () => {
  const dir = await sandbox()
  const legacyPath = join(dir, 'legacy.json'), machinePath = join(dir, 'machine.json')
  await writeFile(legacyPath, legacyManifest(twoItems))
  await writeFile(machinePath, legacyManifest([]))
  await assert.rejects(() => migrateManifest(legacyPath, join(dir, 'catalog.json'), machinePath), /already exists/)
  const result = await migrateManifest(legacyPath, join(dir, 'catalog.json'), machinePath, { overwriteExisting: true })
  assert.equal(result.registered, 2)
  await rm(dir, { recursive: true, force: true })
})

test('legacy manifest must be schema v2 and semantically valid', async () => {
  const dir = await sandbox()
  const legacyPath = join(dir, 'legacy.json')
  await writeFile(legacyPath, legacyManifest(twoItems).replace('"schemaVersion": 2', '"schemaVersion": 3'))
  await assert.rejects(() => migrateManifest(legacyPath, join(dir, 'catalog.json'), join(dir, 'm.json')), /schemaVersion/)
  const bad = JSON.parse(legacyManifest([{ ...twoItems[0], dependsOn: ['ghost'] }]).replace('"schemaVersion": 2', '"schemaVersion": 2'))
  await writeFile(legacyPath, JSON.stringify(bad))
  await assert.rejects(() => migrateManifest(legacyPath, join(dir, 'catalog.json'), join(dir, 'm.json')), /unknown dependency/)
  await rm(dir, { recursive: true, force: true })
})

test('outputs are atomic and byte-stable on a repeated migration with force', async () => {
  const dir = await sandbox()
  const legacyPath = join(dir, 'legacy.json'), catalogPath = join(dir, 'catalog.json'), machinePath = join(dir, 'machine.json')
  await writeFile(legacyPath, legacyManifest(twoItems))
  await migrateManifest(legacyPath, catalogPath, machinePath)
  const firstMachine = await readFile(machinePath, 'utf8'), firstCatalog = await readFile(catalogPath, 'utf8')
  await migrateManifest(legacyPath, catalogPath, machinePath, { overwriteExisting: true })
  assert.equal(await readFile(machinePath, 'utf8'), firstMachine)
  assert.equal(await readFile(catalogPath, 'utf8'), firstCatalog)
  await rm(dir, { recursive: true, force: true })
})
