# POZ character assets

Start with `lineup.png` for the full visual direction and `CAST.md` for character rules.
The four individual PNGs have real alpha transparency and are ready for web/app use.
Do not use the labeled lineup where a transparent illustration is required.

`PROMPTS.md` records the exact built-in image generation prompts and targeted retries.
`qa.html` presents every asset over light and dark backgrounds at realistic sizes.

Project copies are in `site/public/brand/characters/` and `app/assets/characters/`.
The shared web/native Character components support all four residents in two poses.
Current integrations and the Null favicon decision are documented in `../BRAND_GUIDE.md`.
`motion/` contains the new cutout loops and wide/vertical introduction videos.
The old 3D character animations remain legacy files and are not used in the new set.

Run `sync-library.ps1` to copy this set to the user's existing Documents brand library.
It backs up previous current files and the old cast specification before replacing them.
