#!/usr/bin/env bun
/**
 * Stop Hook: Lint, Type Check, and Format
 *
 * Runs before Claude stops, scoped to files Claude edited this session.
 *
 *   - tsc:      project-wide (only sane mode for graph type checking),
 *               skipped unless TS/JS or tsconfig was edited.
 *   - eslint:   on edited JS/TS files; falls back to full project when
 *               eslint config or package.json was edited.
 *   - prettier: on edited prettier-able files only.
 *
 * If no functional file was edited (only docs/lockfiles/etc.), all tools
 * are skipped.
 *
 * Env:
 *   LINT_ON_SAVE=false → disable entirely
 *   LINT_FULL=true     → force project-wide for all tools
 */

import { dirname, resolve, extname, relative, basename } from "path";
import { spawnSync } from "child_process";

interface StopHookInput {
  stop_hook_active?: boolean;
  transcript_path?: string;
}

const TS_JS_EXTENSIONS: Set<string> = new Set([
  ".ts",
  ".tsx",
  ".js",
  ".jsx",
  ".mjs",
  ".mts",
  ".cjs",
  ".cts",
]);

const PRETTIER_EXTENSIONS: Set<string> = new Set([
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

const TSCONFIG_PATTERN = /(?:^|\/)tsconfig[^/]*\.json$/;
const ESLINT_CONFIG_PATTERN =
  /(?:^|\/)(?:eslint\.config\.[cm]?[jt]sx?|\.eslintrc(?:\.[a-z]+)?)$/;
const PRETTIER_CONFIG_PATTERN =
  /(?:^|\/)(?:prettier\.config\.[cm]?[jt]sx?|\.prettierrc(?:\.[a-z]+)?)$/;

async function readStdin(): Promise<string> {
  const chunks: Buffer[] = [];
  for await (const chunk of Bun.stdin.stream()) {
    chunks.push(chunk as Buffer);
  }
  return Buffer.concat(chunks).toString("utf-8");
}

async function findProjectRoot(startPath: string): Promise<string | null> {
  let currentDir = startPath;
  let nearestPkgDir: string | null = null;

  const lockfiles = [
    "bun.lock",
    "bun.lockb",
    "package-lock.json",
    "yarn.lock",
    "pnpm-lock.yaml",
  ];

  while (currentDir !== dirname(currentDir)) {
    const pkgPath = resolve(currentDir, "package.json");
    if (await Bun.file(pkgPath).exists()) {
      if (!nearestPkgDir) {
        nearestPkgDir = currentDir;
      }

      try {
        const pkgJson = await Bun.file(pkgPath).json();
        if (pkgJson.workspaces) {
          return currentDir;
        }
      } catch {}

      for (const lockfile of lockfiles) {
        if (await Bun.file(resolve(currentDir, lockfile)).exists()) {
          return currentDir;
        }
      }

      try {
        const { statSync } = await import("fs");
        statSync(resolve(currentDir, ".git"));
        return currentDir;
      } catch {}
    }
    currentDir = dirname(currentDir);
  }

  return nearestPkgDir;
}

async function getEditedFiles(
  transcriptPath: string | undefined,
  projectRoot: string,
): Promise<string[]> {
  if (!transcriptPath) return [];
  const file = Bun.file(transcriptPath);
  if (!(await file.exists())) return [];

  const text = await file.text();
  const editTools = new Set(["Edit", "Write", "MultiEdit", "NotebookEdit"]);
  const seen = new Set<string>();
  const result: string[] = [];

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
      if (
        (abs.startsWith(projectRoot + "/") || abs === projectRoot) &&
        !seen.has(abs)
      ) {
        seen.add(abs);
        result.push(abs);
      }
    }
  }
  return result;
}

interface Categorized {
  tsJsFiles: string[];
  prettierFiles: string[];
  tsConfigChanged: boolean;
  eslintConfigChanged: boolean;
  prettierConfigChanged: boolean;
  packageJsonChanged: boolean;
  hasNonSkip: boolean;
}

function categorize(files: string[], projectRoot: string): Categorized {
  const tsJsFiles: string[] = [];
  const prettierFiles: string[] = [];
  let tsConfigChanged = false;
  let eslintConfigChanged = false;
  let prettierConfigChanged = false;
  let packageJsonChanged = false;
  let hasNonSkip = false;

  for (const abs of files) {
    const ext = extname(abs);
    const base = basename(abs);
    const rel = relative(projectRoot, abs);

    if (
      ext === ".md" ||
      ext === ".mdx" ||
      ext === ".txt" ||
      ext === ".rst" ||
      base === "LICENSE" ||
      base === "LICENCE" ||
      base === "bun.lockb" ||
      base === "bun.lock" ||
      base === "package-lock.json" ||
      base === "yarn.lock" ||
      base === "pnpm-lock.yaml"
    ) {
      // Markdown is still prettier-formattable; let it be picked up below.
      if (PRETTIER_EXTENSIONS.has(ext)) {
        prettierFiles.push(abs);
        hasNonSkip = true;
      }
      continue;
    }

    hasNonSkip = true;

    if (base === "package.json") packageJsonChanged = true;
    if (TSCONFIG_PATTERN.test(rel)) tsConfigChanged = true;
    if (ESLINT_CONFIG_PATTERN.test(rel)) eslintConfigChanged = true;
    if (PRETTIER_CONFIG_PATTERN.test(rel)) prettierConfigChanged = true;

    if (TS_JS_EXTENSIONS.has(ext)) tsJsFiles.push(abs);
    if (PRETTIER_EXTENSIONS.has(ext)) prettierFiles.push(abs);
  }

  return {
    tsJsFiles,
    prettierFiles,
    tsConfigChanged,
    eslintConfigChanged,
    prettierConfigChanged,
    packageJsonChanged,
    hasNonSkip,
  };
}

