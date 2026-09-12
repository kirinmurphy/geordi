import { collectBrew } from './brew.js'
import { collectApps } from './apps.js'
import { expandHome } from './detect.js'
export async function collectInventory(manifest, deps = {}) {
  const config = { ...manifest.inventoryConfig,
    appRoots: manifest.inventoryConfig.appRoots.map(p => expandHome(p, deps.home ?? process.env.HOME ?? '')) }
  const brew = await (deps.collectBrew ?? collectBrew)(config)
  const { apps, warnings } = await (deps.collectApps ?? collectApps)(config, brew)
  const home = deps.home ?? process.env.HOME ?? ''
  for (const c of brew.casks) c.appPaths = c.appPaths.map(p => home && p.startsWith(home + '/') ? '$HOME' + p.slice(home.length) : p).sort()
  return { brew, apps, warnings }
}
export function brewDrift(expected, actual) {
  const keys = b => [...b.formulae.map(f => `formula:${f.name}`), ...b.casks.map(c => `cask:${c.name}`)].sort()
  const want = keys(expected), have = keys(actual)
  return { missing: want.filter(k => !have.includes(k)), untracked: have.filter(k => !want.includes(k)),
    missingTaps: expected.taps.filter(t => !actual.taps.includes(t)), untrackedTaps: actual.taps.filter(t => !expected.taps.includes(t)) }
}
