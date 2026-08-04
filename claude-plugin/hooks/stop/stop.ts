#!/usr/bin/env bun
/**
 * Stop Hook: lint, type check, format, then run tests.
 *
 * Everything is scoped to the files Claude edited this session, read from the
 * transcript once and categorised once.
 *
 *   - tsc:      project-wide (only sane mode for graph type checking),
 *               skipped unless TS/JS or tsconfig was edited.
 *   - eslint:   on edited JS/TS files; falls back to the full project when
 *               eslint config or package.json was edited.
 *   - prettier: on edited prettier-able files only, never mass-format.
 *   - tests:    the framework's related-tests mode, or the full suite when a
 *               build/test config changed.
 *
 * Lint errors block before the tests run — a project that doesn't type check
 * has nothing to learn from a two-minute test run.
 *
 * Env:
 *   LINT_ON_SAVE=false        → skip lint, type check and format
 *   LINT_FULL=true            → project-wide for every lint tool
 *   RUN_TESTS_ON_STOP=false   → skip tests
 *   RUN_TESTS_FULL_SUITE=true → always run the full suite
 */

import { dirname, resolve, join, extname, relative, basename } from "path";
import { spawnSync } from "child_process";
import { existsSync } from "fs";

interface StopHookInput {
  stop_hook_active?: boolean;
  transcript_path?: string;
}

const TS_JS_EXTENSIONS = new Set([
  ".ts",
  ".tsx",
  ".js",
  ".jsx",
  ".mjs",
  ".mts",
  ".cjs",
  ".cts",
]);

const PRETTIER_EXTENSIONS = new Set([
  ".ts",
  ".tsx",
  ".js",
  ".jsx",
  ".mjs",
  ".mts",
  ".svelte",
  ".md",
  ".mdx",
  ".json",
  ".yaml",
  ".yml",
  ".css",
  ".scss",
  ".html",
]);

// Editing these says nothing about whether the code still works, and a lockfile
// is machine-written — reformatting one is noise, not a fix.
const SKIP_EXTENSIONS = new Set([".txt", ".rst", ".adoc"]);
const SKIP_BASENAMES = new Set([
  "LICENSE",
  "LICENCE",
  "CHANGELOG",
  "CHANGELOG.md",
  ".gitignore",
  ".gitattributes",
  ".editorconfig",
  ".prettierignore",
  ".npmignore",
  "bun.lockb",
  "bun.lock",
  "package-lock.json",
  "yarn.lock",
  "pnpm-lock.yaml",
]);

// Docs are worth formatting but carry no code, so they get prettier and nothing else.
const DOC_EXTENSIONS = new Set([".md", ".mdx"]);

const LOCKFILES = [
  "bun.lock",
  "bun.lockb",
  "package-lock.json",
  "yarn.lock",
  "pnpm-lock.yaml",
];

const TSCONFIG_PATTERN = /(?:^|\/)tsconfig[^/]*\.json$/;
const ESLINT_CONFIG_PATTERN =
  /(?:^|\/)(?:eslint\.config\.[cm]?[jt]sx?|\.eslintrc(?:\.[a-z]+)?)$/;
// Anything that changes how the suite is built or run → run all of it.
const TEST_CONFIG_PATTERN =
  /(?:^|\/)(?:package\.json|tsconfig[^/]*\.json|[a-z]+\.config\.[cm]?[jt]sx?|\.(?:babelrc|mocharc)(?:\.[a-z]+)?)$/;
const TEST_FILE_PATTERN = /[._](?:test|spec)\.[jt]sx?$/;

type Framework = "vitest" | "jest" | "mocha" | "bun";
type PackageManager = "bun" | "pnpm" | "yarn" | "npm";

interface TestSetup {
  framework?: Framework;
  binPath?: string;
  fullSuiteCommand: string[];
}

async function readStdin(): Promise<string> {
  const chunks: Buffer[] = [];
  for await (const chunk of Bun.stdin.stream()) {
    chunks.push(chunk as Buffer);
  }
  return Buffer.concat(chunks).toString("utf-8");
}

async function readJson(path: string): Promise<Record<string, any> | null> {
  try {
    return await Bun.file(path).json();
  } catch {
    return null;
  }
}

async function hasLockfile(dir: string): Promise<boolean> {
  for (const lock of LOCKFILES) {
    if (await Bun.file(join(dir, lock)).exists()) return true;
  }
  return false;
}

