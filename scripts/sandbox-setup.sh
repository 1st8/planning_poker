#!/usr/bin/env bash
#
# Sandbox setup for Docker/CI environments.
#
# Installs everything needed to run `mix test` and `mix phx.server`:
#   - Erlang (prebuilt via apt, avoids OOM from source compilation)
#   - Elixir (prebuilt from GitHub releases)
#   - PostgreSQL (configured on port 5433 to match dev/test config)
#   - build-essential (for NIFs that need source compilation)
#   - hex, rebar, project deps
#
# Reads .tool-versions for the desired Elixir version.
# Idempotent — safe to run multiple times.
#
# Usage: ./scripts/sandbox-setup.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PERSISTENT_ENV="${CLAUDE_ENV_FILE:-/etc/sandbox-persistent.sh}"
PG_PORT=5433

# Derive project name from mix.exs (underscore form, e.g. planning_poker)
PROJECT_NAME="$(grep -oP '(?<=app: :)\w+' "$PROJECT_DIR/mix.exs" | head -1)"
if [ -z "$PROJECT_NAME" ]; then
  echo "ERROR: Could not determine project name from mix.exs" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Parse .tool-versions
# ---------------------------------------------------------------------------
elixir_full="$(grep '^elixir' "$PROJECT_DIR/.tool-versions" | awk '{print $2}')"
elixir_version="${elixir_full%%-otp-*}"  # e.g. 1.19.5

if [ -z "$elixir_version" ]; then
  echo "ERROR: Could not parse elixir version from .tool-versions" >&2
  exit 1
fi

echo "==> Target versions: Elixir $elixir_version (system Erlang from apt)"

# ---------------------------------------------------------------------------
# System packages (Erlang, PostgreSQL, build tools)
# ---------------------------------------------------------------------------
install_apt_packages() {
  local needs_install=false

  command -v erl &>/dev/null || needs_install=true
  command -v pg_isready &>/dev/null || needs_install=true
  command -v gcc &>/dev/null || needs_install=true

  if [ "$needs_install" = true ]; then
    echo "==> Installing system packages..."
    sudo apt-get update -qq
    sudo apt-get install -y -qq erlang postgresql postgresql-client build-essential erlang-dev
  else
    echo "==> System packages already installed, skipping"
  fi
}

install_apt_packages

otp_major="$(erl -eval 'io:format("~s", [erlang:system_info(otp_release)]), halt().' -noshell)"
echo "==> Erlang/OTP $otp_major"

# ---------------------------------------------------------------------------
# PostgreSQL: configure port and start
# ---------------------------------------------------------------------------
setup_postgres() {
  local pg_version
  pg_version="$(pg_lsclusters -h 2>/dev/null | awk '{print $1}' | head -1)"

  if [ -z "$pg_version" ]; then
    echo "ERROR: No PostgreSQL cluster found" >&2
    exit 1
  fi

  local pg_conf="/etc/postgresql/${pg_version}/main/postgresql.conf"

  # Set port to match dev/test config
  if grep -q "^port = ${PG_PORT}$" "$pg_conf" 2>/dev/null; then
    echo "==> PostgreSQL already on port $PG_PORT"
  else
    echo "==> Configuring PostgreSQL on port $PG_PORT..."
    sudo sed -i "s/^port = [0-9]*/port = ${PG_PORT}/" "$pg_conf"
  fi

  # Start if not running
  if pg_isready -p "$PG_PORT" -q 2>/dev/null; then
    echo "==> PostgreSQL already running"
  else
    echo "==> Starting PostgreSQL..."
    sudo pg_ctlcluster "$pg_version" main start
  fi

  # Set postgres password
  sudo -u postgres psql -p "$PG_PORT" -c "ALTER USER postgres PASSWORD 'postgres';" &>/dev/null
  echo "==> PostgreSQL ready (port $PG_PORT, user: postgres/postgres)"
}

setup_postgres

# ---------------------------------------------------------------------------
# Install Elixir from GitHub prebuilt releases
# ---------------------------------------------------------------------------
install_elixir() {
  local version="$1"
  local otp="$2"
  local install_dir="/usr/local/elixir"
  local zip_url="https://github.com/elixir-lang/elixir/releases/download/v${version}/elixir-otp-${otp}.zip"
  local tmp="/tmp/elixir-otp-${otp}.zip"

  echo "==> Downloading Elixir $version (prebuilt for OTP $otp)..."
  curl -sSL -o "$tmp" "$zip_url"
  sudo mkdir -p "$install_dir"
  sudo unzip -q -o "$tmp" -d "$install_dir"
  rm "$tmp"
  echo "==> Elixir installed to $install_dir"
}

