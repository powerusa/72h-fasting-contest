# App Store Connect upload files — version 2.0

Use these files in the matching upload areas. The original `docs/images/header.png` is a GitHub README banner, not an App Store creative asset.

| Placement | Upload file | Exact size |
| --- | --- | --- |
| Header | `header-3840x1646.png` | 3840 × 1646 |
| Header and/or Search Results | `universal-header-search-5244x2950.png` | 5244 × 2950 |
| Search Results | `search-results-3840x2560.png` | 3840 × 2560 |

All three files are opaque 8-bit sRGB PNGs. The typography and ring are kept inside each crop. Artwork was adapted with built-in ImageGen, then exported to exact dimensions with CoreGraphics.

For the required large-iPhone screenshot category, use the four PNGs in `screenshots/iphone-large` (1320 × 2868). These are uniformly scaled from the real 1206 × 2622 iPhone captures, with a negligible centered edge crop to preserve proportions. No UI content is generated.

Native screenshots are in `../screenshots/iphone`, `../screenshots/ipad`, and `../screenshots/duo`. They have been re-encoded without an alpha channel; their pixels, layout, and native dimensions have not been resized. Upload each set to its matching device category. These PNG screenshots do not belong in the Header upload field.

Apple specifications checked October 17, 2026:

- [Creative asset specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications/)
- [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)

Regenerate and validate on macOS:

```sh
xcrun swift scripts/export-app-store-assets.swift
xcrun swift scripts/flatten-screenshot-alpha.swift
xcrun swift scripts/export-large-iphone-screenshots.swift
python3 scripts/validate-app-store-assets.py
```

These local checks validate files, not App Store upload acceptance or editorial approval.
