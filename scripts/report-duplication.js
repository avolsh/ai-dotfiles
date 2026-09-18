#!/usr/bin/env node

/**
 * `make dup-report` — a duplicated-code figure per group of a project's source tree.
 *
 * Shared by every project that declares a `duplication` row in its Build and Run table
 * (tobevisit-web IMP-20260916-quality-gates-adoption FR-4; first written in tobevisit-content as
 * IMP-20260914-duplicate-report-and-format-scope FR-1 – FR-3). It runs from the project root — jscpd
 * is resolved from that project's own `node_modules`, so each caller pins its version.
 *
 * It is a **report**, not a gate — it exits 0 whatever it finds, because no threshold has been
 * calibrated yet; each project records its first figures as the baseline a later gate will cite.
 *
 * Exit 0 means "the report was produced", not "nothing was found". A detector that did not run, or
 * scanned nothing, exits 2: a report built from no scan reads exactly like a clean codebase.
 *
 * ## Why the configuration lives here and not in `.jscpd.json`
 *
 * jscpd 5 rejects unknown keys in its config file and JSON carries no comments, so a `.jscpd.json`
 * could not say *why* a tree is excluded. The exclusions below are the whole configuration, each with
 * its reason, passed to jscpd as flags.
 *
 * ## Groups
 *
 * Each top-level directory of the scan root is a group, and `<root> (root)` holds files directly
 * under it. A directory named by `--split` is not a group itself: each of its subdirectories is (in
 * tobevisit-content, `--split contexts` gives one group per bounded context). A new top-level
 * directory is counted rather than dropped. A clone whose two halves sit in different groups adds its
 * lines to both; a clone inside one group adds them once.
 *
 * Usage (from the project root):
 *   node report-duplication.js [--scan-root <dir>] [--split <dir>]...   scan and summarise
 *   node report-duplication.js [--scan-root <dir>] [--split <dir>]... --from-report <file>
 *                                                                        summarise an existing jscpd report
 * `--scan-root` defaults to `src`; `--split` may be repeated.
 */

const fs = require("fs");
const path = require("path");
const {spawnSync} = require("child_process");

const PROJECT_ROOT = process.cwd();
/** Git-ignored in every caller; `jscpd-report.json` is the name jscpd's JSON reporter writes. */
const REPORT_DIR = ".duplication-report";
const REPORT_FILE = path.join(REPORT_DIR, "jscpd-report.json");

/** jscpd defaults, chosen for the first report: the gate follow-up calibrates its own. */
const MIN_TOKENS = 50;
const MIN_LINES = 5;
const FORMATS = ["typescript", "tsx", "javascript", "jsx"];

/** Every tree the scan skips, and why. An exclusion without a reason is not allowed to exist. */
const EXCLUSIONS = [
  {
    glob: "**/__fixtures__/**",
    reason: "golden files and prompt snapshots tests compare against — copies of real output by design",
  },
  {
    glob: "**/__scratch__/**",
    reason: "throwaway investigation scripts outside the build; copies there are not debt in the product",
  },
];

const displayPath = (absolutePath) =>
  absolutePath.startsWith(PROJECT_ROOT + path.sep) ? path.relative(PROJECT_ROOT, absolutePath) : absolutePath;

const fail = (message) => {
  console.error(`[ERROR] dup-report cannot run: ${message}`);
  process.exit(2);
};

const parseArgs = (argv) => {
  const options = {scanRoot: "src", split: new Set(), fromReport: undefined};
  for (let i = 0; i < argv.length; i += 1) {
    const flag = argv[i];
    const value = argv[i + 1];
    if (flag !== "--scan-root" && flag !== "--split" && flag !== "--from-report") fail(`unknown argument: ${flag}`);
    if (!value || value.startsWith("--")) fail(`${flag} needs a value`);
    if (flag === "--scan-root") options.scanRoot = value.replace(/[\\/]+$/, "");
    if (flag === "--split") options.split.add(value.replace(/[\\/]+$/, ""));
    if (flag === "--from-report") options.fromReport = path.resolve(PROJECT_ROOT, value);
    i += 1;
  }
  return options;
};

/** `app/admin/x.tsx` or `src/app/admin/x.tsx` → `src/app`; `composition-root.ts` → `src (root)`. */
const groupOf = (fileName, {scanRoot, split}) => {
  const parts = fileName.split(/[\\/]/).filter((part) => part !== "" && part !== ".");
  const rootParts = scanRoot.split(/[\\/]/).filter((part) => part !== "" && part !== ".");
  if (rootParts.every((part, index) => parts[index] === part)) parts.splice(0, rootParts.length);
  if (parts.length <= 1) return `${scanRoot} (root)`;
  if (split.has(parts[0]) && parts.length > 2) return `${scanRoot}/${parts[0]}/${parts[1]}`;
  return `${scanRoot}/${parts[0]}`;
};

