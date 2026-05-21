#!/usr/bin/env python3
"""Bundle src/repo-intel into a single-file executable.

Substitutes two placeholders in repo-intel.py with their data as Python string
literals — TEMPLATE with template.html, TECHDATA with techdata.json — then
writes the result to the given output path with mode 0755.
"""

import os
import sys
from pathlib import Path

TEMPLATE_PLACEHOLDER = 'TEMPLATE = "__TEMPLATE_PLACEHOLDER__"'
TECHDATA_PLACEHOLDER = 'TECHDATA = "__TECHDATA_PLACEHOLDER__"'


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: build.py OUTPUT_PATH")
    out_path = Path(sys.argv[1])

    src_dir = Path(__file__).resolve().parent
    script = (src_dir / "repo-intel.py").read_text()
    template = (src_dir / "template.html").read_text()

    techdata_path = src_dir / "techdata.json"
    if not techdata_path.exists():
        sys.exit(
            f"error: {techdata_path} not found — run `make repo-intel-techdata` "
            "(needs network) to generate it, then commit it."
        )
    techdata = techdata_path.read_text()

    for name, placeholder in (
        ("template.html", TEMPLATE_PLACEHOLDER),
        ("techdata.json", TECHDATA_PLACEHOLDER),
    ):
        if script.count(placeholder) != 1:
            sys.exit(f"error: expected exactly one {placeholder!r} line in repo-intel.py")

    bundled = (
        script
        .replace(TEMPLATE_PLACEHOLDER, f"TEMPLATE = {template!r}")
        .replace(TECHDATA_PLACEHOLDER, f"TECHDATA = {techdata!r}")
    )
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(bundled)
    out_path.chmod(0o755)
    print(f"built {out_path} ({os.path.getsize(out_path):,} bytes)")


if __name__ == "__main__":
    main()
