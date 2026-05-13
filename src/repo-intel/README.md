# repo-intel

Source for the `repo-intel` contributor-stats dashboard. The shipped
executable at `stow/bin/repo-intel` is built from the files here — the
HTML template is embedded into the script so the artifact is
single-file and depends only on Python 3 + `git`.

## Files

| File            | Purpose                                                                 |
| --------------- | ----------------------------------------------------------------------- |
| `repo-intel.py` | The script. Holds `TEMPLATE = "__TEMPLATE_PLACEHOLDER__"` until bundled |
| `template.html` | Dashboard HTML, with `/*__DATA_INJECTION__*/` for runtime data          |
| `build.py`      | Substitutes the `TEMPLATE =` line with `template.html` as a `repr()`    |

## Workflows

**Build the shipped artifact** (run after editing source or template):

```bash
make repo-intel-build
```

Writes `stow/bin/repo-intel` (chmod 0755). Commit both source and
artifact — the artifact is checked in so a fresh clone + `make install`
works without a build step.

**Develop against the template live** (no rebuild needed between edits):

```bash
make repo-intel-dev                          # uses cwd, top 10
make repo-intel-dev ARGS="3 facebook/react"  # top 3 of a remote repo
```

The source script auto-detects that `TEMPLATE` is still the placeholder
and falls back to reading `template.html` from disk. The built artifact
never hits that branch — it carries the embedded template.

## How the embedding works

`build.py` looks for exactly one occurrence of the line:

```python
TEMPLATE = "__TEMPLATE_PLACEHOLDER__"
```

and replaces it with `TEMPLATE = <repr(template_html)>`. The result is
a valid Python file — one long string literal on line 48 of the
artifact. Templating happens at build time; the runtime substitution of
`/*__DATA_INJECTION__*/` with `window.__DATA__ = {...}` still happens
inside `main()` as before.
