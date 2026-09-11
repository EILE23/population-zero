# POZ face — current favicon

`face.svg` is the current source. It reinterprets the user's original small dark face
with rounded eyes, soft side tabs and a small smile. It is not the Null cat character.

- SVG, `face-{size}.png` and `favicon.ico`: genuinely transparent outside the face.
- White eyes and mouth are opaque. No background tile, halo, letters or cat ears.
- `preview.png`: light/dark comparison sheet only; its background is not in the icons.
- Website Apple touch icon: separate opaque 180px export, not the browser favicon.
- `null.svg` and `null-*.png`: rejected historical alternative; retained only as source
  history. Do not use them in the app, website or brand guide.

Generate: `node brand/poz/favicon/generate.mjs <sharp module path>`
Verify: `node brand/poz/verify-assets.mjs <sharp module path>`
