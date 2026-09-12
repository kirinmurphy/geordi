import test from 'node:test'
import assert from 'node:assert/strict'
import { createSystemInstaller } from '../src/installers/system.js'
import { installItems } from '../src/install.js'
import { run } from '../src/process.js'
const item = { id: 'tool', label: 'Tool', install: { type: 'brewFormula', package: 'user/tap/tool' } }
const absent = async () => ({ installed: false })
test('system adapter emits argument arrays with explicit package kinds', async () => {
  const calls = []
  const adapter = createSystemInstaller({ brewPaths: [] }, { platform: 'darwin', resolveCommand: async name => '/fake/' + name,
    run: async (...args) => { calls.push(args) } })
  await adapter.install(item)
  await adapter.install({ ...item, install: { type: 'brewCask', package: 'tool' } })
  await adapter.install({ ...item, install: { type: 'npmGlobal', package: '@openai/codex' } })
  assert.deepEqual(calls.map(c => c.slice(0, 2)), [
    ['/fake/brew', ['install', '--formula', 'user/tap/tool']],
    ['/fake/brew', ['install', '--cask', 'tool']],
    ['/fake/npm', ['install', '--global', '--', '@openai/codex']]])
})
test('missing prerequisites and manual work fail before installation', async () => {
  const adapter = createSystemInstaller({ brewPaths: [] }, { platform: 'darwin', resolveCommand: async () => null })
  await assert.rejects(adapter.install(item), /missing prerequisite Homebrew/)
  await assert.rejects(adapter.install({ ...item, install: { type: 'manual', instructions: 'See vendor' } }), /manual action required/)
  await assert.rejects(adapter.install({ ...item, install: { type: 'npmGlobal', package: 'tool' } }), /missing prerequisite npm/)
})
test('preflight all missing items before any mutation', async () => {
  let installed = 0
  await assert.rejects(installItems([item, { ...item, id: 'blocked' }], {
    preflight: async i => { if (i.id === 'blocked') throw new Error('blocked') },
    install: async () => { installed++; return { ok: true } }
  }, absent), /blocked/)
  assert.equal(installed, 0)
})
test('failed command and failed verification never report success', async () => {
  await assert.rejects(installItems([item], { preflight: async () => {}, install: async () => { throw new Error('exit 1') } }, absent), /exit 1/)
  await assert.rejects(installItems([item], { preflight: async () => {}, install: async () => ({ ok: true }) }, absent), /verification failed/)
  await assert.rejects(installItems([item], { preflight: async () => {}, install: async () => ({ ok: false }) }, absent), /did not report success/)
})
test('recheck skips a concurrently installed item', async () => {
  let observations = 0, calls = 0
  await installItems([item], { preflight: async () => {}, install: async () => { calls++ } }, async () => ({ installed: ++observations > 1 }))
  assert.equal(calls, 0)
})
test('process runner checks real subprocess failures without installers', async () => {
  await assert.rejects(run(process.execPath, ['-e', 'process.exit(7)']), /failed \(7\)/)
  await assert.rejects(run('/definitely-not-a-real-command', []), /ENOENT/)
})
