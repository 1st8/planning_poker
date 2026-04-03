#!/usr/bin/env bash
# Bump version: creates a new git tag with incremented version number.
# Usage: scripts/bump.sh [build|minor|major]
# Default: build

set -euo pipefail

SED_I=(sed -i"$(if [[ "$OSTYPE" == darwin* ]]; then echo ' '; fi)")
BUMP="${1:-build}"

# Get latest version tag, default to v0.0.0 if none exists
LATEST=$(git tag --list 'v[0-9]*' | sort -V | tail -1)
LATEST="${LATEST:-v0.0.0}"

# Parse version components
VERSION="${LATEST#v}"
IFS='.' read -r MAJOR MINOR BUILD <<< "$VERSION"

case "$BUMP" in
  major) MAJOR=$((MAJOR + 1)); MINOR=0; BUILD=0 ;;
  minor) MINOR=$((MINOR + 1)); BUILD=0 ;;
  build) BUILD=$((BUILD + 1)) ;;
  *) echo "Usage: $0 [build|minor|major]"; exit 1 ;;
esac

NEW_TAG="v${MAJOR}.${MINOR}.${BUILD}"

NEW_VERSION="${MAJOR}.${MINOR}.${BUILD}"

# Update version in mix.exs
"${SED_I[@]}" "s/version: \"[^\"]*\"/version: \"${NEW_VERSION}\"/" mix.exs

# Update version and appVersion in chart/Chart.yaml (if present)
if [ -f chart/Chart.yaml ]; then
  "${SED_I[@]}" "s/^version: .*/version: ${NEW_VERSION}/" chart/Chart.yaml
  "${SED_I[@]}" "s/^appVersion: .*/appVersion: \"${NEW_VERSION}\"/" chart/Chart.yaml
  git add mix.exs chart/Chart.yaml
else
  git add mix.exs
fi
git commit -m "Bump version to ${NEW_VERSION}"

git tag "$NEW_TAG"
echo "$LATEST -> $NEW_TAG"
