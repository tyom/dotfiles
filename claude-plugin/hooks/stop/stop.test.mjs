// Drives the hook the way Claude Code does — transcript on stdin, decision on
// stdout — against a throwaway project, so nothing here touches a real one.
//
// No lint bins are installed in the fixture, so tsc/eslint/prettier no-op and
// what's under test is the part the merge rewrote: transcript → categorise →
// pick a test command → block or stay quiet.

import test from "node:test";
import assert from "node:assert/strict";
import {
  mkdtempSync,
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
  writeFileSync(join(dir, "bun.lock"), "");
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

// One transcript line per edited file, in the shape the hook parses.
/**
 * @param {string} dir
 * @param {string[]} files
 */
function transcript(dir, files) {
  const path = join(dir, "transcript.jsonl");
  writeFileSync(
    path,
    files
      .map((f) =>
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
      )
      .join("\n"),
  );
  return path;
}

// process.execPath, so the hook is exercised under whichever runtime is running
// the tests rather than a second one that happens to be installed.
/**
 * @param {string} dir
 * @param {string[]} files
 */
function runHook(dir, files, { withTranscript = true } = {}) {
  for (const f of files) {
    mkdirSync(dirname(join(dir, f)), { recursive: true });
    writeFileSync(join(dir, f), "");
  }
  const proc = spawnSync(process.execPath, [HOOK], {
    cwd: dir,
    encoding: "utf-8",
    // No transcript is what Codex sends: it has no Claude Code transcript to
    // point at, so the hook has to find the edits another way.
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

// Codex fires Stop but sends no transcript_path, so without a second source of
// edited files the hook would check nothing and report a clean stop.
test("with no transcript, the git working tree names the edits", () => {
  const reason = JSON.parse(
    runHook(gitFixture(), ["src/thing.ts"], { withTranscript: false }),
  ).reason;
  assert.match(reason, /related src\/thing\.ts/);
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