// Walk up to the workspace root — the directory whose package.json sits beside a
// lockfile, a .git, or a `workspaces` field. That is where node_modules/.bin
// lives, so it is the only root both eslint and the test runner can be launched
// from. Falls back to the nearest package.json.
async function findProjectRoot(start: string): Promise<string | null> {
  let dir = start;
  let nearest: string | null = null;

  while (dir !== dirname(dir)) {
    const pkg = join(dir, "package.json");
    const hasPkg = await Bun.file(pkg).exists();
    const lock = await hasLockfile(dir);

    if (hasPkg || lock) {
      nearest ??= dir;
      // A lockfile with no package.json is a bun project; `bun test` handles it.
      if (lock || existsSync(join(dir, ".git"))) return dir;
      if ((await readJson(pkg))?.workspaces) return dir;
    }
    dir = dirname(dir);
  }

  return nearest;
}

// Absolute paths Claude edited this session, still on disk. Files written and
// later deleted must be dropped: eslint and prettier fatal-error on a missing path.
async function getEditedFiles(
  transcriptPath: string | undefined,
  projectRoot: string,
): Promise<string[]> {
  if (!transcriptPath) return [];
  const file = Bun.file(transcriptPath);
  if (!(await file.exists())) return [];

  const editTools = new Set(["Edit", "Write", "MultiEdit", "NotebookEdit"]);
  const seen = new Set<string>();

  for (const line of (await file.text()).split("\n")) {
    if (!line.trim()) continue;
    let entry: unknown;
    try {
      entry = JSON.parse(line);
    } catch {
      continue;
    }

    const content = (entry as { message?: { content?: unknown } })?.message
      ?.content;
    if (!Array.isArray(content)) continue;

    for (const block of content) {
      if (
        block?.type !== "tool_use" ||
        typeof block.name !== "string" ||
        !editTools.has(block.name)
      ) {
        continue;
      }
      const fp = (block.input as { file_path?: unknown } | undefined)
        ?.file_path;
      if (typeof fp !== "string") continue;
      const abs = resolve(fp);
      if (
        (abs.startsWith(projectRoot + "/") || abs === projectRoot) &&
        !abs.includes("/node_modules/")
      ) {
        seen.add(abs);
      }
    }
  }

  const paths = [...seen];
  const alive = await Promise.all(paths.map((p) => Bun.file(p).exists()));
  return paths.filter((_, i) => alive[i]);
}

interface Categorized {
  tsJsFiles: string[];
  prettierFiles: string[];
  tests: string[];
  sources: string[];
  tsConfigChanged: boolean;
  eslintConfigChanged: boolean;
  packageJsonChanged: boolean;
  testConfigChanged: boolean;
  hasCode: boolean;
}

function categorize(files: string[], projectRoot: string): Categorized {
  const c: Categorized = {
    tsJsFiles: [],
    prettierFiles: [],
    tests: [],
    sources: [],
    tsConfigChanged: false,
    eslintConfigChanged: false,
    packageJsonChanged: false,
    testConfigChanged: false,
    hasCode: false,
  };

  for (const abs of files) {
    const ext = extname(abs);
    const base = basename(abs);
    const rel = relative(projectRoot, abs);

    if (SKIP_EXTENSIONS.has(ext) || SKIP_BASENAMES.has(base)) continue;

    if (DOC_EXTENSIONS.has(ext)) {
      c.prettierFiles.push(abs);
      continue;
    }

    c.hasCode = true;
    if (PRETTIER_EXTENSIONS.has(ext)) c.prettierFiles.push(abs);

    if (base === "package.json") c.packageJsonChanged = true;
    if (TSCONFIG_PATTERN.test(rel)) c.tsConfigChanged = true;
    if (ESLINT_CONFIG_PATTERN.test(rel)) c.eslintConfigChanged = true;

    if (TEST_CONFIG_PATTERN.test(rel)) {
      c.testConfigChanged = true;
      continue;
    }

    if (TS_JS_EXTENSIONS.has(ext)) {
      c.tsJsFiles.push(abs);
      (TEST_FILE_PATTERN.test(base) ? c.tests : c.sources).push(abs);
    }
  }

  return c;
}

