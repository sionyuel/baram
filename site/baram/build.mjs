import { copyFile, mkdir, readFile, writeFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";
import { createHash } from "node:crypto";

const root = path.dirname(fileURLToPath(import.meta.url));
const repository = path.resolve(root, "../..");
const output = path.join(root, "dist");
await mkdir(path.join(output, "assets"), { recursive: true });
for (const file of ["index.html", "styles.css", "app.js"]) {
  await copyFile(path.join(root, "src", file), path.join(output, file));
}
const assetSources = {
  "brand-tokens.css": "docs/brand/baram/tokens.css",
  "baram-mark-master.svg": "docs/brand/baram/assets/baram-mark-master.svg",
  "baram-mark-small.svg": "docs/brand/baram/assets/baram-mark-small.svg",
};
const provenance = [];
for (const [name, source] of Object.entries(assetSources)) {
  await copyFile(path.join(repository, source), path.join(output, "assets", name));
  const content = await readFile(path.join(repository, source));
  provenance.push({ file: `assets/${name}`, source, sha256: createHash("sha256").update(content).digest("hex") });
}
const html = await readFile(path.join(output, "index.html"), "utf8");
if (!html.includes('content="index, follow"') || !html.includes("Baram-1.0.0-rc.1-unsigned-universal.zip")) {
  throw new Error("Public page must be indexable and link the reviewed prerelease asset.");
}
await writeFile(path.join(output, "robots.txt"), "User-agent: *\nAllow: /\n");
await writeFile(path.join(output, "asset-provenance.json"), `${JSON.stringify(provenance, null, 2)}\n`);
console.log(`Built Baram public site: ${output}`);
