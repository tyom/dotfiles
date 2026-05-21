#!/usr/bin/env python3
"""Generate techdata.json — language + framework detection data for repo-intel.

Languages are generated from GitHub Linguist (the canonical, maintained source
for extension→language mappings and the official colors); frameworks are a
small curated map. We evaluated scraping Vercel's `frameworks.ts` for the JS
side but it targets *deployment-framework CLIs* (`next`, `react-scripts`), not
the libraries a repo uses — `react`/`express`/`vue` aren't in it — so it's the
wrong shape for "what does this repo use" and the curated map stays on-target.

Writes a single committed JSON snapshot that repo-intel.py loads (and that
build.py embeds into the artifact):

  - Languages: Linguist `languages.yml` (extension/filename → language, colors,
    with fine-grained languages folded into their `group`, e.g. TSX→TypeScript)
    + `vendor.yml` (vendored-path regexes for the noise filter).
  - Frameworks: curated dependency → framework maps (web + backend) below.

Run via `make repo-intel-techdata` (needs network). Stdlib-only.
"""

import json
import re
import sys
import urllib.request
from pathlib import Path

LANGUAGES_YML = "https://raw.githubusercontent.com/github-linguist/linguist/master/lib/linguist/languages.yml"
VENDOR_YML = "https://raw.githubusercontent.com/github-linguist/linguist/master/lib/linguist/vendor.yml"

OUT = Path(__file__).resolve().parent / "techdata.json"

TYPE_RANK = {"programming": 0, "markup": 1, "data": 2, "prose": 3, "": 4}

# Ambiguous extensions claimed by several languages. Linguist resolves these in
# code (a classifier + popularity), not data, so derivation alone mis-assigns
# (e.g. `.md` → "GCC Machine Description"). This tiebreaker layer pins the few
# that users actually notice; the chosen name must be a real Linguist language.
EXT_OVERRIDE = {
    "md": "Markdown", "markdown": "Markdown", "h": "C", "m": "Objective-C",
    "r": "R", "pl": "Perl", "t": "Perl", "l": "Common Lisp", "v": "Verilog",
    "f": "Fortran", "for": "Fortran", "cls": "Apex", "pro": "Prolog",
    "ts": "TypeScript", "rs": "Rust", "cs": "C#", "sql": "SQL",
}

# Curated web/npm dependency → framework display name. Vercel/Netlify answer a
# different question (deploy presets), so this is maintained directly.
CURATED_WEB = {
    "react": "React", "react-dom": "React", "next": "Next.js",
    "vue": "Vue", "nuxt": "Nuxt", "@angular/core": "Angular",
    "svelte": "Svelte", "@sveltejs/kit": "SvelteKit",
    "solid-js": "SolidJS", "preact": "Preact", "astro": "Astro",
    "gatsby": "Gatsby", "@remix-run/react": "Remix",
    "express": "Express", "koa": "Koa", "fastify": "Fastify",
    "@nestjs/core": "NestJS", "@hapi/hapi": "hapi",
    "electron": "Electron", "react-native": "React Native",
    "expo": "Expo", "@ionic/core": "Ionic",
    "vite": "Vite", "webpack": "webpack", "rollup": "Rollup",
    "esbuild": "esbuild", "parcel": "Parcel",
    "tailwindcss": "Tailwind CSS", "bootstrap": "Bootstrap",
    "@mui/material": "MUI", "@chakra-ui/react": "Chakra UI",
    "styled-components": "styled-components",
    "jest": "Jest", "vitest": "Vitest", "mocha": "Mocha",
    "playwright": "Playwright", "@playwright/test": "Playwright",
    "cypress": "Cypress", "puppeteer": "Puppeteer", "testcafe": "TestCafe",
    "@testing-library/react": "Testing Library",
    "@testing-library/vue": "Testing Library",
    "@testing-library/dom": "Testing Library",
    "eslint": "ESLint", "prettier": "Prettier", "@biomejs/biome": "Biome",
    # Storybook ships across many scoped packages; the framework adapters below
    # cover both apps that embed it and addons that declare it as a peer dep.
    "storybook": "Storybook", "@storybook/react": "Storybook",
    "@storybook/vue3": "Storybook", "@storybook/angular": "Storybook",
    "@storybook/svelte": "Storybook", "@storybook/html": "Storybook",
    "@storybook/web-components": "Storybook", "@storybook/preact": "Storybook",
    # Monorepo / task runners.
    "turbo": "Turborepo", "nx": "Nx", "@nx/workspace": "Nx",
    # Transpilers.
    "@swc/core": "SWC", "@babel/core": "Babel",
    "redux": "Redux", "@reduxjs/toolkit": "Redux", "zustand": "Zustand",
    "@apollo/client": "Apollo", "graphql": "GraphQL",
    "@trpc/server": "tRPC", "@trpc/client": "tRPC",
    "prisma": "Prisma", "@prisma/client": "Prisma",
    "drizzle-orm": "Drizzle", "typeorm": "TypeORM",
    "mongoose": "Mongoose", "sequelize": "Sequelize",
    "three": "three.js", "d3": "D3", "chart.js": "Chart.js",
}

