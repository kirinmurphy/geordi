import { access, stat, realpath } from 'node:fs/promises'
import { constants } from 'node:fs'
import { delimiter, join } from 'node:path'

export const expandHome = (value, home) => value.replace(/^(?:\$HOME|~)(?=\/|$)/, home)
export async function fileExists(path) {
  try { await access(path); return true } catch (e) { if (e.code === 'ENOENT') return false; throw e }
}
export async function executableFileExists(path) {
  try { if (!(await stat(path)).isFile()) return false; await access(path, constants.X_OK); return true }
  catch (e) { if (['ENOENT', 'EACCES', 'ENOTDIR'].includes(e.code)) return false; throw e }
}
export async function resolveCommand(command, env = process.env, isExecutable = executableFileExists) {
  for (const dir of (env.PATH ?? '').split(delimiter).filter(Boolean)) {
    const path = join(dir, command)
    if (await isExecutable(path)) return path
  }
  return null
}
export async function evaluateCheck(check, context = {}) {
  const env = context.env ?? process.env
  if (check.type === 'command') {
    const resolvedPath = await resolveCommand(check.value, env, context.isExecutable)
    const realPath = resolvedPath ? await (context.realpath ?? realpath)(resolvedPath).catch(() => resolvedPath) : null
    return { found: Boolean(resolvedPath), resolvedPath, realPath, provenance: 'executable-path-only' }
  }
  if (check.type === 'app' || check.type === 'path') {
    const resolvedPath = expandHome(check.value, context.home ?? env.HOME ?? '')
    return { found: await (context.exists ?? fileExists)(resolvedPath), resolvedPath }
  }
  throw new Error(`Unknown detection type: ${check.type}`)
}
export async function detectItem(item, context = {}) {
  const checks = await Promise.all(item.detect.map(async c => ({ ...c, ...await evaluateCheck(c, context) })))
  return { ...item, installed: checks.every(c => c.found), checks }
}
export const detectItems = (items, context = {}) => Promise.all(items.map(i => detectItem(i, context)))
