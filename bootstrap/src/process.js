import { execFile } from 'node:child_process'
import { promisify } from 'node:util'
const exec = promisify(execFile)
export async function run(command, args, options = {}) {
  try {
    return await exec(command, args, {
      maxBuffer: 32 * 1024 * 1024, timeout: 120000, ...options,
      env: { ...process.env, HOMEBREW_NO_AUTO_UPDATE: '1', HOMEBREW_NO_ANALYTICS: '1', HOMEBREW_NO_INSTALL_CLEANUP: '1', ...options.env }
    })
  } catch (e) {
    throw new Error(`${command} ${args.join(' ')} failed (${e.code ?? e.signal}): ${e.stderr?.trim() || e.message}`)
  }
}
