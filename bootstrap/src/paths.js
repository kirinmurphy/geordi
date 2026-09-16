import { readFile } from 'node:fs/promises'
import { homedir } from 'node:os'
import { join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { validateSchema } from '../schema/validate.js'
import catalogSchema from '../schema/catalog-v1.schema.json' with { type: 'json' }

// Product data-directory knowledge is a manifest resource, not a literal
// scattered through code (repository manifest-driven composition rule).
// The dataDirName mirrors the desktop app's brand manifest dataDirectoryName
// so both surfaces share one Application Support directory.
const pathsSchema = {
  $schema: 'https://json-schema.org/draft/2020-12/schema',
  type: 'object',
  additionalProperties: false,
  properties: {
    schemaVersion: { const: 1 },
    dataDirName: { type: 'string', minLength: 1, pattern: '^[a-z0-9][a-z0-9._-]*$' },
    machineManifestName: { type: 'string', minLength: 1, pattern: '^[A-Za-z0-9][A-Za-z0-9._-]*\\.json$' }
  },
  required: ['schemaVersion', 'dataDirName', 'machineManifestName']
}

let cached = null
export async function loadPaths() {
  if (cached) return cached
  const paths = JSON.parse(await readFile(fileURLToPath(new URL('../resources/paths.json', import.meta.url)), 'utf8'))
  const errors = validateSchema(paths, pathsSchema)
  if (errors.length) throw new Error(errors.join('\n'))
  cached = paths
  return paths
}

// Default machine-manifest location: the same Application Support directory
// the desktop app uses (brand dataDirName), overridable with --manifest PATH.
// Test isolation: GEORDI_BOOTSTRAP_HOME redirects $HOME (temp-dir sandboxes).
export async function defaultMachineManifestPath(env = process.env, home = homedir()) {
  const paths = await loadPaths()
  const base = env.GEORDI_BOOTSTRAP_HOME || home
  return join(base, 'Library', 'Application Support', paths.dataDirName, paths.machineManifestName)
}
