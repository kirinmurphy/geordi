export function formatReport(report) {
  const lines = ['=== MAC SETUP ===']
  for (const item of report.results) lines.push(`  ${item.installed ? '✓' : '✗'} ${item.label} · ${item.origin} · ${item.provenance}${!item.installed && item.install.type === 'manual' ? ' · manual action required' : ''}`)
  lines.push('', `${report.summary.installed}/${report.summary.total} present · ${report.summary.missing} missing`,
    `Homebrew: ${report.summary.formulae} formulae · ${report.summary.casks} casks (all dependencies included)`)
  for (const [key, values] of Object.entries(report.drift)) if (values.length) lines.push(`${key}: ${values.join(', ')}`)
  if (report.declaredNotBrew.length) lines.push(`Declared defaults not Homebrew-managed: ${report.declaredNotBrew.join(', ')} (an existing app may satisfy the default).`)
  for (const action of report.actions.filter(a => a.install.type === 'manual')) lines.push(`  ${action.label}: ${action.install.instructions}`)
  if (report.mode === 'preview') lines.push('Preview only. Use --apply to install missing items; --sync updates inventory only.')
  return lines.join('\n')
}
