// Re-detect before EVERY action, preflight the whole plan before any mutation,
// and verify after success. No upgrades, removals, shell scripts, or fake success.
export async function installItems(items, installer, observe) {
  const missing = []
  for (const item of items) if (!(await observe(item)).installed) missing.push(item)
  for (const item of missing) await installer.preflight(item)
  const results = []
  for (const item of missing) {
    if ((await observe(item)).installed) continue
    const result = await installer.install(item)
    if (result?.ok !== true) throw new Error(`${item.id}: installer did not report success`)
    if (!(await observe(item)).installed) throw new Error(`${item.id}: post-install verification failed; inspect installer output and PATH, then rerun`)
    results.push({ id: item.id, verified: true })
  }
  return results
}
