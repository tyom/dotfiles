#!/bin/bash

source shell/utils.sh

# Tools installed via curl (supports self-upgrade features)

# Bun - Fast JavaScript runtime, bundler, and package manager
# https://bun.sh
if ! exists bun; then
  print_step 'Installing Bun'
  curl -fsSL https://bun.sh/install | bash
else
  print_info "Bun already installed. Skipping."
fi
