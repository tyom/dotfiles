#!/usr/bin/env bun
/**
 * PostToolUse Hook: Lint, Type Check, and Format
 *
 * Runs after Edit|MultiEdit|Write operations on supported files.
 * Performs type checking, linting, and Prettier formatting.
 * Supports: tsc + eslint + prettier
 *
 * Environment:
 *   stdin: JSON with tool_input containing file_path
 *
 * Exit codes:
 *   0 - Success (or no action needed)
 *   2 - Blocking error (stderr shown to Claude)
 */

import { dirname, resolve, extname } from "path";
import { spawnSync } from "child_process";

interface ToolInput {
  tool_input?: {
    file_path?: string;
  };
}

const TS_JS_EXTENSIONS: Set<string> = new Set([
  ".ts",
  ".tsx",
  ".js",
  ".jsx",
  ".mjs",
  ".mts",
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

/**
 * Reads all data from standard input and returns it as a UTF-8 string.
 *
 * @returns The concatenated stdin contents decoded as UTF-8.
 */
async function readStdin(): Promise<string> {
  const chunks: Buffer[] = [];
  for await (const chunk of Bun.stdin.stream()) {
    chunks.push(chunk as Buffer);
  }
  return Buffer.concat(chunks).toString("utf-8");
}

/**
 * Locate the root of the project or monorepo containing `startPath`.
 *
 * Walks up from `startPath` looking for the workspace/monorepo root rather than
 * the nearest `package.json`, which in a monorepo would be a sub-package that
 * typically lacks top-level configs (prettier, eslint, tsconfig).
 *
 * A directory is considered the project root if it contains `package.json` AND any of:
 * - A `workspaces` field in package.json
 * - A lockfile (bun.lock, bun.lockb, package-lock.json, yarn.lock, pnpm-lock.yaml)
 * - A `.git` directory
 *
 * Falls back to the nearest `package.json` if no root indicators are found.
 *
 * @param startPath - File or directory path to start the upward search from
 * @returns The directory path of the project root, or `null` if no `package.json` is found
 */
async function findProjectRoot(startPath: string): Promise<string | null> {
  let currentDir = dirname(startPath);
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

      // Check for monorepo/root indicators
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

/**
 * Executes a subprocess and returns its success status, combined output, and exit code.
 *
 * @param cmd - The executable or command to run.
 * @param args - Arguments to pass to the command.
 * @param cwd - Working directory in which to run the command.
 * @returns An object with:
 *  - `success`: `true` if the process exited with status `0` and had no signal or spawn error, `false` otherwise.
 *  - `output`: Combined stdout and stderr, with any spawn error or termination signal appended.
 *  - `status`: The numeric exit code of the process, or `null` if unavailable.
 */
function runCommand(
  cmd: string,
  args: string[],
  cwd: string,
): { success: boolean; output: string; status: number | null } {
  const result = spawnSync(cmd, args, {
    cwd,
    encoding: "utf-8",
    timeout: 30000,
    env: { ...process.env, FORCE_COLOR: "0" },
  });

  const outputParts = [result.stdout, result.stderr].filter(Boolean);

  if (result.signal) {
    outputParts.push(`Killed by ${result.signal}`);
  }

  if (result.error) {
    outputParts.push(result.error.message);
  }

  const output = outputParts.join("\n").trim();
  const success = result.status === 0 && !result.signal && !result.error;

  return { success, output, status: result.status };
}

/**
 * Orchestrates type checking, formatting, and linting for a file specified via stdin.
 *
 * Reads a JSON object from stdin to obtain `tool_input.file_path`. If the file extension
 * is supported and a project root (containing package.json) is found, performs:
 * - TypeScript type checking when applicable and tsconfig/tsc are present.
 * - Prettier formatting when a Prettier config and prettier binary are present (auto-formats files if needed).
 * - ESLint linting for JS/TS files when an ESLint config and eslint binary are present.
 *
 * Aggregates tool outputs as errors or warnings. Prints errors to stderr and exits with code 2;
 * prints warnings to stdout and exits with code 0 on success or when no action was necessary.
 *
 * Can be disabled by setting LINT_ON_SAVE=false environment variable.
 *
 * @remarks
 * Exit codes:
 * - 0: success or no applicable action
 * - 2: blocking errors detected (TypeScript, Prettier, or ESLint)
 */
async function main() {
  // Check if linting is disabled via environment variable (default: enabled)
  if (process.env.LINT_ON_SAVE === "false") {
    process.exit(0);
  }

  let input: ToolInput;

  try {
    const stdin = await readStdin();
    input = JSON.parse(stdin);
  } catch {
    process.exit(0);
  }

  const filePath = input?.tool_input?.file_path;
  if (!filePath) {
    process.exit(0);
  }

  const ext = extname(filePath);
  if (!PRETTIER_EXTENSIONS.has(ext)) {
    process.exit(0);
  }

  const projectRoot = await findProjectRoot(filePath);
  if (!projectRoot) {
    process.exit(0);
  }

  const errors: string[] = [];
  const warnings: string[] = [];

  const isTypeScriptFile = TS_JS_EXTENSIONS.has(ext);

  // Run TypeScript type checking if tsconfig exists (TS/JS files only)
  if (isTypeScriptFile && (ext === ".ts" || ext === ".tsx" || ext === ".mts")) {
    const hasTsConfig = await Bun.file(
      resolve(projectRoot, "tsconfig.json"),
    ).exists();

    if (hasTsConfig) {
      const tscPath = resolve(projectRoot, "node_modules", ".bin", "tsc");
      const hasTsc = await Bun.file(tscPath).exists();

      if (hasTsc) {
        const tscResult = runCommand(
          tscPath,
          ["--noEmit", "--skipLibCheck"],
          projectRoot,
        );
        if (!tscResult.success && tscResult.output) {
          errors.push(`TypeScript errors:\n${tscResult.output}`);
        }
      }
    }
  }

  // Run Prettier if config exists
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

  let hasPrettierConfig = false;
  for (const config of prettierConfigs) {
    if (await Bun.file(resolve(projectRoot, config)).exists()) {
      hasPrettierConfig = true;
      break;
    }
  }

  // Also check package.json for prettier key
  if (!hasPrettierConfig) {
    try {
      const pkgJson = await Bun.file(
        resolve(projectRoot, "package.json"),
      ).json();
      if (pkgJson.prettier) {
        hasPrettierConfig = true;
      }
    } catch {}
  }

  if (hasPrettierConfig) {
    const prettierPath = resolve(
      projectRoot,
      "node_modules",
      ".bin",
      "prettier",
    );
    const hasPrettierBin = await Bun.file(prettierPath).exists();

    if (hasPrettierBin) {
      // Check if file needs formatting
      const checkResult = runCommand(
        prettierPath,
        ["--check", filePath],
        projectRoot,
      );

      if (!checkResult.success) {
        // Auto-format the file
        const formatResult = runCommand(
          prettierPath,
          ["--write", filePath],
          projectRoot,
        );

        if (formatResult.success) {
          warnings.push(`Prettier: Auto-formatted ${filePath}`);
        } else {
          errors.push(`Prettier errors:\n${formatResult.output}`);
        }
      }
    }
  }

  // Run ESLint if config exists (TS/JS files only)
  if (isTypeScriptFile) {
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

    let hasEslintConfig = false;
    for (const config of eslintConfigs) {
      if (await Bun.file(resolve(projectRoot, config)).exists()) {
        hasEslintConfig = true;
        break;
      }
    }

    if (hasEslintConfig) {
      const eslintPath = resolve(projectRoot, "node_modules", ".bin", "eslint");
      const hasEslintBin = await Bun.file(eslintPath).exists();

      if (hasEslintBin) {
        // ESLint exit codes: 0 = success, 1 = lint errors, 2 = fatal error
        const eslintResult = runCommand(
          eslintPath,
          ["--format", "stylish", filePath],
          projectRoot,
        );
        if (eslintResult.output) {
          if (eslintResult.status === 1) {
            errors.push(`ESLint errors:\n${eslintResult.output}`);
          } else if (eslintResult.status === 2) {
            errors.push(`ESLint fatal error:\n${eslintResult.output}`);
          } else if (eslintResult.status === 0) {
            // Exit 0 with output means warnings only
            warnings.push(`ESLint warnings:\n${eslintResult.output}`);
          }
        }
      }
    }
  }

  if (errors.length > 0) {
    console.error(errors.join("\n\n"));
    process.exit(2);
  }

  if (warnings.length > 0) {
    console.log(warnings.join("\n\n"));
  }

  process.exit(0);
}

main();
