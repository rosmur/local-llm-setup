#!/bin/bash
# Install .githooks/ as the git hooks directory for this repo.
# Run once after cloning.

set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

git config core.hooksPath .githooks

echo "✓ Git hooks directory set to .githooks/"
echo "  Pre-commit hook will regenerate README.md from docs/ on every commit."
