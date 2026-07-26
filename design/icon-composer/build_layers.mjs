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
const platformMaskSource = join(
  root,
  "../../mobile/App Icon Exports/App Icon-iOS-Default-1024x1024@1x.png",
);

const BLACK = "#000000";
const RED = "#FF1F3D";
const WHITE = "#FFFFFF";

const triangle = {
  top: { x: 512, y: 236 },
  left: { x: 205, y: 780 },
  right: { x: 819, y: 780 },
};

const trimLine = (start, end, startInset, endInset = startInset) => {
  const length = Math.hypot(end.x - start.x, end.y - start.y);
  const xDirection = (end.x - start.x) / length;
  const yDirection = (end.y - start.y) / length;
  return {
    start: {
      x: start.x + xDirection * startInset,
      y: start.y + yDirection * startInset,
    },
    end: {
      x: end.x - xDirection * endInset,
      y: end.y - yDirection * endInset,
    },
  };
};

const triangleEdges = [
  trimLine(triangle.top, triangle.left, 72),
  trimLine(triangle.top, triangle.right, 72),
  trimLine(triangle.left, triangle.right, 44),
].map((edge) => {
  const length = Math.hypot(
    edge.end.x - edge.start.x,
    edge.end.y - edge.start.y,
  );
  return {
    ...edge,
    dashLength: (length - 22 * 5) / 6,
  };
});

const triangleLine = ({ start, end, dashLength }) =>
  `<path d="M ${start.x.toFixed(2)} ${start.y.toFixed(2)} L ${end.x.toFixed(2)} ${end.y.toFixed(2)}" fill="none" stroke="${WHITE}" stroke-width="10" stroke-linecap="round" stroke-dasharray="${dashLength.toFixed(2)} 22"/>`;

const phoneFrame = ({ x, y }) =>
  `<rect x="${x - 34}" y="${y - 54}" width="68" height="108" rx="16" fill="${WHITE}"/>`;

const phoneScreen = ({ x, y }) =>
  `<rect x="${x - 25}" y="${y - 42}" width="50" height="80" rx="9" fill="${RED}"/>`;

const phoneDetails = ({ x, y }) =>
  [
    `<rect x="${x - 9}" y="${y - 49}" width="18" height="4" rx="2" fill="${BLACK}"/>`,
    `<rect x="${x - 9}" y="${y + 44}" width="18" height="4" rx="2" fill="${BLACK}"/>`,
  ].join("\n");

const layers = [
  {
    filename: "01-black-background",
    label: "Black background",
    artwork: `<rect width="1024" height="1024" fill="${BLACK}"/>`,
  },
  {
    filename: "02-sos-ring",
    label: "SOS ring",
    artwork: `
      <circle cx="512" cy="592" r="168" fill="${WHITE}"/>
    `,
  },
  {
    filename: "03-sos-beacon",
    label: "SOS beacon",
    artwork: `
      <circle cx="512" cy="592" r="154" fill="${RED}"/>
    `,
  },
  {
    filename: "04-sos",
    label: "SOS",
    artwork: `
      <text
        x="512"
        y="637"
        text-anchor="middle"
        font-family="Arial"
        font-size="112"
        font-weight="700"
        letter-spacing="5"
        fill="${WHITE}"
      >SOS</text>
    `,
  },
  {
    filename: "05-triangle-links",
    label: "Dashed triangle links",
    artwork: `
      ${triangleEdges.map(triangleLine).join("\n")}
    `,
  },
  {
    filename: "06-phone-frames",
    label: "Phone frames",
    artwork: `
      ${phoneFrame(triangle.top)}
      ${phoneFrame(triangle.left)}
      ${phoneFrame(triangle.right)}
    `,
  },
  {
    filename: "07-phone-screens",
    label: "Phone screens",
    artwork: `
      ${phoneScreen(triangle.top)}
      ${phoneScreen(triangle.left)}
      ${phoneScreen(triangle.right)}
    `,
  },
  {
    filename: "08-phone-details",
    label: "Phone details",
    artwork: `
      ${phoneDetails(triangle.top)}
      ${phoneDetails(triangle.left)}
      ${phoneDetails(triangle.right)}
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
  if (layer.filename === "04-sos") {
    await execFileAsync("magick", [
      "-size",
      "1024x1024",
      "xc:none",
      "-font",
      "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
      "-pointsize",
      "112",
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
  if (layer.filename === "05-triangle-links") {
    await execFileAsync("magick", [
      "-size",
      "1024x1024",
      "xc:none",
      "-fill",
      "none",
      "-stroke",
      WHITE,
      "-strokewidth",
      "10",
      ...triangleEdges.flatMap(({ start, end, dashLength }) => [
        "-draw",
        [
          "stroke-linecap round",
          `stroke-dasharray ${dashLength.toFixed(2)} 22`,
          `path 'M ${start.x.toFixed(2)},${start.y.toFixed(2)} L ${end.x.toFixed(2)},${end.y.toFixed(2)}'`,
        ].join(" "),
      ]),
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
const squarePreviewPng = join(root, ".SafeRelay-preview-square.png");
await writeFile(masterSvg, svgDocument("flattened preview", masterArtwork));
await execFileAsync("magick", [
  ...layers.map((layer) => join(pngDir, `${layer.filename}.png`)),
  "-background",
  "none",
  "-layers",
  "flatten",
  `PNG24:${squarePreviewPng}`,
]);
await execFileAsync("magick", [
  squarePreviewPng,
  "(",
  platformMaskSource,
  "-alpha",
  "extract",
  ")",
  "-alpha",
  "off",
  "-compose",
  "CopyOpacity",
  "-composite",
  "-strip",
  `PNG32:${previewPng}`,
]);
await rm(squarePreviewPng, { force: true });

await execFileAsync("zip", [
  "-j",
  "-q",
  archivePath,
  ...layers.map((layer) => join(pngDir, `${layer.filename}.png`)),
  previewPng,
  join(root, "README.md"),
]);

console.log(`Generated ${layers.length} aligned PNG layers, preview, and archive.`);
