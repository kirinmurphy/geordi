import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { runCli, authorize } from '../src/cli.js'
import { parseArgs } from '../src/args.js'
const fixture = JSON.parse(readFileSync(new URL('./fixtures/integration.json', import.meta.url)))
const setup = () => {
  const logs = [], calls = [], present = new Set(['/present'])
  const deps = { loadManifest: async () => structuredClone(fixture),
    collectBrew: async () => fixture.inventory.brew,
    detectContext: { exists: async path => present.has(path) },
    log: value => logs.push(value), isTTY: false,
    installer: { preflight: async () => {}, install: async item => { calls.push(item.id); present.add('/' + item.id); return { ok: true } } } }
  return { logs, calls, deps }
}
test('mac default previews without install or confirmation', async () => {
  const { deps, calls, logs } = setup()
  deps.confirm = () => { throw new Error('unexpected prompt') }
  assert.equal(await runCli(['mac'], deps), 0)
  assert.equal(calls.length, 0)
  assert.match(logs.join('\n'), /Preview only/)
})
test('check and JSON are read-only and return missing status', async () => {
  for (const args of [['mac', '--check'], ['mac', '--json']]) {
    const { deps, calls, logs } = setup()
    assert.equal(await runCli(args, deps), 1)
    assert.equal(calls.length, 0)
    if (args.includes('--json')) assert.equal(JSON.parse(logs[0]).summary.missing, 1)
  }
})
test('apply --yes installs missing only and repeated apply is a no-op', async () => {
  const { deps, calls } = setup()
  assert.equal(await runCli(['mac', '--apply', '--yes'], deps), 0)
  assert.equal(await runCli(['mac', '--apply', '--yes'], deps), 0)
  assert.deepEqual(calls, ['missing'])
})
test('explicit installed target is also skipped', async () => {
  const { deps, calls } = setup()
  assert.equal(await runCli(['mac', 'present', '--apply', '--yes'], deps), 0)
  assert.deepEqual(calls, [])
})
test('apply refuses nonTTY without --yes', async () => {
  const { deps, calls } = setup()
  await assert.rejects(runCli(['mac', '--apply'], deps), /requires --yes/)
  assert.deepEqual(calls, [])
})
test('TTY approval and rejection are explicit', async () => {
  for (const approved of [false, true]) {
    const { deps, calls } = setup()
    deps.isTTY = true; deps.confirm = async () => approved
    assert.equal(await runCli(['mac', '--apply'], deps), approved ? 0 : 1)
    assert.equal(calls.length, approved ? 1 : 0)
  }
  assert.equal(await authorize({ yes: true }, { isTTY: false }), true)
})
test('sync is explicit and never installs', async () => {
  const { deps, calls } = setup(); let saved = 0
  deps.collectInventory = async () => fixture.inventory
  deps.saveInventory = async () => { saved++; return true }
  assert.equal(await runCli(['mac', '--sync'], deps), 0)
  assert.equal(saved, 1); assert.deepEqual(calls, [])
})
test('unknown and unsafe flag combinations rejected before reads', async () => {
  const bad = [['--sync','--apply'], ['--apply','--json'], ['--sync','--json'], ['--check','--apply'], ['--yes'], ['--wat'], ['--manifest'], ['list','--apply'], ['mac','a','b'], ['--sync','missing']]
  for (const args of bad) await assert.rejects(() => parseArgs(args, { GEORDI_BOOTSTRAP_HOME: '/tmp/x' }), undefined, args.join(' '))
  await assert.rejects(() => parseArgs(['migrate', 'mac'], { GEORDI_BOOTSTRAP_HOME: '/tmp/x' }))
  await assert.rejects(() => parseArgs(['migrate', '--apply'], { GEORDI_BOOTSTRAP_HOME: '/tmp/x' }))
})
test('help needs no manifest or Homebrew', async () => {
  const { deps, logs } = setup(); deps.loadManifest = () => { throw new Error('unexpected read') }
  assert.equal(await runCli(['mac', '--help'], deps), 0)
  assert.match(logs[0], /--apply/)
})
test('manifest option preserves equals in path', async () => {
  const options = await parseArgs(['--manifest=a=b.json'], { GEORDI_BOOTSTRAP_HOME: '/tmp/x' })
  assert.equal(options.manifestPath, 'a=b.json')
})