if command -v elixir &>/dev/null; then
  installed="$(elixir --version 2>/dev/null | grep 'Elixir' | awk '{print $2}')"
  if [ "$installed" = "$elixir_version" ]; then
    echo "==> Elixir $elixir_version already installed, skipping"
  else
    install_elixir "$elixir_version" "$otp_major"
  fi
else
  install_elixir "$elixir_version" "$otp_major"
fi

# ---------------------------------------------------------------------------
# Configure persistent environment (for CLAUDE_ENV_FILE)
# ---------------------------------------------------------------------------
configure_env() {
  local key="$1"
  local line="$2"
  if ! grep -qF "$key" "$PERSISTENT_ENV" 2>/dev/null; then
    echo "$line" >> "$PERSISTENT_ENV"
  fi
}

configure_env '/usr/local/elixir/bin' 'export PATH="/usr/local/elixir/bin:$PATH"'
configure_env 'ELIXIR_ERL_OPTIONS'    'export ELIXIR_ERL_OPTIONS="+fnu"'
configure_env 'LANG='                 'export LANG=C.UTF-8'
# Separate _build so sandbox (different OTP) and local don't clobber each other
configure_env 'MIX_BUILD_PATH'        "export MIX_BUILD_PATH=\"/home/agent/.mix_build/${PROJECT_NAME}\""

export PATH="/usr/local/elixir/bin:$PATH"
export ELIXIR_ERL_OPTIONS="+fnu"
export LANG=C.UTF-8
export MIX_BUILD_PATH="/home/agent/.mix_build/${PROJECT_NAME}"

# ---------------------------------------------------------------------------
# Install hex + rebar
#
# builds.hex.pm may be blocked by firewalls in sandbox environments.
# Hex can be installed from GitHub as a fallback. Rebar3 is downloaded
# directly from its GitHub releases.
# ---------------------------------------------------------------------------
install_hex() {
  if mix archive | grep -q hex 2>/dev/null; then
    echo "==> Hex already installed, skipping"
    return
  fi

  echo "==> Installing hex..."
  if mix local.hex --force --if-missing 2>/dev/null; then
    return
  fi

  echo "==> builds.hex.pm unreachable, installing hex from GitHub..."
  mix archive.install github hexpm/hex branch latest --force
}

install_rebar() {
  if [ -f "$HOME/.mix/elixir/1-${elixir_version%%.*}-otp-${otp_major}/rebar3" ] 2>/dev/null; then
    echo "==> Rebar3 already installed, skipping"
    return
  fi

  echo "==> Installing rebar3..."
  if mix local.rebar --force --if-missing 2>/dev/null; then
    return
  fi

  echo "==> builds.hex.pm unreachable, installing rebar3 from GitHub..."
  curl -sSL -o /tmp/rebar3 "https://github.com/erlang/rebar3/releases/latest/download/rebar3"
  chmod +x /tmp/rebar3
  mix local.rebar rebar3 /tmp/rebar3 --force
  rm /tmp/rebar3
}

install_hex
install_rebar

# ---------------------------------------------------------------------------
# Fetch and compile project dependencies
# ---------------------------------------------------------------------------
echo "==> Fetching project dependencies..."
cd "$PROJECT_DIR"
mix deps.get

