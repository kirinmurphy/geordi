import { run } from '../process.js'
import { findBrew } from '../brew.js'
import { resolveCommand } from '../detect.js'

const commands = {
  brewCask: (path, item) => [path, ['install', '--cask', item.install.package]],
  brewFormula: (path, item) => [path, ['install', '--formula', item.install.package]],
  npmGlobal: (path, item) => [path, ['install', '--global', '--', item.install.package]]
}
export function createSystemInstaller(config, deps = {}) {
  return {
    async preflight(item) {
      if (item.install.type === 'manual') throw new Error(`${item.label}: manual action required. ${item.install.instructions}`)
      if (!commands[item.install.type]) throw new Error(`Unsupported installer: ${item.install.type}`)
      if ((deps.platform ?? process.platform) !== 'darwin') throw new Error('Mac installation requires macOS')
      const path = item.install.type.startsWith('brew') ? await findBrew(config, deps) : await (deps.resolveCommand ?? resolveCommand)('npm')
      if (!path) throw new Error(`${item.label}: missing prerequisite ${item.install.type.startsWith('brew') ? 'Homebrew (https://brew.sh)' : 'npm / Node.js'}`)
      return commands[item.install.type](path, item)
    },
    async install(item) {
      const [command, args] = await this.preflight(item)
      await (deps.run ?? run)(command, args, { timeout: 30 * 60 * 1000 })
      return { ok: true }
    }
  }
}
