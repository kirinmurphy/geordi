import test from 'node:test'
import assert from 'node:assert/strict'
import { readdir, readFile } from 'node:fs/promises'
import { loadManifest, validateManifest, validateCatalog, loadCatalogFile } from '../src/manifest.js'
import { validateSchema } from '../schema/validate.js'
const fixture = JSON.parse(await readFile(new URL('./fixtures/integration.json', import.meta.url)))
const fresh = () => structuredClone(fixture)
test('catalog and machine-manifest fixtures validate against their schemas', async () => {
  await loadCatalogFile(new URL('../catalog.json', import.meta.url))
  for (const file of await readdir(new URL('./fixtures/', import.meta.url))) if (file.endsWith('.json')) await loadManifest(new URL('./fixtures/' + file, import.meta.url))
})
test('unknown keys, invalid types, enums, and missing fields give paths', () => {
  const cases = [
    [m => m.bad = true, /\$\.bad: unknown/],
    [m => m.items[0].enabled = 'yes', /items\[0\]\.enabled: expected boolean/],
    [m => m.items[0].group = 'invalid', /items\[0\]\.group/],
    [m => m.items[0].install.package = '--evil', /install\.package/],
    [m => m.items[0].install.extra = 1, /install\.extra: unknown/],
    [m => delete m.items[0].detect, /items\[0\]\.detect: required/],
    [m => m.schemaVersion = 2, /schemaVersion/],
    [m => m.items[0].install.type = 'fake', /install\.type/],
    [m => m.items[0].detect = [], /detect/],
    [m => m.inventory.brew.formulae = {}, /formulae: expected array/]
  ]
  for (const [change, pattern] of cases) { const m = fresh(); change(m); assert.throws(() => validateManifest(m), pattern) }
})
test('duplicate item identifiers and installer targets rejected', () => {
  const m = fresh(); m.items.push(structuredClone(m.items[0]))
  assert.throws(() => validateManifest(m), /duplicate item id/)
  m.items[2].id = 'another'; assert.throws(() => validateManifest(m), /duplicate install target/)
})
test('catalog duplicates and dependency errors rejected too', () => {
  const catalog = { schemaVersion: 1, items: [structuredClone(fresh().items[0]), structuredClone(fresh().items[0])] }
  assert.throws(() => validateCatalog(catalog), /duplicate item id/)
  const [a] = fresh().items
  const withBadDep = { ...a, id: 'x', dependsOn: ['nope'] }
  assert.throws(() => validateCatalog({ schemaVersion: 1, items: [withBadDep] }), /unknown dependency nope/)
  const withCycleA = { ...a, id: 'a', dependsOn: ['b'] }
  const withCycleB = { ...a, id: 'b', dependsOn: ['a'] }
  assert.throws(() => validateCatalog({ schemaVersion: 1, items: [withCycleA, withCycleB] }), /cycle/)
})
test('unknown, cyclic and disabled dependency edges rejected', () => {
  const m = fresh(); m.items[0].dependsOn = ['bogus']
  assert.throws(() => validateManifest(m), /unknown dependency/)
  m.items[0].dependsOn = ['missing']; m.items[1].dependsOn = ['present']
  assert.throws(() => validateManifest(m), /cycle/)
  delete m.items[1].dependsOn; m.items[1].enabled = false
  assert.throws(() => validateManifest(m), /disabled dependency/)
})
test('same-name formula/cask remain distinct; duplicates within kind rejected', () => {
  const m = fresh()
  m.inventory.brew.formulae = [{ name: 'same', versions: ['1'], installedOnRequest: false, dependencies: [] }]
  m.inventory.brew.casks = [{ name: 'same', versions: ['1'], appPaths: [] }]
  validateManifest(m)
  m.inventory.brew.casks.push(m.inventory.brew.casks[0]); assert.throws(() => validateManifest(m), /duplicate same/)
})
test('manual app provenance is mandatory', () => {
  const m = fresh(); m.inventory.apps = [{ path: '/A.app', name: 'A', bundleId: '', version: '', source: 'unverified', casks: [] }]
  assert.throws(() => validateManifest(m), /require manual/)
})
test('unsupported schema keywords fail closed', () => assert.throws(() => validateSchema('x', { maxLength: 2 }), /Unsupported schema/))
test('prototype-named unknown fields are rejected', () => {
  const m = fresh(); m.constructor = 'unexpected'
  assert.throws(() => validateManifest(m), /constructor: unknown/)
})
test('runtime dependency references must exist and cannot reference self', () => {
  const m = fresh()
  m.inventory.brew.formulae = [{ name: 'tool', versions: ['1'], installedOnRequest: true, dependencies: ['missing'] }]
  assert.throws(() => validateManifest(m), /unknown dependency missing/)
  m.inventory.brew.formulae[0].dependencies = ['tool']
  assert.throws(() => validateManifest(m), /self dependency/)
})
