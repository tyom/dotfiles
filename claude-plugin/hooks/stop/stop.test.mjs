// Drives the hook the way Claude Code does — transcript on stdin, decision on
// stdout — against a throwaway project, so nothing here touches a real one.
//
// Tool-specific fixtures below install small executables so TypeScript, ESLint
// and Prettier are exercised without downloading packages.

import test from "node:test";
import assert from "node:assert/strict";
import {
  mkdtempSync,
  readFileSync,
  writeFileSync,
  mkdirSync,
  realpathSync,
  chmodSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { spawnSync } from "node:child_process";

const HOOK = join(import.meta.dirname, "stop.mjs");

// realpath: on macOS $TMPDIR is a symlink, and the hook compares edited paths
// against the resolved cwd it is launched in.
/** @param {Record<string, unknown>} pkg */
function tmpProject(pkg) {
  const dir = realpathSync(mkdtempSync(join(tmpdir(), "stop-hook-")));
  writeFileSync(join(dir, "package.json"), JSON.stringify(pkg));
  // npm, not bun: the fixture's test script has to actually run, and bun is not
  // on every machine that runs these tests.
  writeFileSync(join(dir, "package-lock.json"), "");
  return dir;
}

// A project whose test script always fails, so a run that happens is visible.
function fixture() {
  return tmpProject({ name: "fixture", scripts: { test: "exit 1" } });
}

// A vitest project whose runner fails and reports its own argv, so the command
// the hook chose shows up in the block reason.
function vitestFixture() {
  const dir = tmpProject({ name: "fixture", devDependencies: { vitest: "*" } });
  const bin = join(dir, "node_modules", ".bin", "vitest");
  mkdirSync(dirname(bin), { recursive: true });
  writeFileSync(bin, '#!/bin/sh\necho "argv: $*"\nexit 1\n');
  chmodSync(bin, 0o755);
  return dir;
}

// A TypeScript project whose compiler reports one stable diagnostic.
function typescriptFixture() {
  const dir = tmpProject({
    name: "fixture",
    devDependencies: { typescript: "*" },
  });
  const bin = join(dir, "node_modules", ".bin", "tsc");
  mkdirSync(dirname(bin), { recursive: true });
  writeFileSync(bin, '#!/bin/sh\necho "TS2322: fixture type error"\nexit 1\n');
  writeFileSync(join(dir, "tsconfig.json"), "{}\n");
  chmodSync(bin, 0o755);
  return dir;
}

// An eslint project whose local binary exists but cannot be launched.
function brokenEslintFixture() {
  const dir = tmpProject({ name: "fixture", devDependencies: { eslint: "*" } });
  const bin = join(dir, "node_modules", ".bin", "eslint");
  mkdirSync(dirname(bin), { recursive: true });
  writeFileSync(bin, "#!/bin/sh\nexit 0\n");
  writeFileSync(join(dir, "eslint.config.js"), "export default []\n");
  chmodSync(bin, 0o644);
  return dir;
}

// An ESLint project whose executable reports its public arguments and fails.
function eslintFixture() {
  const dir = tmpProject({ name: "fixture", devDependencies: { eslint: "*" } });
  const bin = join(dir, "node_modules", ".bin", "eslint");
  mkdirSync(dirname(bin), { recursive: true });
  writeFileSync(bin, '#!/bin/sh\necho "eslint argv: $*"\nexit 1\n');
  writeFileSync(join(dir, "eslint.config.js"), "export default []\n");
  chmodSync(bin, 0o755);
  return dir;
}

// A Prettier project whose executable rewrites its final path argument.
function prettierFixture() {
  const dir = tmpProject({
    name: "fixture",
    devDependencies: { prettier: "*" },
  });
  const bin = join(dir, "node_modules", ".bin", "prettier");
  mkdirSync(dirname(bin), { recursive: true });
  writeFileSync(
    bin,
    '#!/bin/sh\nfor target do :; done\nprintf "formatted\\n" >"$target"\nprintf "%s\\n" "$target"\n',
  );
  writeFileSync(join(dir, ".prettierrc"), "{}\n");
  chmodSync(bin, 0o755);
  return dir;
}

// A vitest project that is also a git repo with one commit, so the working tree
// is clean until a test dirties it.
function gitFixture() {
  const dir = vitestFixture();
  const git = (/** @type {string[]} */ args) =>
    spawnSync("git", ["-C", dir, ...args], { encoding: "utf-8" });
  git(["init", "-q"]);
  git(["add", "-A"]);
  git([
    "-c",
    "user.email=t@t",
    "-c",
    "user.name=t",
    "commit",
    "-qm",
    "init",
    "--no-gpg-sign",
  ]);
  return dir;
}

// One transcript line per edited file, in the shape the hook parses, after an
// assistant message: every session has one of those whether it edited anything
// or not, and it is what marks the file as a transcript this hook can read.
/**
 * @param {string} dir
 * @param {string[]} files
 */
function transcript(dir, files) {
  const path = join(dir, "transcript.jsonl");
  writeFileSync(
    path,
    [
      JSON.stringify({
        message: { content: [{ type: "text", text: "done" }] },
      }),
      ...files.map((f) =>
        JSON.stringify({
          message: {
            content: [
              {
                type: "tool_use",
                name: "Edit",
                input: { file_path: join(dir, f) },
              },
            ],
          },
        }),
      ),
    ].join("\n"),
  );
  return path;
}

// process.execPath, so the hook is exercised under whichever runtime is running
// the tests rather than a second one that happens to be installed.
/**
 * @param {string} dir
 * @param {string[]} files
 */
function runHook(
  dir,
  files,
  { withTranscript = true, writeFiles = true } = {},
) {
  if (writeFiles) {
    for (const f of files) {
      mkdirSync(dirname(join(dir, f)), { recursive: true });
      writeFileSync(join(dir, f), "");
    }
  }
  const proc = spawnSync(process.execPath, [HOOK], {
    cwd: dir,
    encoding: "utf-8",
    // No transcript_path at all is one of the two ways the hook ends up on the
    // git fallback; the other is a transcript it cannot parse.
    input: JSON.stringify(
      withTranscript ? { transcript_path: transcript(dir, files) } : {},
    ),
  });
  // The tests that assert silence would otherwise pass on a crashed hook.
  if (proc.status !== 0) {
    throw new Error(`hook exited ${proc.status}\n${proc.stderr}`);
  }
  return proc.stdout.trim();
}

test("a failing suite blocks when source was edited", () => {
  const out = runHook(fixture(), ["src/thing.ts"]);
  assert.equal(JSON.parse(out).decision, "block");
});

test("a TypeScript failure blocks", () => {
  const reason = JSON.parse(
    runHook(typescriptFixture(), ["src/thing.ts"]),
  ).reason;
  assert.match(reason, /TypeScript errors.*TS2322: fixture type error/is);
});

test("a malformed package.json blocks", () => {
  const dir = tmpProject({ name: "fixture" });
  writeFileSync(join(dir, "package.json"), "{broken");
  const out = runHook(dir, ["package.json"], { writeFiles: false });
  assert.match(JSON.parse(out).reason, /package\.json.*valid JSON/i);
});

test("an ESLint launch failure blocks", () => {
  const out = runHook(brokenEslintFixture(), ["src/thing.js"]);
  assert.match(JSON.parse(out).reason, /ESLint.*EACCES/is);
});

test("an ESLint error blocks and names the edited file", () => {
  const reason = JSON.parse(runHook(eslintFixture(), ["src/thing.js"])).reason;
  assert.match(reason, /ESLint failed.*eslint argv:.*src\/thing\.js/is);
});

// A scoped run hands over edited files without consulting the project's
// ignores, so an ignored file reports "File ignored" on exit 0 and would
// otherwise surface as a warning.
test("ESLint is told not to warn about ignored files", () => {
  const reason = JSON.parse(runHook(eslintFixture(), ["src/thing.js"])).reason;
  assert.match(reason, /eslint argv:.*--no-warn-ignored/is);
});

test("Prettier formats the edited file and reports it", () => {
  const dir = prettierFixture();
  const file = join(dir, "src", "thing.js");
  mkdirSync(dirname(file), { recursive: true });
  writeFileSync(file, "const value=1\n");

  const message = JSON.parse(
    runHook(dir, ["src/thing.js"], { writeFiles: false }),
  ).systemMessage;
  assert.match(message, /Prettier: auto-formatted.*src\/thing\.js/is);
  assert.equal(readFileSync(file, "utf-8"), "formatted\n");
});

test("a docs-only edit runs nothing", () => {
  assert.equal(runHook(fixture(), ["README.md"]), "");
});

test("a lockfile-only edit runs nothing", () => {
  assert.equal(runHook(fixture(), ["package-lock.json"]), "");
});

// A stylesheet used to fall through to the whole suite, because only TS/JS was
// collected as a related-tests target. vitest resolves a .css back to the tests
// that import it, so it belongs in the scoped run.
test("a stylesheet edit is scoped, not a full-suite run", () => {
  const reason = JSON.parse(runHook(vitestFixture(), ["src/style.css"])).reason;
  assert.match(reason, /related src\/style\.css --run/);
});

test("a test-config edit still runs the whole suite", () => {
  const reason = JSON.parse(
    runHook(vitestFixture(), ["src/a.ts", "vitest.config.ts"]),
  ).reason;
  assert.match(reason, /argv: run/);
});

// A Stop with no transcript_path at all: with no second source of edited files
// the hook would check nothing and report a clean stop.
test("with no transcript, the git working tree names the edits", () => {
  const reason = JSON.parse(
    runHook(gitFixture(), ["src/thing.ts"], { withTranscript: false }),
  ).reason;
  assert.match(reason, /related src\/thing\.ts/);
});

// Codex sends a transcript_path of its own, pointing at a rollout log in its
// format. None of it parses as Claude's tool calls, so the working tree has to
// stand in — read as an empty edit list, every Codex session would check nothing
// and report a clean stop.
test("a transcript in another format falls back to git", () => {
  const dir = gitFixture();
  const rollout = join(
    realpathSync(mkdtempSync(join(tmpdir(), "rollout-"))),
    "rollout.jsonl",
  );
  writeFileSync(
    rollout,
    JSON.stringify({
      type: "response_item",
      payload: { type: "function_call", name: "shell" },
    }),
  );
  mkdirSync(join(dir, "src"), { recursive: true });
  writeFileSync(join(dir, "src", "thing.ts"), "export const x = 1\n");

  const proc = spawnSync(process.execPath, [HOOK], {
    cwd: dir,
    encoding: "utf-8",
    input: JSON.stringify({ transcript_path: rollout }),
  });
  assert.equal(proc.status, 0);
  assert.match(JSON.parse(proc.stdout.trim()).reason, /related src\/thing\.ts/);
});

// The transcript is the better signal where it exists: it names what the agent
// touched, not what happens to be dirty. Git must not widen that.
test("a transcript wins over an unrelated dirty file", () => {
  const dir = gitFixture();
  mkdirSync(join(dir, "src"), { recursive: true });
  writeFileSync(join(dir, "src", "untouched.ts"), "export const x = 1\n");
  const reason = JSON.parse(runHook(dir, ["src/thing.ts"])).reason;
  assert.match(reason, /related src\/thing\.ts --run/);
  assert.doesNotMatch(reason, /untouched\.ts/);
});

// A turn that only read code produces an empty transcript result, which is not
// the same as no transcript. Falling back to git here would lint and test
// whatever happened to be dirty after a turn that changed nothing.
test("a read-only turn checks nothing, however dirty the tree", () => {
  const dir = gitFixture();
  mkdirSync(join(dir, "src"), { recursive: true });
  writeFileSync(join(dir, "src", "dirty.ts"), "export const x = 1\n");
  const proc = spawnSync(process.execPath, [HOOK], {
    cwd: dir,
    encoding: "utf-8",
    input: JSON.stringify({ transcript_path: transcript(dir, []) }),
  });
  assert.equal(proc.status, 0);
  assert.equal(proc.stdout.trim(), "");
});
