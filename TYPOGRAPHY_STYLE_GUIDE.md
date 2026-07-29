# HAL Typography Style Guide

Status: active application style contract  
Updated: July 29, 2026

HAL uses semantic font roles from `Sources/HALApp/Typography.swift`. Views must
not introduce raw point sizes or use SwiftUI's `caption` and `caption2` styles.

- `halDisplay`: primary screen or entity title
- `halTitle`: prominent inspector title
- `halSection`: major section heading
- `halSubsection`: secondary section heading
- `halRowTitle`: interactive row and card title
- `halBody`: primary explanatory prose
- `halSecondary`: supporting text and values
- `halSmall`: labels, metadata, and compact annotations

`halSmall` is the minimum permitted application font. It maps to the system
footnote style so it remains dynamic-type aware while being more legible than
the caption styles it replaces.

Weight, color, and emphasis may vary without creating a new size role. A new
size requires an update to this guide and the centralized type scale.
