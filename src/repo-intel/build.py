#!/usr/bin/env python3
"""Bundle src/repo-intel into a single-file executable.

Substitutes the TEMPLATE placeholder in repo-intel.py with the contents
of template.html as a Python string literal, then writes the result to
the given output path with mode 0755.
"""

import os
import sys
from pathlib import Path

PLACEHOLDER = 'TEMPLATE = "__TEMPLATE_PLACEHOLDER__"'


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: build.py OUTPUT_PATH")
    out_path = Path(sys.argv[1])

    src_dir = Path(__file__).resolve().parent
    script = (src_dir / "repo-intel.py").read_text()
    template = (src_dir / "template.html").read_text()

    if script.count(PLACEHOLDER) != 1:
        sys.exit(f"error: expected exactly one {PLACEHOLDER!r} line in repo-intel.py")

    bundled = script.replace(PLACEHOLDER, f"TEMPLATE = {template!r}")
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(bundled)
    out_path.chmod(0o755)
    print(f"built {out_path} ({os.path.getsize(out_path):,} bytes)")


if __name__ == "__main__":
    main()
