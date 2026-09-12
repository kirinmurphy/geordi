import { run } from './process.js'
import { resolveCommand, executableFileExists } from './detect.js'
import { basename, join } from 'node:path'

export const sorted = values => [...new Set(values)].sort()
export async function findBrew(config, deps = {}) {
  const found = await (deps.resolveCommand ?? resolveCommand)('brew')
  if (found) return found
  for (const path of config.brewPaths) if (await (deps.isExecutable ?? executableFileExists)(path)) return path
  return null
}
export function normalizeBrew(data, taps, appRoots) {
  if (!Array.isArray(data.formulae) || !Array.isArray(data.casks)) throw new Error('Homebrew JSON must contain formulae and casks arrays')
  const formulae = data.formulae.map(f => {
    if (!f.installed?.length || !f.full_name) throw new Error('Invalid installed formula record')
    return { name: f.full_name, versions: sorted(f.installed.map(v => v.version)),
      installedOnRequest: f.installed.some(v => v.installed_on_request === true),
      dependencies: sorted(f.installed.flatMap(v => (v.runtime_dependencies ?? []).map(d => d.full_name))) }
  })
  const casks = data.casks.map(c => {
    if (!c.installed || !c.full_token) throw new Error('Invalid installed cask record')
    const appPaths = c.artifacts.flatMap(a => {
      if (!a.app) return []
      if (typeof a.target === 'string' && a.target.startsWith('/')) return [a.target]
      const target = a.app.find(v => typeof v === 'object' && v?.target)?.target ?? a.app[0]
      if (typeof target !== 'string') throw new Error(`Invalid app artifact for ${c.full_token}`)
      return target.startsWith('/') ? [target] : appRoots.map(root => join(root, basename(target)))
    })
    return { name: c.full_token, versions: sorted(Array.isArray(c.installed) ? c.installed : [c.installed]), appPaths: sorted(appPaths) }
  })
  const byName = (a, b) => a.name < b.name ? -1 : a.name > b.name ? 1 : 0
  return { formulae: formulae.sort(byName), casks: casks.sort(byName), taps: sorted(taps) }
}
export async function collectBrew(config, deps = {}) {
  const brewPath = await findBrew(config, deps)
  if (!brewPath) throw new Error('Homebrew not found. Install it from https://brew.sh and add brew to PATH; inventory was not overwritten.')
  const exec = deps.run ?? run
  const { stdout } = await exec(brewPath, ['info', '--json=v2', '--installed'])
  const { stdout: taps } = await exec(brewPath, ['tap'])
  return normalizeBrew(JSON.parse(stdout), taps.split(/\r?\n/).filter(Boolean), config.appRoots)
}
