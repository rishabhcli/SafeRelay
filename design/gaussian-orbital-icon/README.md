# SafeRelay Gaussian Orbital Icon

This SafeRelay icon uses the scientific visual language of Gaussian/GaussView
quantum-chemistry output: triangulated molecular-orbital isosurfaces, separate
positive and negative phases, atom centers, and molecular bonds. The artwork is
an original SafeRelay composition generated with GPT Image 2; it does not copy
Gaussian's logo or letterform.

All import layers are aligned 1024 x 1024 PNGs. Do not crop or resize individual
files before importing them into Apple Icon Composer.

Stack the files back to front in numeric order:

1. `01-quantum-black-background.png`
2. `02-electron-density-haze.png`
3. `03-positive-orbital-phase.png`
4. `04-negative-orbital-phase.png`
5. `05-molecular-bonds.png`
6. `06-atom-nodes.png`
7. `07-emergency-nucleus.png`
8. `08-mesh-highlights.png`

The background is opaque. Every other layer has transparency.

## Suggested Icon Composer groups

- Background: layers 1 and 2
- Molecular orbital: layers 3, 4, and 8
- Molecular scaffold: layers 5 and 6
- Emergency relay: layer 7

Keep the phase layers close together, with only shallow depth. Place the
emergency nucleus slightly forward and use a subtle specular treatment on the
atom nodes and mesh highlights.

## Rebuild

```sh
node design/gaussian-orbital-icon/build_layers.mjs
```

The build produces:

- `SafeRelay-gaussian-orbital-master.png`: unmasked production artwork
- `SafeRelay-gaussian-orbital-preview.png`: rounded-square visual preview
- `SafeRelay-gaussian-orbital-layers.png`: eight-layer contact sheet
- `SafeRelay-Gaussian-Orbital-Icon-Layers.zip`: Icon Composer handoff

The original generated source is preserved as
`gpt-image-2-orbital-source.png`.

## GPT Image 2 prompt

```text
Create a premium iOS app icon for SafeRelay inspired by quantum-chemistry
molecular orbital and electron-density visualizations made in
Gaussian/GaussView, while remaining fully original. On a full-bleed neutral
black field, center a three-dimensional molecular structure with three primary
atom nodes arranged as a relay triangle around a bright emergency-red core.
Surround and connect the structure with positive and negative orbital lobes
rendered as fine triangulated wire mesh. Use coral red, cool cyan, pearl white,
graphite, and a small amber transition. Keep the bonds and endpoints legible at
small size. No words, letters, formulas, axes, labels, UI, platform mask, or
copy of Gaussian's trademark.
```