# Workaround: lazy_html NIF precompiled download fails when the sandbox proxy
# re-encrypts TLS (OTP's pubkey module can't decode the proxy CA cert).
# We download the precompiled NIF with curl (which handles the proxy fine)
# and place it in the elixir_make cache so `mix deps.compile` finds it.
prefetch_lazy_html_nif() {
  local lazy_html_version
  lazy_html_version="$(grep -oP '(?<=locked at )\S+' <(MIX_ENV=test mix deps | grep lazy_html) 2>/dev/null || true)"

  if [ -z "$lazy_html_version" ]; then
    return  # lazy_html not in deps
  fi

  local nif_abi
  nif_abi="$(erl -eval 'io:format("~s", [erlang:system_info(nif_version)]), halt().' -noshell)"
  local arch="aarch64-linux-gnu"
  local filename="lazy_html-nif-${nif_abi}-${arch}-${lazy_html_version}.tar.gz"
  local cache_dir="$HOME/.cache/elixir_make"
  local cache_file="${cache_dir}/${filename}"

  if [ -f "$cache_file" ] && [ "$(stat -c%s "$cache_file" 2>/dev/null || echo 0)" -gt 1000 ]; then
    echo "==> lazy_html NIF already cached, skipping"
    return
  fi

  local url="https://github.com/dashbitco/lazy_html/releases/download/v${lazy_html_version}/${filename}"
  echo "==> Pre-fetching lazy_html NIF (proxy workaround)..."
  mkdir -p "$cache_dir"
  if curl -sSL -L -o "$cache_file" "$url" && [ "$(stat -c%s "$cache_file" 2>/dev/null || echo 0)" -gt 1000 ]; then
    echo "==> Cached ${filename}"
  else
    echo "==> Warning: Could not download lazy_html NIF, will try source compilation"
    rm -f "$cache_file"
  fi
}

prefetch_lazy_html_nif

echo "==> Compiling dependencies..."
MIX_ENV=test mix deps.compile

# ---------------------------------------------------------------------------
# Create and migrate databases
# ---------------------------------------------------------------------------
echo "==> Setting up databases..."
MIX_ENV=test mix ecto.create --quiet 2>/dev/null || true
MIX_ENV=test mix ecto.migrate --quiet
MIX_ENV=dev mix ecto.create --quiet 2>/dev/null || true
MIX_ENV=dev mix ecto.migrate --quiet

# ---------------------------------------------------------------------------
# Playwright for E2E tests
# ---------------------------------------------------------------------------
setup_playwright() {
  local e2e_dir="$PROJECT_DIR/test/e2e"

  if [ ! -d "$e2e_dir" ]; then
    echo "==> No e2e directory found, skipping Playwright setup"
    return
  fi

  echo "==> Installing Playwright and Chromium..."
  cd "$e2e_dir"
  npm install --silent 2>/dev/null
  npx playwright install --with-deps chromium
  cd "$PROJECT_DIR"

  # Pre-compile e2e environment so first run doesn't need to
  echo "==> Compiling e2e environment..."
  MIX_ENV=e2e mix compile --quiet
}

setup_playwright

# ---------------------------------------------------------------------------
# Global CLAUDE.md for sandbox context
# ---------------------------------------------------------------------------
setup_claude_md() {
  local claude_md="$HOME/.claude/CLAUDE.md"

  if [ -f "$claude_md" ]; then
    echo "==> Global CLAUDE.md already exists, skipping"
    return
  fi

  mkdir -p "$HOME/.claude"
  cat > "$claude_md" << CLAUDE_EOF
# Docker microVM Sandbox

Du laeuft in einer Docker microVM Sandbox. Wichtige Hinweise:

- **PostgreSQL** ist als apt-Paket installiert (nicht Docker), Port 5433. Starten mit: \`sudo pg_ctlcluster <version> main start\`
- **Kein git push** — in der Sandbox nicht pushen, das macht der User bzw. autopush vom Host aus
- **Setup-Script**: \`scripts/sandbox-setup.sh\` installiert Erlang, Elixir, PostgreSQL, Playwright
- **Persistente Umgebung**: \`CLAUDE_ENV_FILE\` -> \`/etc/sandbox-persistent.sh\`
- **Separater _build**: \`MIX_BUILD_PATH="/home/agent/.mix_build/${PROJECT_NAME}"\` (OTP-Version kann sich von lokal unterscheiden)

## Context Management

Wenn dein Context zu voll wird, sende ein Signal an den Host:

    scripts/sandbox-signal.sh compact   # Context komprimieren
    scripts/sandbox-signal.sh clear     # Context leeren + Neustart


Ein Watcher auf dem Host fuehrt das Kommando dann automatisch fuer dich aus.
CLAUDE_EOF
  echo "==> Global CLAUDE.md created"
}

setup_claude_md

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=== Sandbox setup complete ==="
erl -eval 'io:format("Erlang/OTP ~s~n", [erlang:system_info(otp_release)]), halt().' -noshell
elixir --version
echo "PostgreSQL on port $PG_PORT"
echo ""
echo "Ready to go:"
echo "  mix test          # run tests"
echo "  mix phx.server    # start dev server"
echo "  scripts/e2e.sh    # run E2E tests"