const runDetector = ({scanRoot}) => {
  const absoluteReport = path.resolve(PROJECT_ROOT, REPORT_FILE);
  // A report left by an earlier run must not be read as this run's result.
  fs.rmSync(absoluteReport, {force: true});

  const args = [
    scanRoot,
    "--min-tokens",
    String(MIN_TOKENS),
    "--min-lines",
    String(MIN_LINES),
    "--format",
    FORMATS.join(","),
    "--ignore",
    EXCLUSIONS.map((exclusion) => exclusion.glob).join(","),
    "--reporters",
    "json,silent",
    "--output",
    REPORT_DIR,
    "--fail-on-empty",
  ];
  const result = spawnSync(path.join("node_modules", ".bin", "jscpd"), args, {cwd: PROJECT_ROOT, encoding: "utf8"});
  if (result.error) {
    fail(`jscpd did not start (${result.error.message}); the project needs jscpd as a dev dependency — run \`npm install\``);
  }
  if (result.status !== 0) {
    fail(`jscpd exited ${result.status}\n${`${result.stdout ?? ""}${result.stderr ?? ""}`.trim()}`);
  }
  if (!fs.existsSync(absoluteReport)) fail(`jscpd exited 0 but wrote no report at ${REPORT_FILE}`);
  return absoluteReport;
};

const readReport = (reportPath) => {
  if (!fs.existsSync(reportPath)) fail(`report does not exist: ${displayPath(reportPath)}`);
  const report = JSON.parse(fs.readFileSync(reportPath, "utf8"));
  if (!Array.isArray(report.duplicates) || !report.statistics || !report.statistics.total) {
    fail(`${displayPath(reportPath)} is not a jscpd JSON report (no duplicates / statistics.total)`);
  }
  return report;
};

/**
 * Every group that exists on disk, seeded at zero, so a group with no clones prints `0` instead of
 * vanishing — an absent row and a clean one must not read the same.
 */
const groupsOnDisk = (options) => {
  const root = path.resolve(PROJECT_ROOT, options.scanRoot);
  if (!fs.existsSync(root)) fail(`scan root does not exist: ${options.scanRoot}`);
  const found = new Set();
  for (const item of fs.readdirSync(root, {withFileTypes: true})) {
    if (!item.isDirectory()) {
      found.add(groupOf(item.name, options));
    } else if (options.split.has(item.name)) {
      for (const child of fs.readdirSync(path.join(root, item.name), {withFileTypes: true})) {
        if (child.isDirectory()) found.add(groupOf(`${item.name}/${child.name}/index.ts`, options));
      }
    } else {
      found.add(groupOf(`${item.name}/index.ts`, options));
    }
  }
  return found;
};

const summarise = (report, options) => {
  const groups = new Map([...groupsOnDisk(options)].map((group) => [group, {clones: 0, lines: 0}]));
  let crossGroup = 0;
  for (const clone of report.duplicates) {
    const touched = new Set([groupOf(clone.firstFile.name, options), groupOf(clone.secondFile.name, options)]);
    if (touched.size > 1) crossGroup += 1;
    for (const group of touched) {
      const totals = groups.get(group) ?? {clones: 0, lines: 0};
      totals.clones += 1;
      totals.lines += clone.lines;
      groups.set(group, totals);
    }
  }
  return {groups, crossGroup};
};

const main = () => {
  const options = parseArgs(process.argv.slice(2));
  const reportPath = options.fromReport ?? runDetector(options);

  const report = readReport(reportPath);
  const {groups, crossGroup} = summarise(report, options);
  const total = report.statistics.total;

  const width = Math.max(0, ...[...groups.keys()].map((group) => group.length));
  const rows = [...groups.entries()].sort((a, b) => b[1].lines - a[1].lines || a[0].localeCompare(b[0]));
  for (const [group, totals] of rows) {
    console.log(`  ${group.padEnd(width)}  ${String(totals.lines).padStart(6)} lines  ${totals.clones} clones`);
  }
  console.log(
    `[SUMMARY] make dup-report — ${total.clones} clones, ${total.duplicatedLines} duplicated lines ` +
      `(${Number(total.percentage).toFixed(2)}%) in ${total.sources} files; ${crossGroup} clones span two groups; ` +
      `report: ${displayPath(reportPath)}`
  );
};

main();
