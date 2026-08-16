// @ts-check
/**
 * Stop Hook: lint, type check, format, then run tests.
 *
 * Everything is scoped to the files Claude edited this session, read from the
 * transcript once and categorised once. hooks/README.md has the per-tool scope
 * table and the env vars; this file is the implementation of it.
 *
 * Lint errors block before the tests run — a project that doesn't type check
 * has nothing to learn from a two-minute test run.
 *
 * Plain JS on node: builtins only, so node, deno and bun all run it as-is with
 * nothing installed. The types are JSDoc: an editor checks them, and no
 * dependency is needed to do it.
 */

import { dirname, resolve, join, extname, relative, basename } from "node:path";
import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { readFile, readdir } from "node:fs/promises";
import { text } from "node:stream/consumers";

/**
 * @typedef {object} StopHookInput
 * @property {boolean} [stop_hook_active]
 * @property {string} [transcript_path]
 */

/** @typedef {"vitest" | "jest" | "mocha" | "bun"} Framework */
/** @typedef {"bun" | "pnpm" | "yarn" | "npm"} PackageManager */

// One list, three jobs: the project-root marker, the package-manager map, and
// part of SKIP_BASENAMES below. Ordered — the first match names the manager.
/** @type {[string, PackageManager][]} */
const LOCKFILES = [
  ["bun.lock", "bun"],
  ["bun.lockb", "bun"],
  ["pnpm-lock.yaml", "pnpm"],
  ["yarn.lock", "yarn"],
  ["package-lock.json", "npm"],
];

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
  ...LOCKFILES.map(([name]) => name),
]);

// Docs are worth formatting but carry no code, so they get prettier and nothing else.
const DOC_EXTENSIONS = new Set([".md", ".mdx"]);

const TSCONFIG_PATTERN = /(?:^|\/)tsconfig[^/]*\.json$/;
const ESLINT_CONFIG_PATTERN =
  /(?:^|\/)(?:eslint\.config\.[cm]?[jt]sx?|\.eslintrc(?:\.[a-z]+)?)$/;
// Anything that changes how the suite is built or run → run all of it. Named
// runners and bundlers only: a bare `[a-z]+\.config\.` also catches
// tailwind/next/postcss/drizzle, so a one-line style tweak would cost a full
// suite for the rest of the session. package.json and tsconfig are folded in at
// the call site rather than spelled out here a second time.
const TEST_CONFIG_PATTERN =
  /(?:^|\/)(?:(?:vitest|jest|mocha|playwright|vite|babel|rollup|webpack|esbuild|tsup|swc)\.config\.[cm]?[jt]sx?|\.(?:babelrc|mocharc)(?:\.[a-z]+)?)$/;
const TEST_FILE_PATTERN = /[._](?:test|spec)\.[jt]sx?$/;

// Matched against a directory listing rather than a glob, so there is no pattern
// library to depend on. eslint reuses ESLINT_CONFIG_PATTERN above: its `(?:^|\/)`
// prefix matches a bare basename just as well as a path.
const PRETTIER_CONFIG_FILE = /^(?:prettier\.config\.|\.prettierrc)/;

// One budget for the whole run, sitting under the timeout in hooks.json. A hook
// the harness kills never writes its decision, so failing tests would read as a
// clean stop — each tool gets what is actually left, not its own fixed slice.
const DEADLINE = Date.now() + 140_000;
/** @param {number} cap */
const budget = (cap) => Math.min(cap, Math.max(1000, DEADLINE - Date.now()));

/**
 * @typedef {object} TestSetup
 * @property {Framework} [framework]
 * @property {string} [binPath]
 * @property {string[]} fullSuiteCommand
 */

/**
 * @param {string} path
 * @returns {Promise<Record<string, any> | null>}
 */
async function readJson(path) {
  try {
    return JSON.parse(await readFile(path, "utf8"));
  } catch {
    return null;
  }
}

