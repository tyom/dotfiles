# Reviewed bootstrap inputs. Update safely with `make repin`.
BUN_VERSION=1.3.14
BUN_INSTALL_URL=https://raw.githubusercontent.com/oven-sh/bun/bun-v1.3.14/src/cli/install.sh
BUN_INSTALL_SHA256=bab8acfb046aac8c72407bdcce903957665d655d7acaa3e11c7c4616beae68dd

VOLTA_VERSION=2.0.2
VOLTA_INSTALL_URL=https://raw.githubusercontent.com/volta-cli/volta/e83f04ccd79be994c0e65c0bb56838fbcda6fcf9/dev/unix/volta-install.sh
VOLTA_INSTALL_SHA256=fbdc4b8cb33fb6d19e5f07b22423265943d34e7e5c3d5a1efcecc9621854f9cb

: "${OH_MY_ZSH_REMOTE:=https://github.com/ohmyzsh/ohmyzsh.git}"
: "${OH_MY_ZSH_COMMIT:=b54a71977574cfcf659cc2f15a5e6422f17a8da7}"

HOMEBREW_INSTALL_URL=https://raw.githubusercontent.com/Homebrew/install/6cb910c93f8194b1661a490278a488482399d380/install.sh
HOMEBREW_INSTALL_SHA256=12479a24be3f5307eecac7cde670fad7118640f031229e964f544b1367b52a41
