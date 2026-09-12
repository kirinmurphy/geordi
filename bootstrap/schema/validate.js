import { readFileSync } from 'node:fs'

export const schema = JSON.parse(readFileSync(new URL('./manifest-v2.schema.json', import.meta.url), 'utf8'))

// Deliberately constrained JSON Schema interpreter. Fail closed on unsupported
// keywords so evolving the contract cannot silently disable validation.
const supported = new Set(['$schema', '$id', '$defs', '$ref', 'title', 'description',
  'type', 'const', 'enum', 'oneOf', 'properties', 'required', 'additionalProperties',
  'items', 'minItems', 'uniqueItems', 'minLength', 'pattern'])
export function validateSchema(value, rule = schema, path = '$', root = rule) {
  for (const key of Object.keys(rule)) {
    if (!supported.has(key)) throw new Error(`Unsupported schema keyword: ${key}`)
  }
  if (rule.$ref) {
    const target = rule.$ref.split('/').slice(1).reduce((v, k) => v?.[k], root)
    if (!target) throw new Error(`Unresolved schema reference: ${rule.$ref}`)
    return validateSchema(value, target, path, root)
  }
  const errors = []
  const fail = message => errors.push(`${path}: ${message}`)
  if (rule.oneOf) {
    const variants = rule.oneOf.map(r => validateSchema(value, r, path, root))
    if (variants.filter(v => v.length === 0).length !== 1) {
      const match = rule.oneOf.findIndex(r => r.properties?.type?.const === value?.type || r.properties?.type?.enum?.includes(value?.type))
      errors.push(...(match >= 0 ? variants[match] : [`${path}.type: no matching schema variant`]))
    }
  }
  if ('const' in rule && value !== rule.const) fail(`expected ${JSON.stringify(rule.const)}`)
  if (rule.enum && !rule.enum.includes(value)) fail(`expected one of ${rule.enum.join(', ')}`)
  const kind = Array.isArray(value) ? 'array' : value === null ? 'null' : typeof value
  if (rule.type && kind !== rule.type) { fail(`expected ${rule.type}, got ${kind}`); return errors }
  if (kind === 'object') {
    for (const key of rule.required ?? []) if (!Object.hasOwn(value, key)) errors.push(`${path}.${key}: required`)
    for (const [key, child] of Object.entries(value)) {
      if (rule.properties && Object.hasOwn(rule.properties, key)) errors.push(...validateSchema(child, rule.properties[key], `${path}.${key}`, root))
      else if (rule.additionalProperties === false) errors.push(`${path}.${key}: unknown field`)
    }
  }
  if (kind === 'array') {
    if (value.length < (rule.minItems ?? 0)) fail(`expected at least ${rule.minItems} items`)
    if (rule.uniqueItems && new Set(value.map(v => JSON.stringify(v))).size !== value.length) fail('duplicate values')
    if (rule.items) value.forEach((v, i) => errors.push(...validateSchema(v, rule.items, `${path}[${i}]`, root)))
  }
  if (kind === 'string') {
    if (value.length < (rule.minLength ?? 0)) fail('must not be empty')
    if (rule.pattern && !new RegExp(rule.pattern).test(value)) fail(`does not match ${rule.pattern}`)
  }
  return errors
}
