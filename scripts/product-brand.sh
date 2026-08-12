#!/bin/zsh

brand_manifest="${0:A:h:h}/Sources/HALManifestKit/Resources/product-brand.json"
product_display_name="$(plutil -extract displayName raw "$brand_manifest")"

if [[ -z "$product_display_name" || "$product_display_name" == *"/"* ]]; then
  print -u2 "Invalid product displayName in $brand_manifest"
  return 1
fi
