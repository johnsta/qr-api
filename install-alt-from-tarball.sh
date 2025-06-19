#!/bin/bash
# install-alt-from-tarball.sh
# Usage: ./install-alt-from-tarball.sh <path-to-tarball>
# Example: ./install-alt-from-tarball.sh ./.build/testing.tgz

set -euo pipefail

TARBALL="${1:-.build/testing.tgz}"
PKGDIR="package"

# Create package directory
mkdir -p "$PKGDIR"

echo "Extracting tarball $TARBALL to $PKGDIR..."
tar -xzf "$TARBALL" -C "$PKGDIR" --strip-components=1
ls -l "$PKGDIR"

# Change package name and bin in package.json using jq for safe JSON edits
jq '.name = "alt" | .bin = {"alt": "index.js"}' "$PKGDIR/package.json" > "$PKGDIR/package.tmp.json" && mv "$PKGDIR/package.tmp.json" "$PKGDIR/package.json"
cat "$PKGDIR/package.json"
echo "Changed package name to alt and bin to alt in $PKGDIR/package.json"

# Ensure index.js is executable
chmod +x "$PKGDIR/index.js"
echo "Ensured $PKGDIR/index.js is executable"

# Install alt globally from extracted package
echo "Installing alt globally from $PKGDIR..."
npm install -g "./$PKGDIR" --verbose

echo "Verifying alt is installed..."
npm list -g --depth=0 | grep 'alt' || echo "alt not found in global npm list"
npm root -g
npx --no alt --version || echo "npx alt failed"