function runCommand(
  command: string[],
  cwd: string,
  timeoutMs: number,
): { success: boolean; output: string; status: number | null } {
  const result = spawnSync(command[0], command.slice(1), {
    cwd,
    encoding: "utf-8",
    timeout: timeoutMs,
    env: { ...process.env, FORCE_COLOR: "0", CI: "true" },
  });

  const parts = [result.stdout, result.stderr].filter(Boolean);
  if (result.signal) parts.push(`Killed by ${result.signal}`);
  if (result.error) parts.push(result.error.message);

  return {
    success: result.status === 0 && !result.signal && !result.error,
    output: parts.join("\n").trim(),
    status: result.status,
  };
}

async function binExists(
  projectRoot: string,
  name: string,
): Promise<string | null> {
  const path = resolve(projectRoot, "node_modules", ".bin", name);
  return (await Bun.file(path).exists()) ? path : null;
}

// One glob per tool instead of a hand-kept list of every config filename.
async function hasConfig(projectRoot: string, glob: string): Promise<boolean> {
  for await (const _ of new Bun.Glob(glob).scan({
    cwd: projectRoot,
    dot: true,
    onlyFiles: false,
  })) {
    return true;
  }
  return false;
}

async function lint(
  projectRoot: string,
  c: Categorized,
  forceFull: boolean,
  errors: string[],
  warnings: string[],
): Promise<void> {
  // ── TypeScript (project-wide; the only mode that makes sense for graph checks) ──
  if (
    forceFull ||
    c.tsJsFiles.length > 0 ||
    c.tsConfigChanged ||
    c.packageJsonChanged
  ) {
    const tsc = await binExists(projectRoot, "tsc");
    if (tsc && (await Bun.file(join(projectRoot, "tsconfig.json")).exists())) {
      const r = runCommand(
        [tsc, "--noEmit", "--skipLibCheck"],
        projectRoot,
        30000,
      );
      if (!r.success && r.output)
        errors.push(`TypeScript errors:\n${r.output}`);
    }
  }

  // ── ESLint (scoped to edited JS/TS unless config or package.json changed) ──
  const eslint = await binExists(projectRoot, "eslint");
  if (
    eslint &&
    (await hasConfig(projectRoot, "{eslint.config.*,.eslintrc*}"))
  ) {
    const targets =
      forceFull || c.eslintConfigChanged || c.packageJsonChanged
        ? ["."]
        : c.tsJsFiles.map((f) => relative(projectRoot, f));

    if (targets.length > 0) {
      const r = runCommand(
        [
          eslint,
          "--format",
          "stylish",
          "--no-error-on-unmatched-pattern",
          ...targets,
        ],
        projectRoot,
        30000,
      );
      if (r.output) {
        if (r.status === 1) errors.push(`ESLint errors:\n${r.output}`);
        else if (r.status === 2) errors.push(`ESLint fatal:\n${r.output}`);
        else if (r.status === 0) warnings.push(`ESLint warnings:\n${r.output}`);
      }
    }
  }

  // ── Prettier (always scoped to edited files; never mass-format) ──
  if (c.prettierFiles.length === 0) return;
  const prettier = await binExists(projectRoot, "prettier");
  if (!prettier) return;

  const configured =
    (await hasConfig(projectRoot, "{prettier.config.*,.prettierrc*}")) ||
    !!(await readJson(join(projectRoot, "package.json")))?.prettier;
  if (!configured) return;

  // --list-different alongside --write names only the files that changed, so one
  // run replaces the old check-then-write pass over every file.
  const r = runCommand(
    [prettier, "--write", "--list-different", ...c.prettierFiles],
    projectRoot,
    30000,
  );
  if (!r.success) errors.push(`Prettier errors:\n${r.output}`);
  else if (r.output) warnings.push(`Prettier: auto-formatted\n${r.output}`);
}

async function detectPackageManager(dir: string): Promise<PackageManager> {
  if (
    (await Bun.file(join(dir, "bun.lockb")).exists()) ||
    (await Bun.file(join(dir, "bun.lock")).exists())
  ) {
    return "bun";
  }
  if (await Bun.file(join(dir, "pnpm-lock.yaml")).exists()) return "pnpm";
  if (await Bun.file(join(dir, "yarn.lock")).exists()) return "yarn";
  return "npm";
}

