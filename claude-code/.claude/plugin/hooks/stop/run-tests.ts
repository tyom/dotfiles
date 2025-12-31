#!/usr/bin/env bun
/**
 * Stop Hook: Run Tests
 *
 * Runs tests before Claude stops if tests are present in the project.
 * Blocks stopping if tests fail.
 *
 * Environment:
 *   stdin: JSON with stop_hook_active, transcript_path, etc.
 *
 * Output (JSON):
 *   { "decision": "block", "reason": "..." } - Prevent stopping
 *   {} or nothing - Allow stopping
 */

import { resolve, join } from "path";
import { spawnSync } from "child_process";
import { existsSync, readdirSync, statSync } from "fs";

interface StopHookInput {
  stop_hook_active?: boolean;
  transcript_path?: string;
}

interface TestConfig {
  runner: string;
  command: string[];
  cwd: string;
}

const CWD = process.cwd();

/**
 * Read all data from standard input and return it as a UTF-8 string.
 *
 * @returns The concatenated UTF-8 string read from stdin (empty string if no data).
 */
async function readStdin(): Promise<string> {
  const chunks: Buffer[] = [];
  for await (const chunk of Bun.stdin.stream()) {
    chunks.push(chunk as Buffer);
  }
  return Buffer.concat(chunks).toString("utf-8");
}

/**
 * Detects whether a directory contains project test files or test directories.
 *
 * Checks the given directory and its `src` subdirectory for common test directories
 * (e.g., `test`, `tests`, `__tests__`, `spec`, `specs`) and common test file name
 * patterns (for example `.test.js`, `.spec.tsx`, `_test.ts`).
 *
 * @param dir - Path of the directory to inspect
 * @returns `true` if the directory or its `src` subdirectory contains test files or test directories, `false` otherwise
 */
function hasTestFiles(dir: string): boolean {
  const testPatterns = [
    /\.test\.[jt]sx?$/,
    /\.spec\.[jt]sx?$/,
    /_test\.[jt]sx?$/,
    /_spec\.[jt]sx?$/,
  ];

  const testDirs = ["test", "tests", "__tests__", "spec", "specs"];

  // Check for test directories
  for (const testDir of testDirs) {
    const testPath = join(dir, testDir);
    if (existsSync(testPath) && statSync(testPath).isDirectory()) {
      return true;
    }
  }

  // Check for test files in src or root
  const srcDir = join(dir, "src");
  const dirsToCheck = [dir, srcDir].filter(
    (d) => existsSync(d) && statSync(d).isDirectory(),
  );

  for (const checkDir of dirsToCheck) {
    try {
      const files = readdirSync(checkDir, { recursive: true }) as string[];
      for (const file of files) {
        if (testPatterns.some((pattern) => pattern.test(file))) {
          return true;
        }
      }
    } catch {
      continue;
    }
  }

  return false;
}

/**
 * Detects an appropriate test runner and the command to run tests for the project located at `dir`.
 *
 * @param dir - Path to the project directory to analyze
 * @returns A `TestConfig` containing the selected `runner`, the `command` to invoke tests, and the `cwd`, or `null` if no suitable runner or test configuration is detected
 */
