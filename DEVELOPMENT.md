# Development

Run the fast tests, or install into a container instead of your machine:

```bash
# Fast installer, shell, PATH-script and Stop-hook tests
make check

# Run setup and validation
make docker-test

# Interactive shell (persistent state)
make docker-shell

# Run setup and drop into shell
make docker-setup

# Clean up persistent containers
make docker-clean
```

## Minimal Setup (No Homebrew/Bun)

Add `VARIANT=minimal` to install without Homebrew or Bun:

```bash
# Run minimal setup and validation
make docker-test VARIANT=minimal

# Interactive shell with minimal setup (persistent state)
make docker-shell VARIANT=minimal

# Run minimal setup and drop into shell
make docker-setup VARIANT=minimal
```

That variant builds on `ubuntu:24.04` rather than `homebrew/brew`, so it covers
the paths taken when `brew` and `bun` are missing. CI runs both.

## Testing Remote Install

```bash
# Test local changes via HTTP server (before deployment)
make docker-test-remote-local

# Smoke test the deployed URL (after merge to master)
make docker-test-remote
```

## Repinning Bootstrap Dependencies

`scripts/versions.sh` records the reviewed Bun and Volta releases, the Oh My Zsh
commit, and the Homebrew installer commit, with SHA-256 checksums for downloaded
scripts. Refresh all of them explicitly:

```bash
make repin
git diff -- scripts/versions.sh
make check
```

Review the diff before committing it. Installation never changes these pins.

## Makefile Commands

Run `make` to see all available commands:

| Command                         | Description                               |
| ------------------------------- | ----------------------------------------- |
| `make install`                  | Install dotfiles on local machine         |
| `make uninstall`                | Remove dotfiles symlinks                  |
| `make check`                    | Run the fast local tests                  |
| `make repin`                    | Refresh bootstrap versions and checksums  |
| `make brew`                     | Install Homebrew packages                 |
| `make docker-build`             | Build Docker test image                   |
| `make docker-test`              | Run setup and validation in Docker        |
| `make docker-setup`             | Run setup and drop into shell             |
| `make docker-shell`             | Start persistent shell in Docker          |
| `make docker-clean`             | Remove persistent Docker containers       |
| `make docker-test-remote`       | Smoke test remote install (deployed URL)  |
| `make docker-test-remote-local` | Test remote install via local HTTP server |

Docker commands support `VARIANT=minimal` for testing without Homebrew/Bun (e.g., `make docker-test VARIANT=minimal`).
