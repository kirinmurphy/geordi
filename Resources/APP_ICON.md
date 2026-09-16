# geordi app icon

The icon is original generated artwork, not a copied film still or
reproduction of any prop.

## Current icon (September 2026, portal variant)

- Design: a glowing electric-blue diamond core inside four rounded
  metal corner blocks on a dark squircle — a futuristic "portal" motif.
- Master: `GeordiApp-1024.png` (1024×1024, derived from the user-supplied
  `portal_icon_variant_final` artwork, downscaled from 1254×1254, then
  flattened edge-to-edge — the artwork's transparent margin was filled
  with the border color and the content scaled to the tile edge via
  `swift scripts/make-icon-master.swift`, otherwise the icon reads
  smaller than full-bleed neighbors at Dock size)
- Packaged asset: `GeordiApp.icns`, rebuilt from the master with the
  standard pipeline below.

## Regeneration

```sh
cd Resources
rm -rf GeordiApp.iconset && mkdir GeordiApp.iconset
for s in 16 32 128 256 512; do
  sips -z $s $s GeordiApp-1024.png --out GeordiApp.iconset/icon_${s}x${s}.png
  sips -z $((s*2)) $((s*2)) GeordiApp-1024.png --out GeordiApp.iconset/icon_${s}x${s}@2x.png
done
iconutil -c icns GeordiApp.iconset -o GeordiApp.icns
```

Always ship an icns built from this pipeline (all 10 size entries) rather
than a third-party icns — some generators omit the small non-retina
variants.
