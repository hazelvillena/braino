# Braino brand assets

`BrainoMark.png` is the original supplied transparent artwork, preserved byte-for-byte.

`BrainoIcon.png` and `Braino.icns` composite that drawing at a larger scale over a rounded lemon tile with a subtle yellow gradient. The drawing's internal transparency is preserved, so its holes show the yellow rather than becoming a solid silhouette.

`BrainoGlyph.png` is the transparent header glyph; `BrainoMenu.png` is the transparent menu template. These do not include a yellow tile.

Run `./build.sh` to regenerate all assets and copy the exact shared UI into the app. Do not substitute an image-generated silhouette for the original drawing.
