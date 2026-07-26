# SafeRelay Icon Composer Layers

The icon uses a fixed three-color palette:

- Black: `#000000`
- Signal red: `#FF1F3D`
- White: `#FFFFFF`

All import layers are 1024 x 1024 PNGs exported from one coordinate system.
Do not crop or resize individual files before importing them.

Stack the files back to front in numeric order:

1. `01-black-background.png`
2. `02-sos-ring.png`
3. `03-sos-beacon.png`
4. `04-sos.png`
5. `05-triangle-links.png`
6. `06-phone-frames.png`
7. `07-phone-screens.png`
8. `08-phone-details.png`

The black background is full-bleed and opaque. Every other PNG has transparency.
Keep all eight import layers square and unmasked so Apple can apply its native
rounded-square shape without jagged or doubled edges.

`SafeRelay-preview.png` is a flattened reference and is not an import layer. Its
four corners use the same uniform rounded-square mask as the Apple Icon Composer
export in this repository, matching the macOS 27 app-icon shape.

Suggested four-group organization in Icon Composer:

- Background: `01-black-background`
- Emergency: `02-sos-ring`, `03-sos-beacon`, `04-sos`
- Network links: `05-triangle-links`
- Linked devices: `06-phone-frames`, `07-phone-screens`, `08-phone-details`