# Web/JS sentinel files: basename → framework (assigned to the JS/TS bucket).
CURATED_SENTINELS_JS = [
    ["next.config.js", "Next.js"], ["next.config.ts", "Next.js"],
    ["next.config.mjs", "Next.js"], ["nuxt.config.js", "Nuxt"],
    ["nuxt.config.ts", "Nuxt"], ["svelte.config.js", "Svelte"],
    ["astro.config.mjs", "Astro"], ["vue.config.js", "Vue"],
    ["gatsby-config.js", "Gatsby"], ["angular.json", "Angular"],
]

# Backend frameworks Vercel/Netlify don't cover — keyed by language, then
# dependency name → display name. Matched as whole words in manifest text.
CURATED_BACKEND = {
    "Python": {
        "django": "Django", "djangorestframework": "Django REST",
        "flask": "Flask", "fastapi": "FastAPI", "starlette": "Starlette",
        "tornado": "Tornado", "aiohttp": "aiohttp", "sanic": "Sanic",
        "pyramid": "Pyramid", "sqlalchemy": "SQLAlchemy", "pydantic": "Pydantic",
        "celery": "Celery", "scrapy": "Scrapy", "numpy": "NumPy",
        "pandas": "pandas", "scipy": "SciPy", "scikit-learn": "scikit-learn",
        "tensorflow": "TensorFlow", "torch": "PyTorch", "keras": "Keras",
        "transformers": "Transformers", "matplotlib": "Matplotlib",
        "pytest": "pytest", "click": "Click", "typer": "Typer",
        "requests": "Requests", "httpx": "HTTPX",
    },
    "Ruby": {
        "rails": "Rails", "sinatra": "Sinatra", "hanami": "Hanami",
        "rspec": "RSpec", "sidekiq": "Sidekiq", "puma": "Puma", "devise": "Devise",
    },
    "Go": {
        "github.com/gin-gonic/gin": "Gin", "github.com/labstack/echo": "Echo",
        "github.com/gofiber/fiber": "Fiber", "github.com/gorilla/mux": "Gorilla",
        "gorm.io/gorm": "GORM", "github.com/spf13/cobra": "Cobra",
        "github.com/go-chi/chi": "chi", "google.golang.org/grpc": "gRPC",
    },
    "Rust": {
        "actix-web": "Actix Web", "axum": "Axum", "rocket": "Rocket",
        "warp": "warp", "tokio": "Tokio", "serde": "Serde", "diesel": "Diesel",
        "tonic": "Tonic", "clap": "clap", "bevy": "Bevy", "tauri": "Tauri",
    },
    "PHP": {
        "laravel/framework": "Laravel", "symfony/symfony": "Symfony",
        "symfony/framework-bundle": "Symfony", "slim/slim": "Slim",
        "cakephp/cakephp": "CakePHP", "yiisoft/yii2": "Yii",
    },
}

# Colors for synthetic framework groups Linguist doesn't define a language for.
# Purple keeps "Tools" distinct from the grey "Other" bucket on the same page.
SYNTHETIC_COLORS = {"Tools": "#a371f7"}

# Backend / non-JS sentinel files: basename (or sub-path) → (framework, language).
# The "Tools" bucket surfaces build/devops tooling that's present as a config
# file rather than a dependency — it'd otherwise hide in the long tail of the
# language bar (Dockerfile/Makefile are tiny by line count).
CURATED_SENTINELS = [
    ["manage.py", "Django", "Python"],
    ["artisan", "Laravel", "PHP"],
    ["config/application.rb", "Rails", "Ruby"],
    ["Dockerfile", "Docker", "Tools"],
    ["docker-compose.yml", "Docker Compose", "Tools"],
    ["docker-compose.yaml", "Docker Compose", "Tools"],
    ["compose.yml", "Docker Compose", "Tools"],
    ["compose.yaml", "Docker Compose", "Tools"],
    ["Makefile", "Make", "Tools"],
    ["GNUmakefile", "Make", "Tools"],
    ["pnpm-lock.yaml", "pnpm", "Tools"],
    ["yarn.lock", "Yarn", "Tools"],
    ["bun.lockb", "Bun", "Tools"],
    ["bun.lock", "Bun", "Tools"],
    [".gitlab-ci.yml", "GitLab CI", "Tools"],
    ["vercel.json", "Vercel", "Tools"],
    ["netlify.toml", "Netlify", "Tools"],
    # Trailing slash → directory-prefix match (no single file to key on).
    [".github/workflows/", "GitHub Actions", "Tools"],
]


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": "repo-intel-gen"})
    with urllib.request.urlopen(req, timeout=10) as resp:
        return resp.read().decode("utf-8")


