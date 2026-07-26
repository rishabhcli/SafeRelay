import { mkdir, rm, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { execFile } from "node:child_process";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);
const root = dirname(fileURLToPath(import.meta.url));
const svgDir = join(root, "svg");
const pngDir = join(root, "png");
const archivePath = join(root, "SafeRelay-Icon-Composer-PNGs.zip");

const BLACK = "#000000";
const RED = "#FF1F3D";
const WHITE = "#FFFFFF";

const dottedLine = (x1, y1, x2, y2, count = 5, radius = 10) =>
  Array.from({ length: count }, (_, index) => {
    const t = 0.2 + (index / (count - 1)) * 0.6;
    const cx = x1 + (x2 - x1) * t;
    const cy = y1 + (y2 - y1) * t;
    return `<circle cx="${cx.toFixed(2)}" cy="${cy.toFixed(2)}" r="${radius}" fill="${WHITE}"/>`;
  }).join("\n");

const layers = [
  {
    filename: "01-black-background",
    label: "Black background",
    artwork: `<rect width="1024" height="1024" fill="${BLACK}"/>`,
  },
  {
    filename: "02-triangle-links",
    label: "Dotted triangle links",
    artwork: `
      ${dottedLine(512, 272, 235, 752)}
      ${dottedLine(512, 272, 789, 752)}
      ${dottedLine(235, 752, 789, 752)}
    `,
  },
  {
    filename: "03-device-rings",
    label: "Device rings",
    artwork: `
      <circle cx="512" cy="272" r="66" fill="${WHITE}"/>
      <circle cx="235" cy="752" r="66" fill="${WHITE}"/>
      <circle cx="789" cy="752" r="66" fill="${WHITE}"/>
    `,
  },
  {
    filename: "04-device-nodes",
    label: "Device nodes",
    artwork: `
      <circle cx="512" cy="272" r="55" fill="${RED}"/>
      <circle cx="235" cy="752" r="55" fill="${RED}"/>
      <circle cx="789" cy="752" r="55" fill="${RED}"/>
    `,
  },
  {
    filename: "05-device-glyphs",
    label: "Device glyphs",
    artwork: `
      <rect x="500" y="253" width="24" height="38" rx="6" fill="${WHITE}"/>
      <rect x="223" y="733" width="24" height="38" rx="6" fill="${WHITE}"/>
      <rect x="777" y="733" width="24" height="38" rx="6" fill="${WHITE}"/>
    `,
  },
  {
    filename: "06-sos-ring",
    label: "SOS ring",
    artwork: `
      <circle cx="512" cy="592" r="142" fill="${WHITE}"/>
    `,
  },
  {
    filename: "07-sos-beacon",
    label: "SOS beacon",
    artwork: `
      <circle cx="512" cy="592" r="129" fill="${RED}"/>
    `,
  },
  {
    filename: "08-sos",
    label: "SOS",
    artwork: `
      <text
        x="512"
        y="632"
        text-anchor="middle"
        font-family="Arial"
        font-size="100"
        font-weight="700"
        letter-spacing="5"
        fill="${WHITE}"
      >SOS</text>
    `,
  },
];

const svgDocument = (label, artwork) => `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <title>SafeRelay icon - ${label}</title>
  ${artwork}
</svg>
`;

await rm(svgDir, { recursive: true, force: true });
await rm(pngDir, { recursive: true, force: true });
await rm(archivePath, { force: true });
await mkdir(svgDir, { recursive: true });
await mkdir(pngDir, { recursive: true });

for (const layer of layers) {
  const svgPath = join(svgDir, `${layer.filename}.svg`);
  const pngPath = join(pngDir, `${layer.filename}.png`);
  await writeFile(svgPath, svgDocument(layer.label, layer.artwork.trim()));
  if (layer.filename === "08-sos") {
    await execFileAsync("magick", [
      "-size",
      "1024x1024",
      "xc:none",
      "-font",
      "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
      "-pointsize",
      "100",
      "-kerning",
      "5",
      "-fill",
      WHITE,
      "-gravity",
      "center",
      "-annotate",
      "+0+80",
      "SOS",
      "-strip",
      `PNG32:${pngPath}`,
    ]);
    continue;
  }
  await execFileAsync("magick", [
    "-background",
    "none",
    "-density",
    "144",
    svgPath,
    "-resize",
    "1024x1024!",
    "-strip",
    `PNG32:${pngPath}`,
  ]);
}

const masterArtwork = layers.map((layer) => `<g id="${layer.filename}">${layer.artwork}</g>`).join("\n");
const masterSvg = join(svgDir, "SafeRelay-master.svg");
const previewPng = join(root, "SafeRelay-preview.png");
await writeFile(masterSvg, svgDocument("flattened preview", masterArtwork));
await execFileAsync("magick", [
  ...layers.map((layer) => join(pngDir, `${layer.filename}.png`)),
  "-background",
  "none",
  "-layers",
  "flatten",
  `PNG24:${previewPng}`,
]);

await execFileAsync("zip", [
  "-j",
  "-q",
  archivePath,
  ...layers.map((layer) => join(pngDir, `${layer.filename}.png`)),
  previewPng,
  join(root, "README.md"),
]);

console.log(`Generated ${layers.length} aligned PNG layers, preview, and archive.`);
