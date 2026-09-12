import { readdir } from 'node:fs/promises'
import { basename, join } from 'node:path'
import { run } from './process.js'
import { expandHome } from './detect.js'
import { sorted } from './brew.js'

export async function collectApps(config, brew, deps = {}) {
  const home = deps.home ?? process.env.HOME ?? ''
  const portable = path => home && path.startsWith(home + '/') ? '$HOME' + path.slice(home.length) : path
  const apps = [], warnings = []
  const exec = deps.run ?? run
  const walk = async (root, top = false) => {
    let entries
    try { entries = await (deps.readdir ?? readdir)(root, { withFileTypes: true }) }
    catch (e) { if (top && e.code === 'ENOENT') return; throw new Error(`Cannot inventory ${root}: ${e.message}`) }
    for (const entry of entries.sort((a, b) => a.name < b.name ? -1 : a.name > b.name ? 1 : 0)) {
      const path = join(root, entry.name)
      if (!entry.name.endsWith('.app')) {
        if (entry.isDirectory()) await walk(path)
        continue
      }
      let plist = {}
      try { plist = JSON.parse((await exec('/usr/bin/plutil', ['-convert', 'json', '-o', '-', join(path, 'Contents/Info.plist')])).stdout) }
      catch { warnings.push(`${portable(path)}: unreadable Info.plist; name-only inventory, source unverified unless cask artifact matches`) }
      const bundleId = typeof plist.CFBundleIdentifier === 'string' ? plist.CFBundleIdentifier : ''
      if (config.excludedBundlePrefixes.some(prefix => bundleId.startsWith(prefix))) continue
      const casks = brew.casks.filter(c => c.appPaths.some(p => expandHome(p, home) === path)).map(c => c.name)
      const string = value => typeof value === 'string' ? value : ''
      apps.push({ path: portable(path), name: string(plist.CFBundleDisplayName) || string(plist.CFBundleName) || basename(path, '.app'),
        bundleId, version: string(plist.CFBundleShortVersionString) || string(plist.CFBundleVersion),
        source: casks.length ? 'homebrew' : 'unverified', casks: sorted(casks),
        ...(!casks.length ? { install: { type: 'manual', instructions: 'Install from a verified vendor or original source; no package identifier has been inferred.' } } : {}) })
    }
  }
  for (const root of config.appRoots) await walk(expandHome(root, home), true)
  return { apps: apps.sort((a, b) => a.path < b.path ? -1 : a.path > b.path ? 1 : 0), warnings: sorted(warnings) }
}
