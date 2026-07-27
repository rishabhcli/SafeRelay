import { execFile } from "node:child_process";
import { mkdir, rm } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);
const root = dirname(fileURLToPath(import.meta.url));
const source = join(root, "gpt-image-2-orbital-source.png");
const pngDir = join(root, "png");
const workingDir = join(root, ".build");
const squareMaster = join(root, "SafeRelay-gaussian-orbital-master.png");
const preview = join(root, "SafeRelay-gaussian-orbital-preview.png");
const contactSheet = join(root, "SafeRelay-gaussian-orbital-layers.png");
const archive = join(root, "SafeRelay-Gaussian-Orbital-Icon-Layers.zip");
const normalizedColor = join(workingDir, "normalized-color.png");

const circle = (x, y, radius) =>
  `(((i-${x})*(i-${x})+(j-${y})*(j-${y}))<${radius * radius})`;

const nucleus = circle(512, 540, 78);
const atomNodes = [
  circle(512, 290, 58),
  circle(298, 648, 64),
  circle(722, 648, 64),
  circle(512, 207, 37),
  circle(220, 688, 37),
  circle(329, 731, 37),
  circle(803, 688, 37),
  circle(695, 731, 37),
].join("||");
const highlight = "max(r,max(g,b))>0.82";
const positivePhase = "(r>g*1.22&&r>b*1.10)";
const negativePhase = "(b>r*1.12&&g>r*1.10)";
const protectedParts = `(${nucleus})||(${atomNodes})`;

const layers = [
  {
    filename: "01-quantum-black-background",
    label: "Quantum black background",
    background: true,
  },
  {
    filename: "02-electron-density-haze",
    label: "Electron density haze",
    condition: `!(${protectedParts})&&max(r,max(g,b))<0.18`,
  },
  {
    filename: "03-positive-orbital-phase",
    label: "Positive orbital phase",
    condition: `!(${protectedParts})&&!(${highlight})&&max(r,max(g,b))>=0.18&&${positivePhase}`,
  },
  {
    filename: "04-negative-orbital-phase",
    label: "Negative orbital phase",
    condition: `!(${protectedParts})&&!(${highlight})&&max(r,max(g,b))>=0.18&&${negativePhase}`,
  },
  {
    filename: "05-molecular-bonds",
    label: "Molecular bonds",
    condition: `!(${protectedParts})&&!(${highlight})&&max(r,max(g,b))>=0.18&&!${positivePhase}&&!${negativePhase}`,
  },
  {
    filename: "06-atom-nodes",
    label: "Atom nodes",
    condition: atomNodes,
  },
  {
    filename: "07-emergency-nucleus",
    label: "Emergency nucleus",
    condition: nucleus,
  },
  {
    filename: "08-mesh-highlights",
    label: "Mesh highlights",
    condition: `!(${protectedParts})&&${highlight}`,
  },
];

const runMagick = (...args) => execFileAsync("magick", args);

await rm(pngDir, { recursive: true, force: true });
await rm(workingDir, { recursive: true, force: true });
await rm(archive, { force: true });
await mkdir(pngDir, { recursive: true });
await mkdir(workingDir, { recursive: true });

await runMagick(
  source,
  "-filter",
  "Lanczos",
  "-resize",
  "1024x1024!",
  "-colorspace",
  "sRGB",
  "-strip",
  `PNG24:${squareMaster}`,
);

await runMagick(
  squareMaster,
  "-alpha",
  "off",
  "-fx",
  "max(r,max(g,b))<0.000001?0:u/max(r,max(g,b))",
  "-strip",
  `PNG24:${normalizedColor}`,
);

for (const layer of layers) {
  const output = join(pngDir, `${layer.filename}.png`);
  if (layer.background) {
    await runMagick("-size", "1024x1024", "xc:#000000", "-strip", `PNG24:${output}`);
    continue;
  }

  const mask = join(workingDir, `${layer.filename}-mask.png`);
  await runMagick(
    squareMaster,
    "-alpha",
    "off",
    "-fx",
    `max(r,max(g,b))*((${layer.condition})?1:0)`,
    "-colorspace",
    "Gray",
    "-strip",
    `PNG8:${mask}`,
  );
  await runMagick(
    normalizedColor,
    mask,
    "-alpha",
    "off",
    "-compose",
    "CopyOpacity",
    "-composite",
    "-strip",
    `PNG32:${output}`,
  );
}

const layerPaths = layers.map(({ filename }) => join(pngDir, `${filename}.png`));
const recomposed = join(workingDir, "recomposed.png");
await runMagick(
  ...layerPaths,
  "-background",
  "none",
  "-layers",
  "flatten",
  "-strip",
  `PNG24:${recomposed}`,
);

const previewMask = join(workingDir, "preview-mask.png");
await runMagick(
  "-size",
  "1024x1024",
  "xc:none",
  "-fill",
  "white",
  "-draw",
  "roundrectangle 44,44 980,980 220,220",
  `PNG8:${previewMask}`,
);
await runMagick(
  recomposed,
  previewMask,
  "-alpha",
  "off",
  "-compose",
  "CopyOpacity",
  "-composite",
  "-strip",
  `PNG32:${preview}`,
);

await execFileAsync("magick", [
  "montage",
  ...layerPaths,
  "-set",
  "label",
  "%t",
  "-thumbnail",
  "232x232",
  "-background",
  "#15171A",
  "-fill",
  "#F5F7FA",
  "-font",
  "/System/Library/Fonts/SFNS.ttf",
  "-pointsize",
  "13",
  "-tile",
  "4x2",
  "-geometry",
  "232x262+12+12",
  "-strip",
  `PNG24:${contactSheet}`,
]);

await execFileAsync("zip", [
  "-j",
  "-q",
  archive,
  ...layerPaths,
  squareMaster,
  preview,
  join(root, "README.md"),
]);

const { stdout: meanDifference } = await runMagick(
  squareMaster,
  recomposed,
  "-compose",
  "difference",
  "-composite",
  "-format",
  "%[fx:mean]",
  "info:",
);

await rm(workingDir, { recursive: true, force: true });

console.log(`Generated ${layers.length} aligned layers, preview, contact sheet, and archive.`);
console.log(`Recomposition mean pixel difference: ${meanDifference.trim()}`);