function runCommand(
  cmd: string,
  args: string[],
  cwd: string,
  timeoutMs = 30000,
): { success: boolean; output: string; status: number | null } {
  const result = spawnSync(cmd, args, {
    cwd,
    encoding: "utf-8",
    timeout: timeoutMs,
    env: { ...process.env, FORCE_COLOR: "0" },
  });

  const outputParts = [result.stdout, result.stderr].filter(Boolean);
  if (result.signal) outputParts.push(`Killed by ${result.signal}`);
  if (result.error) outputParts.push(result.error.message);

  const output = outputParts.join("\n").trim();
  const success = result.status === 0 && !result.signal && !result.error;
  return { success, output, status: result.status };
}

async function fileExists(path: string): Promise<boolean> {
  return Bun.file(path).exists();
}

async function findExistingConfig(
  projectRoot: string,
  candidates: string[],
): Promise<boolean> {
  for (const c of candidates) {
    if (await fileExists(resolve(projectRoot, c))) return true;
  }
  return false;
}

async function main() {
  if (process.env.LINT_ON_SAVE === "false") process.exit(0);

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

  const forceFull = process.env.LINT_FULL === "true";

  const editedFiles = await getEditedFiles(input.transcript_path, projectRoot);
  const cat = categorize(editedFiles, projectRoot);

  // Nothing functional changed and nothing prettier-able touched → skip.
  if (!forceFull && !cat.hasNonSkip) process.exit(0);

  const errors: string[] = [];
  const warnings: string[] = [];

  // ── TypeScript (project-wide; only mode that makes sense for graph checks) ──
  const shouldRunTsc =
    forceFull ||
    cat.tsJsFiles.length > 0 ||
    cat.tsConfigChanged ||
    cat.packageJsonChanged;

  if (shouldRunTsc) {
    const hasTsConfig = await fileExists(resolve(projectRoot, "tsconfig.json"));
    if (hasTsConfig) {
      const tscPath = resolve(projectRoot, "node_modules", ".bin", "tsc");
      if (await fileExists(tscPath)) {
        const r = runCommand(
          tscPath,
          ["--noEmit", "--skipLibCheck"],
          projectRoot,
        );
        if (!r.success && r.output) {
          errors.push(`TypeScript errors:\n${r.output}`);
        }
      }
    }
  }

  // ── ESLint (scoped to edited JS/TS unless config or package.json changed) ──
  const eslintConfigs = [
    "eslint.config.js",
    "eslint.config.mjs",
    "eslint.config.cjs",
    ".eslintrc.js",
    ".eslintrc.cjs",
    ".eslintrc.json",
    ".eslintrc.yml",
    ".eslintrc.yaml",
    ".eslintrc",
  ];
  const hasEslintConfig = await findExistingConfig(projectRoot, eslintConfigs);

  if (hasEslintConfig) {
    const eslintPath = resolve(projectRoot, "node_modules", ".bin", "eslint");
    if (await fileExists(eslintPath)) {
      const fullEslint =
        forceFull || cat.eslintConfigChanged || cat.packageJsonChanged;

      const targets = fullEslint
        ? ["."]
        : cat.tsJsFiles.map((f) => relative(projectRoot, f));

      if (targets.length > 0) {
        const r = runCommand(
          eslintPath,
          ["--format", "stylish", "--no-error-on-unmatched-pattern", ...targets],
          projectRoot,
        );
        if (r.output) {
          if (r.status === 1) errors.push(`ESLint errors:\n${r.output}`);
          else if (r.status === 2) errors.push(`ESLint fatal:\n${r.output}`);
          else if (r.status === 0) warnings.push(`ESLint warnings:\n${r.output}`);
        }
      }
    }
  }

  // ── Prettier (always scoped to edited files; never mass-format) ──
  const prettierConfigs = [
    "prettier.config.js",
    "prettier.config.mjs",
    "prettier.config.cjs",
    ".prettierrc",
    ".prettierrc.json",
    ".prettierrc.yml",
    ".prettierrc.yaml",
    ".prettierrc.js",
    ".prettierrc.cjs",
    ".prettierrc.mjs",
    ".prettierrc.toml",
  ];
  let hasPrettierConfig = await findExistingConfig(projectRoot, prettierConfigs);
  if (!hasPrettierConfig) {
    try {
      const pkgJson = await Bun.file(
        resolve(projectRoot, "package.json"),
      ).json();
      if (pkgJson.prettier) hasPrettierConfig = true;
    } catch {}
  }

  if (hasPrettierConfig && cat.prettierFiles.length > 0) {
    const prettierPath = resolve(
      projectRoot,
      "node_modules",
      ".bin",
      "prettier",
    );
    if (await fileExists(prettierPath)) {
      for (const file of cat.prettierFiles) {
        const check = runCommand(prettierPath, ["--check", file], projectRoot);
        if (!check.success) {
          const fmt = runCommand(prettierPath, ["--write", file], projectRoot);
          if (fmt.success) {
            warnings.push(`Prettier: Auto-formatted ${relative(projectRoot, file)}`);
          } else {
            errors.push(`Prettier errors:\n${fmt.output}`);
          }
        }
      }
    }
  }

  if (errors.length > 0) {
    const decision = {
      decision: "block",
      reason: `Lint/type errors found. Please fix before stopping.\n\n${errors.join("\n\n")}`,
    };
    console.log(JSON.stringify(decision));
    process.exit(0);
  }

  if (warnings.length > 0) {
    console.log(warnings.join("\n\n"));
  }

  process.exit(0);
}

main();
