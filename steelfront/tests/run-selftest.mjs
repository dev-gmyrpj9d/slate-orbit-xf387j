#!/usr/bin/env node
// Runs Steel Front's built-in self-test (steelfront.html?selftest) in headless Chrome/Chromium and exits 0 on PASS.
// No npm dependencies. Usage:
//   node steelfront/tests/run-selftest.mjs [path/to/steelfront.html]
//   CHROME=/path/to/chrome node steelfront/tests/run-selftest.mjs
import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const page = resolve(process.argv[2] || resolve(here, "../steelfront.html"));
if (!existsSync(page)) { console.error(`not found: ${page}`); process.exit(2); }

const candidates = [process.env.CHROME, "google-chrome", "google-chrome-stable", "chromium", "chromium-browser", "chrome",
  "/usr/local/bin/linear-chromium", "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe"].filter(Boolean);
const chrome = candidates.find(c => spawnSync(c, ["--version"], { stdio: "ignore" }).status === 0);
if (!chrome) { console.error("No Chrome/Chromium found: set CHROME=/path/to/chrome"); process.exit(2); }

const url = pathToFileURL(page).href + "?selftest";
// software WebGL2 so it also runs on machines without a GPU; virtual time lets the page finish its checks
const r = spawnSync(chrome, ["--headless=new", "--no-sandbox", "--use-angle=swiftshader", "--enable-unsafe-swiftshader",
  "--virtual-time-budget=90000", "--dump-dom", url], { encoding: "utf8", maxBuffer: 64 << 20, timeout: 240000 });
const dom = r.stdout || "";
const sum = /<body[^>]*\sdata-selftest="([^"]*)"/.exec(dom);
const panel = /<pre id="selftest"[^>]*>([\s\S]*?)<\/pre>/.exec(dom);
const decode = s => s.replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, "\"").replace(/&#39;/g, "'").replace(/&amp;/g, "&");
if (panel) console.log(decode(panel[1]));
if (!sum) {
  console.error(`Self-test did not report a result (WebGL2 unavailable, or the page threw on load).\n${(r.stderr || "").split("\n").slice(-15).join("\n")}`);
  process.exit(1);
}
console.log(`\n${sum[1]}`);
process.exit(sum[1].startsWith("PASS") ? 0 : 1);