async function detectTestRunner(dir: string): Promise<TestConfig | null> {
  const packageJsonPath = join(dir, "package.json");
  const packageJsonFile = Bun.file(packageJsonPath);

  if (!(await packageJsonFile.exists())) {
    return null;
  }

  let packageJson: Record<string, unknown>;
  try {
    packageJson = await packageJsonFile.json();
  } catch {
    return null;
  }

  const scripts = packageJson.scripts as Record<string, string> | undefined;
  const devDeps = packageJson.devDependencies as
    | Record<string, string>
    | undefined;
  const deps = packageJson.dependencies as Record<string, string> | undefined;

  // Check for test script in package.json
  if (
    scripts?.test &&
    scripts.test !== 'echo "Error: no test specified" && exit 1'
  ) {
    // Detect the package manager
    if (
      (await Bun.file(join(dir, "bun.lockb")).exists()) ||
      (await Bun.file(join(dir, "bun.lock")).exists())
    ) {
      return { runner: "bun", command: ["bun", "run", "test"], cwd: dir };
    }
    if (await Bun.file(join(dir, "pnpm-lock.yaml")).exists()) {
      return { runner: "pnpm", command: ["pnpm", "test"], cwd: dir };
    }
    if (await Bun.file(join(dir, "yarn.lock")).exists()) {
      return { runner: "yarn", command: ["yarn", "test"], cwd: dir };
    }
    return { runner: "npm", command: ["npm", "test"], cwd: dir };
  }

  // Check for specific test frameworks
  const allDeps = { ...deps, ...devDeps };

  if (allDeps?.vitest) {
    const vitestPath = resolve(dir, "node_modules", ".bin", "vitest");
    if (await Bun.file(vitestPath).exists()) {
      return { runner: "vitest", command: [vitestPath, "run"], cwd: dir };
    }
  }

  if (allDeps?.jest) {
    const jestPath = resolve(dir, "node_modules", ".bin", "jest");
    if (await Bun.file(jestPath).exists()) {
      return { runner: "jest", command: [jestPath], cwd: dir };
    }
  }

  if (allDeps?.mocha) {
    const mochaPath = resolve(dir, "node_modules", ".bin", "mocha");
    if (await Bun.file(mochaPath).exists()) {
      return { runner: "mocha", command: [mochaPath], cwd: dir };
    }
  }

  // Bun has built-in test runner
  if (
    (await Bun.file(join(dir, "bun.lockb")).exists()) ||
    (await Bun.file(join(dir, "bun.lock")).exists())
  ) {
    if (hasTestFiles(dir)) {
      return { runner: "bun", command: ["bun", "test"], cwd: dir };
    }
  }

  return null;
}

/**
 * Execute the configured test command and collect its combined output.
 *
 * @param config - Test runner configuration containing `command` (array where the first element is the executable and the rest are arguments) and `cwd` (working directory to run the command in)
 * @returns An object with `success` set to `true` if the process exited with status 0, `false` otherwise, and `output` containing the trimmed concatenation of the process's stdout and stderr
 */
function runTests(config: TestConfig): { success: boolean; output: string } {
  const result = spawnSync(config.command[0], config.command.slice(1), {
    cwd: config.cwd,
    encoding: "utf-8",
    timeout: 120000,
    env: { ...process.env, FORCE_COLOR: "0", CI: "true" },
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

/**
 * Finds the nearest ancestor directory that contains a package.json file.
 *
 * @returns Path to the nearest ancestor directory containing a `package.json`; if none is found, returns the original `CWD`.
 */
async function findProjectRoot(): Promise<string> {
  let current = CWD;
  while (current !== resolve(current, "..")) {
    if (await Bun.file(join(current, "package.json")).exists()) {
      return current;
    }
    current = resolve(current, "..");
  }
  return CWD;
}

/**
 * Run project tests and block shutdown when tests fail.
 *
 * Reads optional JSON from stdin to detect an active stop hook; if a stop hook is already active, the function allows shutdown to continue.
 * Locates the project root, detects an appropriate test runner and configuration, and verifies test files exist; if no runner or tests are found, it allows shutdown.
 * Executes the detected test suite and, if any test fails, emits a JSON decision object to stdout with `decision: "block"` and a `reason` that includes the test output to prevent stopping.
 */
async function main() {
  let input: StopHookInput = {};

  try {
    const stdin = await readStdin();
    if (stdin.trim()) {
      input = JSON.parse(stdin);
    }
  } catch {
    // Continue with empty input
  }

  // Prevent infinite loops - if we're already continuing from a stop hook, allow stopping
  if (input.stop_hook_active) {
    process.exit(0);
  }

  const projectRoot = await findProjectRoot();
  const testConfig = await detectTestRunner(projectRoot);

  if (!testConfig) {
    process.exit(0);
  }

  if (!hasTestFiles(projectRoot)) {
    process.exit(0);
  }

  const result = runTests(testConfig);

  if (!result.success) {
    const output = {
      decision: "block",
      reason: `Tests failed. Please fix the failing tests before stopping.\n\n${result.output}`,
    };
    console.log(JSON.stringify(output));
    process.exit(0);
  }

  process.exit(0);
}

main();