/** @param {string} dir */
const hasLockfile = (dir) =>
  LOCKFILES.some(([name]) => existsSync(join(dir, name)));

// Walk up to the workspace root — the directory whose package.json sits beside a
// lockfile, a .git, or a `workspaces` field. That is where node_modules/.bin
// lives, so it is the only root both eslint and the test runner can be launched
// from. Falls back to the nearest package.json.
/**
 * @param {string} start
 * @returns {Promise<string | null>}
 */
async function findProjectRoot(start) {
  let dir = start;
  /** @type {string | null} */
  let nearest = null;

  while (dir !== dirname(dir)) {
    const pkg = join(dir, "package.json");
    const hasPkg = existsSync(pkg);
    const lock = hasLockfile(dir);

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

// Absolute paths Claude edited this session, as claimed by the transcript.
// null, not [], when there is no transcript here to read: the file is missing,
// or every line is in some other agent's format. Codex sends a transcript path
// too, pointing at its own rollout log, and none of it parses as Claude's tool
// calls. The caller falls back to git for that; an empty Claude transcript is a
// real answer and stays empty.
/**
 * @param {string} transcriptPath
 * @param {string} projectRoot
 * @returns {Promise<string[] | null>}
 */
async function getEditedFiles(transcriptPath, projectRoot) {
  if (!existsSync(transcriptPath)) return null;

  const editTools = new Set(["Edit", "Write", "MultiEdit", "NotebookEdit"]);
  /** @type {Set<string>} */
  const seen = new Set();
  let readable = false;

  for (const line of (await readFile(transcriptPath, "utf8")).split("\n")) {
    if (!line.trim()) continue;
    let entry;
    try {
      entry = JSON.parse(line);
    } catch {
      continue;
    }

    // One line in the shape this parser expects is enough to call the file ours:
    // a session that only read code still has assistant messages in it.
    const content = entry?.message?.content;
    if (!Array.isArray(content)) continue;
    readable = true;

    for (const block of content) {
      if (
        block?.type !== "tool_use" ||
        typeof block.name !== "string" ||
        !editTools.has(block.name)
      ) {
        continue;
      }
      const fp = block.input?.file_path;
      if (typeof fp !== "string") continue;
      const abs = resolve(fp);
      if (abs.startsWith(projectRoot + "/") || abs === projectRoot) {
        seen.add(abs);
      }
    }
  }

  return readable ? [...seen] : null;
}

// Both sources hand over raw candidates, so what counts as a file worth checking
// is decided once. Files written and later deleted have to go: eslint and
// prettier fatal-error on a missing path, and `git diff HEAD` lists deletions as
// a matter of course.
/** @param {string[]} files */
const worthChecking = (files) =>
  files.filter((f) => !f.includes("/node_modules/") && existsSync(f));

// Codex fires Stop but sends no transcript_path, so there is no record of what
// the agent touched. The working tree is the neutral answer: what changed since
// HEAD, plus anything new that git is not ignoring. Wider than the transcript —
// a file edited by hand counts too — which is why it is only the fallback.
/** @param {string} projectRoot */
function gitChangedFiles(projectRoot) {
  // --relative scopes the output to projectRoot and prints paths relative to it,
  // which matters when the project is one package inside a larger repo. -z keeps
  // paths intact when they contain spaces or non-ASCII.
  const run = (/** @type {string[]} */ args) =>
    runCommand(["git", "-C", projectRoot, ...args], projectRoot, budget(5_000));

  // A repo with no commits has no HEAD to diff, and everything in it is
  // untracked anyway, so a failure here is not worth reporting.
  const tracked = run(["diff", "-z", "--name-only", "--relative", "HEAD"]);
  const untracked = run(["ls-files", "-z", "--others", "--exclude-standard"]);

  return [tracked, untracked]
    .filter((r) => r.success)
    .flatMap((r) => r.output.split("\0"))
    .filter(Boolean)
    .map((p) => resolve(projectRoot, p));
}

/**
 * @typedef {object} Categorized
 * @property {string[]} prettierFiles
 * @property {string[]} codeFiles Every edited code file, and the targets for a
 *   related-tests run — not only the TS/JS ones. `vitest related` and
 *   `jest --findRelatedTests` resolve a stylesheet or a JSON fixture back to the
 *   tests that import it, so scoping by them beats falling through to the whole
 *   suite.
 * @property {string[]} testFiles The subset of codeFiles that are themselves test files.
 * @property {boolean} tsConfigChanged
 * @property {boolean} eslintConfigChanged
 * @property {boolean} packageJsonChanged
 * @property {boolean} testConfigChanged
 * @property {boolean} hasCode
 */

/**
 * @param {string[]} files
 * @param {string} projectRoot
 */
function categorize(files, projectRoot) {
  /** @type {Categorized} */
  const c = {
    prettierFiles: [],
    codeFiles: [],
    testFiles: [],
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

    const isPackageJson = base === "package.json";
    const isTsConfig = TSCONFIG_PATTERN.test(rel);
    if (isPackageJson) c.packageJsonChanged = true;
    if (isTsConfig) c.tsConfigChanged = true;
    if (ESLINT_CONFIG_PATTERN.test(rel)) c.eslintConfigChanged = true;

    if (isPackageJson || isTsConfig || TEST_CONFIG_PATTERN.test(rel)) {
      c.testConfigChanged = true;
      continue;
    }

    c.codeFiles.push(abs);
    if (TS_JS_EXTENSIONS.has(ext) && TEST_FILE_PATTERN.test(base)) {
      c.testFiles.push(abs);
    }
  }

  return c;
}

/**
 * @param {string[]} command
 * @param {string} cwd
 * @param {number} timeoutMs
 */
function runCommand(command, cwd, timeoutMs) {
  const result = spawnSync(command[0], command.slice(1), {
    cwd,
    encoding: "utf-8",
    timeout: timeoutMs,
    // The default (a few MB) is under what a verbose suite prints, and going over
    // it is an ENOBUFS error — a passing run would read as a failure and block.
    maxBuffer: 64 * 1024 * 1024,
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

/**
 * @param {string} projectRoot
 * @param {string} name
 */
function binPath(projectRoot, name) {
  const path = resolve(projectRoot, "node_modules", ".bin", name);
  return existsSync(path) ? path : null;
}

// One directory listing per tool instead of a hand-kept list of every config
// filename.
/**
 * @param {string} projectRoot
 * @param {RegExp} pattern
 */
async function hasConfig(projectRoot, pattern) {
  try {
    return (await readdir(projectRoot)).some((name) => pattern.test(name));
  } catch {
    return false;
  }
}

/**
 * @param {string} projectRoot
 * @param {Categorized} c
 * @param {boolean} forceFull
 */
async function lint(projectRoot, c, forceFull) {
  /** @type {string[]} */
  const errors = [];
  /** @type {string[]} */
  const warnings = [];
  // Lint only understands TS/JS, so it takes a narrower slice than the tests do.
  const tsJsFiles = c.codeFiles.filter((f) => TS_JS_EXTENSIONS.has(extname(f)));

  // ── TypeScript (project-wide; the only mode that makes sense for graph checks) ──
  if (
    forceFull ||
    tsJsFiles.length > 0 ||
    c.tsConfigChanged ||
    c.packageJsonChanged
  ) {
    const tsc = binPath(projectRoot, "tsc");
    if (tsc && existsSync(join(projectRoot, "tsconfig.json"))) {
      const r = runCommand(
        [tsc, "--noEmit", "--skipLibCheck"],
        projectRoot,
        budget(30_000),
      );
      if (!r.success && r.output)
        errors.push(`TypeScript errors:\n${r.output}`);
    }
  }

  // ── ESLint (scoped to edited JS/TS unless config or package.json changed) ──
  const eslint = binPath(projectRoot, "eslint");
  if (eslint && (await hasConfig(projectRoot, ESLINT_CONFIG_PATTERN))) {
    const targets =
      forceFull || c.eslintConfigChanged || c.packageJsonChanged
        ? ["."]
        : tsJsFiles.map((f) => relative(projectRoot, f));

    if (targets.length > 0) {
      const r = runCommand(
        [
          eslint,
          "--format",
          "stylish",
          "--no-error-on-unmatched-pattern",
          // Scoped runs pass edited files blind to the project's ignores, so a
          // repo with an ignored subtree (a standalone package with its own
          // tooling, say) reports "File ignored" on exit 0 — which lands in
          // warnings. Only silences that notice; real warnings still surface.
          "--no-warn-ignored",
          ...targets,
        ],
        projectRoot,
        budget(30_000),
      );
      if (!r.success) {
        errors.push(`ESLint failed:\n${r.output || "No error output"}`);
      } else if (r.output) {
        warnings.push(`ESLint warnings:\n${r.output}`);
      }
    }
  }

  // ── Prettier (always scoped to edited files; never mass-format) ──
  const prettier =
    c.prettierFiles.length > 0 ? binPath(projectRoot, "prettier") : null;
  const configured =
    !!prettier &&
    ((await hasConfig(projectRoot, PRETTIER_CONFIG_FILE)) ||
      !!(await readJson(join(projectRoot, "package.json")))?.prettier);

  if (prettier && configured) {
    // --list-different alongside --write names only the files that changed, so one
    // run replaces the old check-then-write pass over every file.
    const r = runCommand(
      [prettier, "--write", "--list-different", ...c.prettierFiles],
      projectRoot,
      budget(30_000),
    );
    if (!r.success) errors.push(`Prettier errors:\n${r.output}`);
    else if (r.output) warnings.push(`Prettier: auto-formatted\n${r.output}`);
  }

  return { errors, warnings };
}

/** @param {string} dir */
function detectPackageManager(dir) {
  return LOCKFILES.find(([name]) => existsSync(join(dir, name)))?.[1] ?? "npm";
}

/**
 * @param {string} dir
 * @returns {Promise<TestSetup | null>}
 */
async function detectTestSetup(dir) {
  const pm = detectPackageManager(dir);
  const pkg = await readJson(join(dir, "package.json"));

  let framework;
  let bin;
  for (const candidate of /** @type {const} */ (["vitest", "jest", "mocha"])) {
    if (!pkg?.dependencies?.[candidate] && !pkg?.devDependencies?.[candidate]) {
      continue;
    }
    const found = binPath(dir, candidate);
    if (found) {
      framework = candidate;
      bin = found;
      break;
    }
  }

  // Prefer the package manager's `test` script when defined — it may layer on
  // setup the bare runner misses, such as a build step or env vars.
  const testScript = pkg?.scripts?.test;
  const hasTestScript =
    !!testScript && testScript !== 'echo "Error: no test specified" && exit 1';

  let fullSuiteCommand;
  if (hasTestScript) {
    fullSuiteCommand = pm === "bun" ? ["bun", "run", "test"] : [pm, "test"];
  } else if (bin) {
    // bin is only ever set alongside framework, so this covers both.
    fullSuiteCommand = framework === "vitest" ? [bin, "run"] : [bin];
  } else if (pm === "bun") {
    fullSuiteCommand = ["bun", "test"];
  } else {
    return null;
  }

  return {
    framework: framework ?? (pm === "bun" ? "bun" : undefined),
    binPath: bin,
    fullSuiteCommand,
  };
}

/**
 * @param {TestSetup} setup
 * @param {Categorized} c
 * @param {string} projectRoot
 */
function buildTestCommand(setup, c, projectRoot) {
  if (c.testConfigChanged || c.codeFiles.length === 0) {
    return setup.fullSuiteCommand;
  }
  const rel = c.codeFiles.map((f) => relative(projectRoot, f));

  if (setup.framework === "vitest" && setup.binPath) {
    // Nothing related to the edit is not a failure; without this vitest exits 1.
    return [setup.binPath, "related", ...rel, "--run", "--passWithNoTests"];
  }
  if (setup.framework === "jest" && setup.binPath) {
    return [setup.binPath, "--findRelatedTests", "--passWithNoTests", ...rel];
  }
  // bun test has no related mode; it takes paths, so narrowing is only safe
  // when every edit was itself a test file.
  if (
    setup.framework === "bun" &&
    c.testFiles.length > 0 &&
    c.testFiles.length === c.codeFiles.length
  ) {
    return ["bun", "test", ...rel];
  }
  return setup.fullSuiteCommand;
}

/**
 * @param {string} reason
 * @returns {never}
 */
function block(reason) {
  console.log(JSON.stringify({ decision: "block", reason }));
  process.exit(0);
}

// The harness always pipes the payload in. A TTY means someone ran this by hand,
// and reading stdin there would hang rather than fail.
const readStdin = () => (process.stdin.isTTY ? "" : text(process.stdin));

async function main() {
  const lintEnabled = process.env.LINT_ON_SAVE !== "false";
  const testsEnabled = process.env.RUN_TESTS_ON_STOP !== "false";
  if (!lintEnabled && !testsEnabled) process.exit(0);

  /** @type {StopHookInput} */
  let input = {};
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

  // Which source, not which result: an empty transcript means the agent edited
  // nothing, and falling back there would lint and test whatever happens to be
  // dirty after a turn that only read code. Git stands in when there is no
  // transcript this hook can read — none sent, or one in another agent's format.
  const edited = input.transcript_path
    ? await getEditedFiles(input.transcript_path, projectRoot)
    : null;

  const c = categorize(
    worthChecking(edited ?? gitChangedFiles(projectRoot)),
    projectRoot,
  );

  // A broken manifest makes tool and script detection unreliable. Treat it as
  // an actionable project error instead of collapsing it into "no test setup".
  const packagePath = join(projectRoot, "package.json");
  if (existsSync(packagePath) && !(await readJson(packagePath))) {
    block("package.json must contain valid JSON before stopping.");
  }

  // Nothing functional changed and nothing formattable was touched → skip.
  if (!lintFull && !testsFull && !c.hasCode && c.prettierFiles.length === 0) {
    process.exit(0);
  }

  const { errors, warnings } = lintEnabled
    ? await lint(projectRoot, c, lintFull)
    : { errors: [], warnings: [] };

  if (errors.length > 0) {
    block(
      `Lint/type errors found. Please fix before stopping.\n\n${errors.join(
        "\n\n",
      )}`,
    );
  }

  if (testsEnabled && (testsFull || c.hasCode)) {
    const setup = await detectTestSetup(projectRoot);
    if (setup) {
      const command = testsFull
        ? setup.fullSuiteCommand
        : buildTestCommand(setup, c, projectRoot);
      const r = runCommand(command, projectRoot, budget(120_000));
      if (!r.success) {
        block(
          `Tests failed. Please fix the failing tests before stopping.\n\n$ ${command.join(
            " ",
          )}\n\n${r.output}`,
        );
      }
    }
  }

  // systemMessage, not bare text: plain stdout from a hook that exits 0 only
  // shows in transcript mode, so a warning printed that way is one nobody reads.
  if (warnings.length > 0) {
    console.log(JSON.stringify({ systemMessage: warnings.join("\n\n") }));
  }
  process.exit(0);
}

// A hook that throws is still a hook that ran: fail open rather than surface a
// stack trace and a non-zero exit for something the session cannot act on.
main().catch((e) => {
  console.error(`stop hook: ${e}`);
  process.exit(0);
});
