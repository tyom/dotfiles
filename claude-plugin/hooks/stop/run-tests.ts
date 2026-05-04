#!/usr/bin/env bun
/**
 * Stop Hook: Run Tests (related-files mode)
 *
 * Runs only the tests relevant to files Claude edited this session.
 * Skips entirely if no functional changes were made.
 *
 * Strategy:
 *   1. Parse the session transcript for Edit/Write/MultiEdit tool calls.
 *   2. Drop docs/lockfile-only edits → skip.
 *   3. Run the full suite if a config file changed (vitest.config, package.json, etc.).
 *   4. Otherwise, invoke the framework's related-tests mode:
 *        - vitest → `vitest related <files> --run`
 *        - jest   → `jest --findRelatedTests <files>`
 *        - bun    → no native related mode; if only test files were edited, run those;
 *                   otherwise fall back to the full suite.
 *        - other  → fall back to the full suite.
 *
 * Env:
 *   RUN_TESTS_ON_STOP=false   → skip entirely
 *   RUN_TESTS_FULL_SUITE=true → always run the full suite (ignore related mode)
 */

import { resolve, join, relative, basename, extname } from "path";
import { spawnSync } from "child_process";

interface StopHookInput {
  stop_hook_active?: boolean;
  transcript_path?: string;
}

type Framework = "vitest" | "jest" | "mocha" | "bun";
type PackageManager = "bun" | "pnpm" | "yarn" | "npm";

interface TestSetup {
  framework?: Framework;
  packageManager: PackageManager;
  binPath?: string;
  fullSuiteCommand: string[];
  cwd: string;
}

const CWD = process.cwd();

const TEST_FILE_PATTERNS = [
  /\.test\.[jt]sx?$/,
  /\.spec\.[jt]sx?$/,
  /_test\.[jt]sx?$/,
  /_spec\.[jt]sx?$/,
];

const SKIP_EXTENSIONS = new Set([".md", ".mdx", ".txt", ".rst", ".adoc"]);

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

const CONFIG_FILE_PATTERNS = [
  /(?:^|\/)package\.json$/,
  /(?:^|\/)tsconfig[^/]*\.json$/,
  /(?:^|\/)vitest\.config\.[cm]?[jt]sx?$/,
  /(?:^|\/)jest\.config\.[cm]?[jt]sx?$/,
  /(?:^|\/)mocha\.config\.[cm]?[jt]sx?$/,
  /(?:^|\/)\.mocharc(?:\.[a-z]+)?$/,
  /(?:^|\/)babel\.config\.[cm]?[jt]sx?$/,
  /(?:^|\/)\.babelrc(?:\.[a-z]+)?$/,
  /(?:^|\/)vite\.config\.[cm]?[jt]sx?$/,
  /(?:^|\/)rollup\.config\.[cm]?[jt]sx?$/,
  /(?:^|\/)webpack\.config\.[cm]?[jt]sx?$/,
  /(?:^|\/)esbuild\.config\.[cm]?[jt]sx?$/,
  /(?:^|\/)tsup\.config\.[cm]?[jt]sx?$/,
  /(?:^|\/)swc\.config\.[cm]?[jt]sx?$/,
];

async function readStdin(): Promise<string> {
  const chunks: Buffer[] = [];
  for await (const chunk of Bun.stdin.stream()) {
    chunks.push(chunk as Buffer);
  }
  return Buffer.concat(chunks).toString("utf-8");
}

async function findProjectRoot(start: string): Promise<string> {
  let current = start;
  while (current !== resolve(current, "..")) {
    if (await Bun.file(join(current, "package.json")).exists()) {
      return current;
    }
    current = resolve(current, "..");
  }
  return start;
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

async function detectFrameworkBin(
  dir: string,
  deps: Record<string, string>,
): Promise<{ framework: Framework; binPath: string } | null> {
  const candidates: Framework[] = ["vitest", "jest", "mocha"];
  for (const framework of candidates) {
    if (!deps[framework]) continue;
    const binPath = resolve(dir, "node_modules", ".bin", framework);
    if (await Bun.file(binPath).exists()) {
      return { framework, binPath };
    }
  }
  return null;
}

async function detectTestSetup(dir: string): Promise<TestSetup | null> {
  const pkgFile = Bun.file(join(dir, "package.json"));
  const packageManager = await detectPackageManager(dir);

  if (!(await pkgFile.exists())) {
    // Bun project without package.json — rare but supported by `bun test`.
    if (packageManager === "bun") {
      return {
        framework: "bun",
        packageManager,
        fullSuiteCommand: ["bun", "test"],
        cwd: dir,
      };
    }
    return null;
  }

  let pkg: Record<string, unknown>;
  try {
    pkg = await pkgFile.json();
  } catch {
    return null;
  }

  const deps: Record<string, string> = {
    ...((pkg.dependencies as Record<string, string>) ?? {}),
    ...((pkg.devDependencies as Record<string, string>) ?? {}),
  };
  const scripts = pkg.scripts as Record<string, string> | undefined;
  const hasTestScript =
    !!scripts?.test &&
    scripts.test !== 'echo "Error: no test specified" && exit 1';

  const detected = await detectFrameworkBin(dir, deps);

  // Build the full-suite command, preferring the package manager's `test` script
  // when defined (it may layer setup like build steps or env vars).
  let fullSuiteCommand: string[];
  if (hasTestScript) {
    fullSuiteCommand =
      packageManager === "bun"
        ? ["bun", "run", "test"]
        : packageManager === "pnpm"
          ? ["pnpm", "test"]
          : packageManager === "yarn"
            ? ["yarn", "test"]
            : ["npm", "test"];
  } else if (detected?.framework === "vitest") {
    fullSuiteCommand = [detected.binPath, "run"];
  } else if (detected) {
    fullSuiteCommand = [detected.binPath];
  } else if (packageManager === "bun") {
    fullSuiteCommand = ["bun", "test"];
    return {
      framework: "bun",
      packageManager,
      fullSuiteCommand,
      cwd: dir,
    };
  } else {
    return null;
  }

  return {
    framework: detected?.framework ?? (packageManager === "bun" ? "bun" : undefined),
    packageManager,
    binPath: detected?.binPath,
    fullSuiteCommand,
    cwd: dir,
  };
}

async function getEditedFiles(
  transcriptPath: string | undefined,
  projectRoot: string,
): Promise<Set<string>> {
  const edited = new Set<string>();
  if (!transcriptPath) return edited;

  const file = Bun.file(transcriptPath);
  if (!(await file.exists())) return edited;

  const text = await file.text();
  const editTools = new Set(["Edit", "Write", "MultiEdit", "NotebookEdit"]);

  for (const line of text.split("\n")) {
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
      const fp = (block.input as { file_path?: unknown } | undefined)?.file_path;
      if (typeof fp !== "string") continue;
      const abs = resolve(fp);
      if (abs.startsWith(projectRoot + "/") || abs === projectRoot) {
        edited.add(abs);
      }
    }
  }

  return edited;
}

