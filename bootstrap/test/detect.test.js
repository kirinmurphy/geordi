import test from 'node:test'
import assert from 'node:assert/strict'
import { evaluateCheck, detectItem } from '../src/detect.js'
test('command detection uses executable metadata without launching programs', async () => {
  const result = await evaluateCheck({ type: 'command', value: 'hermes' }, {
    env: { PATH: '/fake/bin' }, isExecutable: async p => p === '/fake/bin/hermes',
    realpath: async () => '/source/hermes.py', probe: () => { throw new Error('must not execute') }
  })
  assert.equal(result.found, true)
  assert.equal(result.realPath, '/source/hermes.py')
  assert.equal(result.provenance, 'executable-path-only')
})
test('command requires executable and returns absent cleanly', async () => {
  assert.equal((await evaluateCheck({ type: 'command', value: 'tool' }, { env: { PATH: '/fake' }, isExecutable: async () => false })).found, false)
})
test('all item checks must pass and HOME expands portably', async () => {
  const item = { detect: [{ type: 'path', value: '$HOME/example' }, { type: 'app', value: '/missing.app' }] }
  const result = await detectItem(item, { home: '/home', exists: async p => p === '/home/example' })
  assert.equal(result.checks[0].found, true); assert.equal(result.installed, false)
})
test('unsupported executing command probes rejected', async () => {
  await assert.rejects(evaluateCheck({ type: 'commandProbe' }), /Unknown detection/)
})