def parse_languages_yml(text):
    """Line-parse Linguist languages.yml (machine-generated, regular).

    Returns {name: {"type", "color", "extensions": [...], "filenames": [...]}}.
    """
    langs = {}
    cur = None
    listkey = None
    for raw in text.splitlines():
        if not raw or raw.lstrip().startswith("#"):
            continue
        if not raw[0].isspace():  # column-0 language header
            m = re.match(r'^(?:"([^"]+)"|\'([^\']+)\'|([^:]+)):\s*$', raw)
            if m:
                name = m.group(1) or m.group(2) or m.group(3)
                cur = {"type": "", "color": "", "group": "",
                       "extensions": [], "filenames": []}
                langs[name] = cur
                listkey = None
            else:
                cur = None
            continue
        if cur is None:
            continue
        item = re.match(r'^  - (.*)$', raw)
        if item and listkey:
            val = item.group(1).strip().strip('"').strip("'")
            cur[listkey].append(val)
            continue
        prop = re.match(r'^  (\w+):\s*(.*)$', raw)
        if prop:
            key, val = prop.group(1), prop.group(2).strip()
            if key in ("extensions", "filenames") and val == "":
                listkey = key
            else:
                listkey = None
                if key == "color":
                    cur["color"] = val.strip('"').strip("'")
                elif key == "type":
                    cur["type"] = val
                elif key == "group":
                    cur["group"] = val.strip('"').strip("'")
    return langs


def build_language_tables(langs):
    """ext/filename → language name and name → color, colored languages only.

    Fine-grained languages are folded into their `group` (TSX→TypeScript) so the
    bar doesn't fragment; ambiguous extensions are pinned via EXT_OVERRIDE.
    """
    name_color = {n: i["color"] for n, i in langs.items() if i.get("color")}
    ext_lang, ext_meta, filename_lang = {}, {}, {}
    for name, info in langs.items():
        if not info.get("color"):
            continue
        # Roll fine-grained langs into their parent, but only when that parent
        # is itself a colored language — otherwise a group like "Checksums"
        # would seed color-less entries.
        group = info.get("group")
        eff = group if group and group in name_color else name
        rank = TYPE_RANK.get(info.get("type", ""), 4)
        for idx, ext in enumerate(info.get("extensions", [])):
            key = ext[1:].lower() if ext.startswith(".") else ext.lower()
            if not key:
                continue
            primary = idx == 0
            if key not in ext_lang:
                ext_lang[key] = eff
                ext_meta[key] = (rank, primary)
            else:
                prank, pprimary = ext_meta[key]
                # Prefer better type rank; then a primary extension over secondary.
                if rank < prank or (rank == prank and primary and not pprimary):
                    ext_lang[key] = eff
                    ext_meta[key] = (rank, primary)
        for fn in info.get("filenames", []):
            filename_lang.setdefault(fn.lower(), eff)
    for ext, lang in EXT_OVERRIDE.items():
        if lang in name_color:
            ext_lang[ext] = lang
    name_color.update(SYNTHETIC_COLORS)  # synthetic buckets Linguist doesn't color
    return name_color, ext_lang, filename_lang


def parse_vendor_yml(text):
    out = []
    for line in text.splitlines():
        m = re.match(r'^- (.*)$', line)
        if m:
            out.append(m.group(1).strip())
    return out


def main():
    print("fetching Linguist languages.yml…", file=sys.stderr)
    langs = parse_languages_yml(fetch(LANGUAGES_YML))
    name_color, ext_lang, filename_lang = build_language_tables(langs)
    print(f"  {len(name_color)} colored languages, {len(ext_lang)} extensions",
          file=sys.stderr)

    print("fetching Linguist vendor.yml…", file=sys.stderr)
    vendor = parse_vendor_yml(fetch(VENDOR_YML))
    print(f"  {len(vendor)} vendor patterns", file=sys.stderr)

    fw_deps = {"npm": CURATED_WEB}
    fw_deps.update(CURATED_BACKEND)

    data = {
        "_source": {"languages": LANGUAGES_YML, "vendor": VENDOR_YML},
        "lang": {"ext": ext_lang, "filename": filename_lang, "color": name_color},
        "vendor": vendor,
        "fw_deps": fw_deps,
        "fw_sentinels_js": CURATED_SENTINELS_JS,
        "fw_sentinels_other": CURATED_SENTINELS,
    }
    OUT.write_text(json.dumps(data, ensure_ascii=False, indent=1, sort_keys=True))
    print(f"wrote {OUT} ({OUT.stat().st_size:,} bytes)", file=sys.stderr)


if __name__ == "__main__":
    main()
