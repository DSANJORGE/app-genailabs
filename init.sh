#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TARGET_DIR="$PARENT_DIR/eme_app_package"
REPO_URL="https://github.com/entermedia-community/eme-app-package"

if [ -d "$TARGET_DIR" ]; then
  echo "Directory '$TARGET_DIR' already exists. Skipping fork & clone."
else
  echo "Forking and cloning $REPO_URL into $TARGET_DIR..."
  cd "$PARENT_DIR"
  gh repo fork "$REPO_URL" --clone -- eme_app_package
fi

echo ""
echo "======================================================================="
echo "Please now open eme_app_package/eme_app_package.code-workspace"
echo "======================================================================="