async function detectTestSetup(dir: string): Promise<TestSetup | null> {
  const pm = await detectPackageManager(dir);
  const pkg = await readJson(join(dir, "package.json"));
  const deps: Record<string, string> = {
    ...(pkg?.dependencies ?? {}),
    ...(pkg?.devDependencies ?? {}),
  };

  let framework: Framework | undefined;
  let binPath: string | undefined;
  for (const candidate of ["vitest", "jest", "mocha"] as const) {
    if (!deps[candidate]) continue;
    const found = await binExists(dir, candidate);
    if (found) {
      framework = candidate;
      binPath = found;
      break;
    }
  }

  // Prefer the package manager's `test` script when defined — it may layer on
  // setup the bare runner misses, such as a build step or env vars.
  const testScript = pkg?.scripts?.test;
  const hasTestScript =
    !!testScript && testScript !== 'echo "Error: no test specified" && exit 1';

  let fullSuiteCommand: string[];
  if (hasTestScript) {
    fullSuiteCommand = pm === "bun" ? ["bun", "run", "test"] : [pm, "test"];
  } else if (framework === "vitest") {
    fullSuiteCommand = [binPath!, "run"];
  } else if (framework) {
    fullSuiteCommand = [binPath!];
  } else if (pm === "bun") {
    fullSuiteCommand = ["bun", "test"];
  } else {
    return null;
  }

  return {
    framework: framework ?? (pm === "bun" ? "bun" : undefined),
    binPath,
    fullSuiteCommand,
  };
}

function buildTestCommand(
  setup: TestSetup,
  c: Categorized,
  projectRoot: string,
): string[] {
  if (c.testConfigChanged) return setup.fullSuiteCommand;

  const all = [...c.tests, ...c.sources];
  if (all.length === 0) return setup.fullSuiteCommand;
  const rel = all.map((f) => relative(projectRoot, f));

  if (setup.framework === "vitest" && setup.binPath) {
    return [setup.binPath, "related", ...rel, "--run"];
  }
  if (setup.framework === "jest" && setup.binPath) {
    return [setup.binPath, "--findRelatedTests", "--passWithNoTests", ...rel];
  }
  // bun test has no related mode; it takes paths, so narrowing is only safe
  // when every edit was itself a test file.
  if (
    setup.framework === "bun" &&
    c.sources.length === 0 &&
    c.tests.length > 0
  ) {
    return ["bun", "test", ...c.tests.map((f) => relative(projectRoot, f))];
  }
  return setup.fullSuiteCommand;
}

function block(reason: string): never {
  console.log(JSON.stringify({ decision: "block", reason }));
  process.exit(0);
}

async function main() {
  const lintEnabled = process.env.LINT_ON_SAVE !== "false";
  const testsEnabled = process.env.RUN_TESTS_ON_STOP !== "false";
  if (!lintEnabled && !testsEnabled) process.exit(0);

  let input: StopHookInput = {};
  try {
    const stdin = await readStdin();
    if (stdin.trim()) input = JSON.parse(stdin);
  } catch {
    // Continue with empty input
  }
  if (input.stop_hook_active) process.exit(0);

  const projectRoot = await findProjectRoot(process.cwd());
  if (!projectRoot) process.exit(0);

  const lintFull = process.env.LINT_FULL === "true";
  const testsFull = process.env.RUN_TESTS_FULL_SUITE === "true";

  const c = categorize(
    await getEditedFiles(input.transcript_path, projectRoot),
    projectRoot,
  );

  // Nothing functional changed and nothing formattable was touched → skip.
  if (!lintFull && !testsFull && !c.hasCode && c.prettierFiles.length === 0) {
    process.exit(0);
  }

  const errors: string[] = [];
  const warnings: string[] = [];

  if (lintEnabled) {
    await lint(projectRoot, c, lintFull, errors, warnings);
    if (errors.length > 0) {
      block(
        `Lint/type errors found. Please fix before stopping.\n\n${errors.join("\n\n")}`,
      );
    }
  }

  if (testsEnabled && (testsFull || c.hasCode)) {
    const setup = await detectTestSetup(projectRoot);
    if (setup) {
      const command = testsFull
        ? setup.fullSuiteCommand
        : buildTestCommand(setup, c, projectRoot);
      const r = runCommand(command, projectRoot, 120000);
      if (!r.success) {
        block(
          `Tests failed. Please fix the failing tests before stopping.\n\n$ ${command.join(" ")}\n\n${r.output}`,
        );
      }
    }
  }

  if (warnings.length > 0) console.log(warnings.join("\n\n"));
  process.exit(0);
}

main();
