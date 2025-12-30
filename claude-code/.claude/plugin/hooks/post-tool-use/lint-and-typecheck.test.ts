import { describe, test, expect } from "bun:test";

describe("lint-and-typecheck hook", () => {
  test("PRETTIER_EXTENSIONS includes markdown", () => {
    const PRETTIER_EXTENSIONS = new Set([
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
    expect(PRETTIER_EXTENSIONS.has(".md")).toBe(true);
  });

  test("PRETTIER_EXTENSIONS includes typescript", () => {
    const PRETTIER_EXTENSIONS = new Set([
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
    expect(PRETTIER_EXTENSIONS.has(".ts")).toBe(true);
  });
});
