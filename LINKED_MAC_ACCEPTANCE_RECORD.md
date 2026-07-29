# Linked-Mac Acceptance Record

Date: July 29, 2026  
Scope: current-state Homebrew cask, terminal capability, and shell-framework work  
Privacy: records product behavior only; no private file contents or arbitrary
local paths are retained here

## Evidence checked

- The linked snapshot completed all configured collectors.
- Warp was correlated to the installed `warp` cask through its declared
  application artifact and bundle identifier.
- Browser/Finder download-origin metadata remained independently not observed.
- Oh My Zsh appeared as an observed Git-backed shell framework with an active
  configuration reference and a sanitized `github.com` repository provider.
- Formulae and casks remained separate package entities.
- After installing the revised build and allowing the bounded refresh to
  complete, Warp retained **Download origin: Not observed** and **Installed
  with: Homebrew cask warp** with no contradictory cask field.
- Three current zsh processes were projected within the configured budget as
  possible—not proven—Oh My Zsh relationships.

## Issue found and resolved

Warp initially displayed both **Homebrew cask: Not observed** and
**Installed with: Homebrew cask warp**. The first field came from the older
resolved-path adapter; the second came from stronger Caskroom receipt evidence.
These claims described different implementations under the same label and
looked contradictory.

The resolved-path cask adapter was removed. Homebrew ownership now comes only
from the bounded Homebrew inventory, and the versioned application
classification policy recognizes the generic **Installed with: Homebrew cask
…** detail. Download origin remains a separate provenance adapter.

## Shell activity decision

An active `.zshrc` reference plus a current process whose executable exactly
matches the manifest-declared shell supports a useful but limited association.
HAL now presents this as a possible relationship and explicitly says it did
not inspect the process environment or prove that the process sourced the
configuration. The number of projected shell processes is manifest-bounded.

## Remaining validation

- Exercise every reviewed terminal adapter and the chooser from the installed
  UI.
- Complete representative participant sessions using
  `PRODUCT_EVALUATION_GUIDE.md`.
- Continue the lifecycle checks in `STATUS.md`; do not infer completion from
  this focused evidence audit.
