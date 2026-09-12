import test from 'node:test'
import assert from 'node:assert/strict'
import { mkdtemp, writeFile, readFile, mkdir, rm } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { normalizeBrew, collectBrew, findBrew } from '../src/brew.js'
import { collectApps } from '../src/apps.js'
import { brewDrift } from '../src/inventory.js'
import { saveInventory } from '../src/manifest.js'
import { selectItems, observeItem } from '../src/plan.js'
const fixture = JSON.parse(await readFile(new URL('./fixtures/integration.json', import.meta.url)))
const raw = {
  formulae: [{ full_name: 'tool', installed: [{ version: '2', installed_on_request: true, runtime_dependencies: [{ full_name: 'lib' }] }] },
    { full_name: 'lib', installed: [{ version: '1', installed_on_request: false, runtime_dependencies: [] }] }],
  casks: [{ full_token: 'tool', installed: '3', artifacts: [{ app: ['Different.app'], target: '/Applications/Exact.app' }] }]
}
test('normalization retains every dependency, installed versions and formula/cask identities', () => {
  const result = normalizeBrew(raw, [], ['/Applications'])
  assert.deepEqual(result.formulae.map(f => f.name), ['lib', 'tool'])
  assert.equal(result.formulae[0].installedOnRequest, false)
  assert.deepEqual(result.formulae[1].dependencies, ['lib'])
  assert.deepEqual(result.casks[0].appPaths, ['/Applications/Exact.app'])
  const reversed = structuredClone(raw); reversed.formulae.reverse()
  assert.deepEqual(normalizeBrew(reversed, [], ['/Applications']), result)
})
test('cask target overrides source bundle basename, qualified identifiers preserved', () => {
  const data = { formulae: [], casks: [{ full_token: 'user/tap/app', installed: ['1'], artifacts: [{ app: ['Source.app', { target: 'Target.app' }] }] }] }
  assert.deepEqual(normalizeBrew(data, ['user/tap'], ['/Applications']).casks, [{ name: 'user/tap/app', versions: ['1'], appPaths: ['/Applications/Target.app'] }])
})
test('invalid or incomplete brew capture is rejected, not treated as empty', () => {
  assert.throws(() => normalizeBrew({}, [], []), /arrays/)
  assert.throws(() => normalizeBrew({ formulae: [{ full_name: 'x', installed: [] }], casks: [] }, [], []), /Invalid installed/)
})
test('Homebrew collection calls read-only argv only and fails closed', async () => {
  const calls = []
  const deps = { resolveCommand: async () => '/brew', run: async (cmd, args) => { calls.push([cmd, args]); return { stdout: args[0] === 'info' ? JSON.stringify(raw) : '' } } }
  await collectBrew({ brewPaths: [], appRoots: ['/Applications'] }, deps)
  assert.deepEqual(calls, [['/brew', ['info', '--json=v2', '--installed']], ['/brew', ['tap']]])
  await assert.rejects(collectBrew({ brewPaths: [] }, { resolveCommand: async () => null }), /not found/)
  assert.equal(await findBrew({ brewPaths: ['/fallback'] }, { resolveCommand: async () => null, isExecutable: async () => true }), '/fallback')
})
test('app inventory uses plist/name only, recursively finds suites, skips Apple, never guesses casks', async () => {
  const dir = await mkdtemp(join(tmpdir(), 'geordi-apps-'))
  try {
    for (const name of ['Suite/Manual.app', 'Managed.app', 'Apple.app', 'Broken.app']) await mkdir(join(dir, name), { recursive: true })
    const calls = []
    const deps = { home: dir, run: async (cmd, args) => {
      calls.push([cmd, args]); const path = args.at(-1)
      if (path.includes('Broken')) throw new Error('bad plist')
      return { stdout: JSON.stringify({ CFBundleIdentifier: path.includes('Apple') ? 'com.apple.example' : 'org.vendor.app', CFBundleName: 'Metadata name', CFBundleShortVersionString: '1' }) }
    } }
    const result = await collectApps({ appRoots: [dir], excludedBundlePrefixes: ['com.apple.'] }, { casks: [{ name: 'managed', appPaths: [join(dir, 'Managed.app')] }] }, deps)
    assert.equal(result.apps.length, 3)
    assert.equal(result.apps.filter(a => a.source === 'unverified').length, 2)
    assert.equal(result.warnings.length, 1)
    assert.ok(result.apps.some(a => a.path === '$HOME/Suite/Manual.app' && a.install.type === 'manual'))
    assert.ok(calls.every(([cmd, args]) => cmd === '/usr/bin/plutil' && args.slice(0, 4).join(' ') === '-convert json -o -'))
  } finally { await rm(dir, { recursive: true, force: true }) }
})
test('directory permission failure aborts rather than silently truncates inventory', async () => {
  await assert.rejects(collectApps({ appRoots: ['/apps'], excludedBundlePrefixes: [] }, { casks: [] }, { readdir: async () => { throw Object.assign(new Error('denied'), { code: 'EACCES' }) } }), /Cannot inventory/)
})
test('inventory write is deterministic, idempotent and preserves defaults', async () => {
  const dir = await mkdtemp(join(tmpdir(), 'geordi-sync-'))
  try {
    const path = join(dir, 'manifest.json'), m = structuredClone(fixture)
    await writeFile(path, JSON.stringify(m, null, 2) + '\n')
    const inventory = { ...m.inventory, brew: normalizeBrew(raw, [], ['/Applications']) }
    assert.equal(await saveInventory(path, m, inventory), true)
    const first = await readFile(path, 'utf8')
    assert.equal(await saveInventory(path, m, inventory), false)
    assert.equal(await readFile(path, 'utf8'), first)
    assert.deepEqual(JSON.parse(first).items, fixture.items)
    await assert.rejects(saveInventory(path, m, { bad: true }), /unknown field/)
    assert.equal(await readFile(path, 'utf8'), first)
  } finally { await rm(dir, { recursive: true, force: true }) }
})
test('drift distinguishes formula/cask same-name and includes taps', () => {
  const actual = normalizeBrew(raw, [], ['/Applications'])
  const expected = { formulae: [], casks: [{ name: 'tool' }], taps: ['user/tap'] }
  assert.deepEqual(brewDrift(expected, actual), { missing: [], untracked: ['formula:lib', 'formula:tool'], missingTaps: ['user/tap'], untrackedTaps: [] })
})
test('dependency ordering and snapshot install plan are deterministic; manual apps included', () => {
  const m = structuredClone(fixture); m.items[0].dependsOn = ['missing']
  m.inventory.brew = normalizeBrew(raw, [], ['/Applications'])
  m.inventory.apps = [{ path: '/Manual.app', name: 'Manual', source: 'unverified', install: { type: 'manual', instructions: 'vendor' } }]
  assert.deepEqual(selectItems(m, 'present').map(i => i.id), ['missing', 'present'])
  assert.deepEqual(selectItems(m).map(i => i.id), ['missing', 'present', 'brewFormula:lib', 'brewFormula:tool', 'brewCask:tool', 'app:/Manual.app'])
})
test('existing manual default app satisfies setup without claiming Homebrew provenance', async () => {
  const item = { detect: [{ type: 'app', value: '/Manual.app' }], install: { type: 'brewCask', package: 'manual' } }
  const result = await observeItem(item, { formulae: [], casks: [] }, { exists: async () => true })
  assert.equal(result.installed, true); assert.equal(result.provenance, 'detected-source-unverified')
})
