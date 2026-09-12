#!/usr/bin/env python3
"""Read-only evidence cross-check after the documented live commands.

Usage: python3 scripts/verify-evidence.py /tmp/geordi-brew-inventory.json \
  /tmp/geordi-formula-list.txt /tmp/geordi-cask-list.txt /tmp/geordi-bootstrap-check.json
"""
import json
import pathlib
import sys

root = pathlib.Path(__file__).resolve().parents[1]
manifest = json.loads((root / 'manifest.json').read_text())
capture, formula_file, cask_file, check_file = map(pathlib.Path, sys.argv[1:])
raw = json.loads(capture.read_text())
report = json.loads(check_file.read_text())
brew = manifest['inventory']['brew']
formulae = {f['name'] for f in brew['formulae']}
casks = {c['name'] for c in brew['casks']}
assert formulae == {f['full_name'] for f in raw['formulae']}
assert casks == {c['full_token'] for c in raw['casks']}
assert formulae == set(formula_file.read_text().splitlines())
assert casks == set(cask_file.read_text().splitlines())
assert all(not values for values in report['drift'].values())
assert report['summary']['formulae'] == len(formulae)
assert report['summary']['casks'] == len(casks)
source_files = sorted(root.rglob('*.js'))
assert all(len(p.read_text().splitlines()) < 300 for p in source_files)
for path in root.glob('*.md'):
    assert sum(line.startswith('```') for line in path.read_text().splitlines()) % 2 == 0
print(json.dumps({
    'capturedAndIndependentBrewListsMatch': True,
    'formulae': len(formulae), 'casks': len(casks),
    'requestedFormulae': sum(f['installedOnRequest'] for f in brew['formulae']),
    'dependencyFormulae': sum(not f['installedOnRequest'] for f in brew['formulae']),
    'apps': len(manifest['inventory']['apps']),
    'unverifiedApps': sum(a['source'] == 'unverified' for a in manifest['inventory']['apps']),
    'checkSummary': report['summary'], 'drift': report['drift'],
    'missingDefaultIds': [a['id'] for a in report['actions']],
    'javascriptFilesUnder300Lines': len(source_files),
}, indent=2))
