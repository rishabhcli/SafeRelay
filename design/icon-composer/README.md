# SafeRelay Icon Composer Layers

The icon uses a fixed three-color palette:

- Black: `#000000`
- Signal red: `#FF1F3D`
- White: `#FFFFFF`

All import layers are 1024 x 1024 PNGs exported from one coordinate system.
Do not crop or resize individual files before importing them.

Stack the files back to front in numeric order:

1. `01-black-background.png`
2. `02-triangle-links.png`
3. `03-device-rings.png`
4. `04-device-nodes.png`
5. `05-device-glyphs.png`
6. `06-sos-ring.png`
7. `07-sos-beacon.png`
8. `08-sos.png`

The black background is full-bleed and opaque. Every other PNG has transparency.
`SafeRelay-preview.png` is a flattened reference and is not an import layer.

Suggested four-group organization in Icon Composer:

- Background: `01-black-background`
- Network links: `02-triangle-links`
- Linked devices: `03-device-rings`, `04-device-nodes`, `05-device-glyphs`
- Emergency: `06-sos-ring`, `07-sos-beacon`, `08-sos`
