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
  ".md",
  ".mdx",
  ".json",
  ".yaml",
  ".yml",
  ".css",
  ".scss",
  ".html",
]);

async function readStdin(): Promise<string> {
  const chunks: Buffer[] = [];
  for await (const chunk of Bun.stdin.stream()) {
    chunks.push(chunk as Buffer);
  }
  return Buffer.concat(chunks).toString("utf-8");
}

async function findProjectRoot(startPath: string): Promise<string | null> {
  let currentDir = dirname(startPath);
  while (currentDir !== "/") {
    if (await Bun.file(resolve(currentDir, "package.json")).exists()) {
      return currentDir;
    }
    currentDir = dirname(currentDir);
  }
  return null;
}

function runCommand(
  cmd: string,
  args: string[],
  cwd: string,
): { success: boolean; output: string } {
  const result = spawnSync(cmd, args, {
    cwd,
    encoding: "utf-8",
    timeout: 30000,
    env: { ...process.env, FORCE_COLOR: "0" },
  });

  const output = [result.stdout, result.stderr]
    .filter(Boolean)
    .join("\n")
    .trim();
  return {
    success: result.status === 0,
    output,
  };
}

async function main() {
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
        const eslintResult = runCommand(
          eslintPath,
          ["--format", "stylish", "--max-warnings", "0", filePath],
          projectRoot,
        );
        if (!eslintResult.success && eslintResult.output) {
          if (eslintResult.output.includes("error")) {
            errors.push(`ESLint errors:\n${eslintResult.output}`);
          } else {
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
