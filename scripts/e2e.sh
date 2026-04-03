#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/.."
E2E_DIR="$PROJECT_DIR/test/e2e"

# Derive project name from mix.exs for sandbox build path
PROJECT_NAME="$(grep -oP '(?<=app: :)\w+' "$PROJECT_DIR/mix.exs" | head -1)"

# Sandbox: use separate build dir to avoid compile env conflicts
if [[ "${MIX_BUILD_PATH:-}" == */".mix_build/"* ]]; then
  export MIX_BUILD_PATH="${MIX_BUILD_PATH%/*}/${PROJECT_NAME}_e2e"
fi
export MIX_ENV=e2e

cd "$E2E_DIR"
npm install --silent 2>/dev/null
npx playwright test "$@"
