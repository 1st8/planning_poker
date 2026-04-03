#!/usr/bin/env bash
# Auto-push: checks every 60s for unpushed commits and pushes them.
# When a new version tag (vX.Y.Z) is detected, also deploys to dokku in the background.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Derive dokku app name from mix.exs (replace underscores with hyphens)
PROJECT_NAME="$(grep -oP '(?<=app: :)\w+' "$PROJECT_DIR/mix.exs" | head -1)"
DOKKU_APP="${PROJECT_NAME//_/-}"

LAST_DEPLOYED_TAG=""

while true; do
  # Push unpushed commits to origin
  git log @{u}..HEAD --oneline | grep -q . && echo "[autopush] Pushing to origin..." && git push -q

  # Check for latest version tag on HEAD
  CURRENT_TAG=$(git tag --points-at HEAD | grep -E '^v[0-9]+\.[0-9]+' | sort -V | tail -1)

  if [[ -n "$CURRENT_TAG" && "$CURRENT_TAG" != "$LAST_DEPLOYED_TAG" ]]; then
    echo "[autopush] New version tag detected: $CURRENT_TAG — deploying to dokku ($DOKKU_APP)..."
    git push dokku main &
    LAST_DEPLOYED_TAG="$CURRENT_TAG"
  fi

  read -t 60 -s -n 1 && echo "[autopush] Manual trigger..."
done
