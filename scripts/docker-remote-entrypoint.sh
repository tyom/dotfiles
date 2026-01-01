#!/bin/bash

# Docker entrypoint for remote install testing
# Usage:
#   docker run <image> remote-test       # Test deployed URL
#   docker run <image> remote-test-local # Test via local HTTP server

set -e

export YES_OVERRIDE=true

case "${1:-remote-test}" in
remote-test)
  echo "Testing remote install from deployed URL..."
  echo "URL: https://tyom.github.io/dotfiles/install.sh"
  echo ""
  curl -fsSL https://tyom.github.io/dotfiles/install.sh | bash
  echo ""
  echo "Remote install test completed successfully!"
  ;;
remote-test-local)
  echo "Testing remote install via local HTTP server..."
  echo ""

  # Start HTTP server in background
  cd /tmp/docs
  python3 -m http.server 8080 &
  SERVER_PID=$!

  # Wait for server to be ready
  for i in {1..10}; do
    if curl -fsSL --max-time 1 http://localhost:8080/ >/dev/null 2>&1; then
      break
    fi
    sleep 0.5
  done

  # Test the install
  echo "Fetching from http://localhost:8080/install.sh"
  curl -fsSL http://localhost:8080/install.sh | bash

  # Cleanup
  kill $SERVER_PID 2>/dev/null || true

  echo ""
  echo "Local remote install test completed successfully!"
  ;;
*)
  exec "$@"
  ;;
esac
