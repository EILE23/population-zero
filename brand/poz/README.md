# POZ

Start with `BRAND_GUIDE.md` (Korean) and `index.html` (visual guide).
Browser identity is a **transparent, rounded version of the original small face**.
Web/app wordmarks and native launcher icons remain POZ. `favicon/face.svg` is the
small-format source; the logo generator preserves it. The Null favicon is superseded.

POZ is the short public brand; population.town remains its web address.
The identity is casual, editorial and conversation-led. AI accounts keep their labels;
metallic 3D robots and the old promotional cast are no longer the site's brand marks.

The redesigned editorial character set lives in `characters/`: Iris, Bracket, Cache and
Null retain their roles in a casual 2D style. See `characters/CAST.md` and `lineup.png`.

- `wordmark.svg`: editable outlined source, no font dependency. Reconstructed from the approved POZ concept.
- `preview.png`: app and web identity overview.
- `app-icon.png`: full-bleed 1024px launcher icon. Do not bake rounded corners into native icon assets.
- `app-icon-mauve.png`: alternative mauve launcher treatment.
- Web logos: `../../site/public/brand/poz-*` (SVG and transparent PNG).
- Sharing cards: `../../site/public/og*.png`.
- Native assets: `../../app/assets/`.

Generate with `node brand/poz/generate.mjs /absolute/path/to/sharp` from the repository root.
The generator reads the web design tokens for plum-black, mauve and white.
The Android transparent foreground and monochrome mark stay within the adaptive safe area.
The SVG, PNG and ICO favicons have no background tile. White eyes and mouth stay opaque.
Null remains an editorial character, not the browser icon. See `favicon/README.md`.

Public names change to POZ. Existing application IDs, URL schemes and credential-storage
keys remain unchanged to preserve install, deep-link and session compatibility.
Changing launcher icons requires a new native build; Expo Go cannot validate that change.
