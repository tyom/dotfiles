// Drives the hook the way Claude Code does — transcript on stdin, decision on
// stdout — against a throwaway project, so nothing here touches a real one.
//
// No lint bins are installed in the fixture, so tsc/eslint/prettier no-op and
// what's under test is the part the merge rewrote: transcript → categorise →
// pick a test command → block or stay quiet.

import { test, expect } from "bun:test";
import { mkdtempSync, writeFileSync, mkdirSync, realpathSync } from "fs";
import { tmpdir } from "os";
import { join, dirname } from "path";

const HOOK = join(import.meta.dir, "stop.ts");

// A project whose test script always fails, so a run that happens is visible.
function fixture(): string {
  // realpath: on macOS $TMPDIR is a symlink, and the hook compares edited paths
  // against the resolved cwd it is launched in.
  const dir = realpathSync(mkdtempSync(join(tmpdir(), "stop-hook-")));
  writeFileSync(
    join(dir, "package.json"),
    JSON.stringify({ name: "fixture", scripts: { test: "exit 1" } }),
  );
  writeFileSync(join(dir, "bun.lock"), "");
  return dir;
}

// One transcript line per edited file, in the shape the hook parses.
function transcript(dir: string, files: string[]): string {
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

function runHook(dir: string, files: string[]): string {
  for (const f of files) {
    mkdirSync(dirname(join(dir, f)), { recursive: true });
    writeFileSync(join(dir, f), "");
  }
  const proc = Bun.spawnSync(["bun", "run", HOOK], {
    cwd: dir,
    stdin: Buffer.from(
      JSON.stringify({ transcript_path: transcript(dir, files) }),
    ),
  });
  return proc.stdout.toString().trim();
}

test("a failing suite blocks when source was edited", () => {
  const out = runHook(fixture(), ["src/thing.ts"]);
  expect(JSON.parse(out).decision).toBe("block");
});

test("a docs-only edit runs nothing", () => {
  expect(runHook(fixture(), ["README.md"])).toBe("");
});

test("a lockfile-only edit runs nothing", () => {
  expect(runHook(fixture(), ["package-lock.json"])).toBe("");
});
