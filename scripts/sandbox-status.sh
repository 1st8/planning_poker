#!/usr/bin/env bash
#
# Quick health check for the sandbox environment.
# Verifies that all dependencies are installed and prints their versions.
#
# Usage: ./scripts/sandbox-status.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PG_PORT=5433

errors=0

check() {
  local name="$1"
  local cmd="$2"
  shift 2

  if command -v "$cmd" &>/dev/null; then
    local version
    version=$("$@" 2>&1 || true)
    version="${version%%$'\n'*}"  # first line only
    printf "  %-14s %s\n" "$name" "$version"
  else
    printf "  %-14s MISSING\n" "$name"
    errors=$((errors + 1))
  fi
}

echo "=== Sandbox Status ==="
echo ""

# --- Tool versions from .tool-versions ---
echo "Expected (from .tool-versions):"
while IFS=' ' read -r tool version; do
  [[ -z "$tool" || "$tool" == \#* ]] && continue
  printf "  %-14s %s\n" "$tool" "$version"
done < "$PROJECT_DIR/.tool-versions"
echo ""

# --- Installed versions ---
echo "Installed:"
check "erlang" erl erl -eval 'io:format("OTP ~s (erts ~s)", [erlang:system_info(otp_release), erlang:system_info(version)]), halt().' -noshell

# elixir --version is multi-line; grab the "Elixir x.y.z" line
if command -v elixir &>/dev/null; then
  elixir_ver=$(elixir --version 2>&1 | grep -oP 'Elixir \S+' || true)
  printf "  %-14s %s\n" "elixir" "${elixir_ver:-unknown}"
else
  printf "  %-14s MISSING\n" "elixir"
  errors=$((errors + 1))
fi
check "postgresql" psql psql --version
check "node" node node --version
check "npm" npm npm --version
check "gcc" gcc gcc --version
echo ""

# --- PostgreSQL status ---
echo "PostgreSQL (port $PG_PORT):"
if pg_isready -p "$PG_PORT" -q 2>/dev/null; then
  echo "  Status:        running"
else
  echo "  Status:        NOT RUNNING"
  errors=$((errors + 1))
fi
echo ""

# --- Hex & Rebar ---
echo "Mix tooling:"
if mix archive 2>/dev/null | grep -q hex 2>/dev/null || mix hex.info &>/dev/null; then
  hex_version=$(mix hex.info 2>&1 | grep -oP 'Hex:\s+\S+' || true)
  printf "  %-14s %s\n" "hex" "${hex_version:-installed}"
else
  printf "  %-14s MISSING\n" "hex"
  errors=$((errors + 1))
fi

if find "$HOME/.mix" -name rebar3 -print -quit 2>/dev/null | grep -q .; then
  printf "  %-14s installed\n" "rebar3"
else
  printf "  %-14s MISSING\n" "rebar3"
  errors=$((errors + 1))
fi
echo ""

# --- Project deps ---
echo "Project deps:"
cd "$PROJECT_DIR"
if [ -d "deps" ] && [ "$(ls deps/ 2>/dev/null | wc -l)" -gt 0 ]; then
  dep_count=$(ls deps/ | wc -l)
  printf "  %-14s %s packages in deps/\n" "fetched" "$dep_count"
else
  printf "  %-14s NOT FETCHED\n" "deps"
  errors=$((errors + 1))
fi
echo ""

# --- Playwright ---
echo "Playwright:"
e2e_dir="$PROJECT_DIR/test/e2e"
if [ -d "$e2e_dir/node_modules" ]; then
  pw_version=$(cd "$e2e_dir" && npx playwright --version 2>/dev/null || echo "installed")
  printf "  %-14s %s\n" "playwright" "$pw_version"
else
  printf "  %-14s NOT INSTALLED\n" "playwright"
  errors=$((errors + 1))
fi
echo ""

# --- Summary ---
if [ "$errors" -eq 0 ]; then
  echo "=== All checks passed ==="
else
  echo "=== $errors check(s) failed ==="
  exit 1
fi