interface Categorized {
  tests: string[];
  sources: string[];
  hasConfig: boolean;
  hasNonSkip: boolean;
}

function categorize(files: Set<string>, projectRoot: string): Categorized {
  const tests: string[] = [];
  const sources: string[] = [];
  let hasConfig = false;
  let hasNonSkip = false;

  for (const abs of files) {
    const base = basename(abs);
    const ext = extname(abs);
    const rel = relative(projectRoot, abs);

    if (SKIP_EXTENSIONS.has(ext) || SKIP_BASENAMES.has(base)) continue;

    hasNonSkip = true;

    if (CONFIG_FILE_PATTERNS.some((p) => p.test(rel))) {
      hasConfig = true;
      continue;
    }

    if (TEST_FILE_PATTERNS.some((p) => p.test(base))) {
      tests.push(abs);
    } else if (/\.[jt]sx?$/.test(base)) {
      sources.push(abs);
    }
    // Other file types (e.g. .css, .json fixtures) — ignore for related mode;
    // hasNonSkip stays true so we don't accidentally skip when only assets changed
    // and a related-mode runner can't help us.
  }

  return { tests, sources, hasConfig, hasNonSkip };
}

function buildRunCommand(
  setup: TestSetup,
  categorized: Categorized,
): string[] {
  if (categorized.hasConfig) return setup.fullSuiteCommand;

  const all = [...categorized.tests, ...categorized.sources];
  if (all.length === 0) return setup.fullSuiteCommand;

  const rel = all.map((f) => relative(setup.cwd, f));

  if (setup.framework === "vitest" && setup.binPath) {
    return [setup.binPath, "related", ...rel, "--run"];
  }
  if (setup.framework === "jest" && setup.binPath) {
    return [setup.binPath, "--findRelatedTests", ...rel];
  }
  if (setup.framework === "bun") {
    // bun test takes file paths; only safe to narrow when all edits are test files.
    if (categorized.sources.length === 0 && categorized.tests.length > 0) {
      return ["bun", "test", ...categorized.tests.map((f) => relative(setup.cwd, f))];
    }
  }
  return setup.fullSuiteCommand;
}

function runCommand(
  command: string[],
  cwd: string,
): { success: boolean; output: string } {
  const result = spawnSync(command[0], command.slice(1), {
    cwd,
    encoding: "utf-8",
    timeout: 120000,
    env: { ...process.env, FORCE_COLOR: "0", CI: "true" },
  });
  const output = [result.stdout, result.stderr]
    .filter(Boolean)
    .join("\n")
    .trim();
  return { success: result.status === 0, output };
}

async function main() {
  if (process.env.RUN_TESTS_ON_STOP === "false") process.exit(0);

  let input: StopHookInput = {};
  try {
    const stdin = await readStdin();
    if (stdin.trim()) input = JSON.parse(stdin);
  } catch {
    // Continue with empty input
  }

  if (input.stop_hook_active) process.exit(0);

  const projectRoot = await findProjectRoot(CWD);
  const setup = await detectTestSetup(projectRoot);
  if (!setup) process.exit(0);

  const forceFull = process.env.RUN_TESTS_FULL_SUITE === "true";
  let command: string[];

  if (forceFull) {
    command = setup.fullSuiteCommand;
  } else {
    const edited = await getEditedFiles(input.transcript_path, projectRoot);
    const categorized = categorize(edited, projectRoot);

    // No edits, or only docs/lockfiles/etc. → no functional change, skip tests.
    if (!categorized.hasNonSkip) process.exit(0);

    command = buildRunCommand(setup, categorized);
  }

  const result = runCommand(command, setup.cwd);

  if (!result.success) {
    const decision = {
      decision: "block",
      reason: `Tests failed. Please fix the failing tests before stopping.\n\n$ ${command.join(" ")}\n\n${result.output}`,
    };
    console.log(JSON.stringify(decision));
  }

  process.exit(0);
}

main();
