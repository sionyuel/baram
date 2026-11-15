import { readFile, stat } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";
import { createHash } from "node:crypto";

const root = path.dirname(fileURLToPath(import.meta.url));
const output = path.join(root, "dist");
const html = await readFile(path.join(output, "index.html"), "utf8");
const css = await readFile(path.join(output, "styles.css"), "utf8");
const ids = [...html.matchAll(/\bid="([^"]+)"/g)].map((match) => match[1]);
if (new Set(ids).size !== ids.length) throw new Error("Duplicate HTML IDs.");
if ((html.match(/<h1\b/g) ?? []).length !== 1) throw new Error("One primary heading is required.");
if (!html.includes('<html lang="ko">')) throw new Error("Korean document language missing.");
if (!html.includes('href="https://baram.sionyuel.com/"')) throw new Error("Canonical URL missing.");
if (!html.includes('content="index, follow"')) throw new Error("Public robots metadata missing.");
if (!html.includes("Baram-1.0.0-rc.3-unsigned-universal.zip")) throw new Error("Reviewed prerelease download missing.");
if (!html.includes("Developer ID") || !html.includes("Apple 공증이 없습니다")) throw new Error("Unsigned release warning missing.");
if (!html.includes("지원 세벌식 전용") || !html.includes("두벌식에는 적용되지 않습니다")) throw new Error("Physical chording scope is unclear.");
if (!html.includes("두벌식 · 세벌식 · 실험 기능") || !html.includes("두벌식 옛글은 제외합니다") || html.includes("두벌식에는 자동 한영 전환을 적용하지 않습니다")) throw new Error("Automatic correction scope is unclear.");
for (const match of html.matchAll(/(?:src|href)="([^"#][^"]*)"/g)) {
  if (/^(?:https?:|mailto:)/.test(match[1])) continue;
  await stat(path.join(output, match[1]));
}
for (const match of html.matchAll(/href="#([^"]+)"/g)) {
  if (!ids.includes(match[1])) throw new Error(`Missing anchor ${match[1]}`);
}
for (const match of css.matchAll(/url\("?([^\)"]+)/g)) {
  if (!/^data:/.test(match[1])) await stat(path.join(output, match[1]));
}
for (const asset of JSON.parse(await readFile(path.join(output, "asset-provenance.json"), "utf8"))) {
  const content = await readFile(path.join(output, asset.file));
  const actual = createHash("sha256").update(content).digest("hex");
  if (actual !== asset.sha256) throw new Error(`Asset checksum differs: ${asset.file}`);
}
if (!css.includes("prefers-reduced-motion") || !css.includes(":focus-visible")) throw new Error("Motion/focus accessibility rules missing.");
console.log("Baram public site verified: anchors, assets, provenance, prerelease warning, robots, focus and reduced motion.");
