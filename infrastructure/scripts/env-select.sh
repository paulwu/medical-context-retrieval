#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# env-select.sh — Select, display, or switch the active Terraform environment
# ═══════════════════════════════════════════════════════════════════════════
#
# Usage:
#   bash scripts/env-select.sh              # Interactive picker
#   bash scripts/env-select.sh dev          # Select by alias or name
#   bash scripts/env-select.sh --current    # Show current environment
#   bash scripts/env-select.sh --list       # List available environments
#
# The selected environment is persisted in .current-env (git-ignored).
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ENV_FILE="$REPO_ROOT/.current-env"
ENV_JSON="$REPO_ROOT/environments/environments.json"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

die() { echo -e "${RED}ERROR: $1${NC}" >&2; exit 1; }

require_jq() {
  command -v jq &>/dev/null || die "jq is required. Install with: apt install jq"
}

get_current_env() {
  if [[ -f "$ENV_FILE" ]]; then
    cat "$ENV_FILE"
  else
    echo ""
  fi
}

resolve_env() {
  local input="$1"
  require_jq

  # Try exact name match first
  if jq -e ".environments[\"$input\"]" "$ENV_JSON" &>/dev/null; then
    echo "$input"
    return
  fi

  # Try alias match
  local match
  match=$(jq -r ".environments | to_entries[] | select(.value.alias == \"$input\") | .key" "$ENV_JSON" 2>/dev/null)
  if [[ -n "$match" ]]; then
    echo "$match"
    return
  fi

  die "Environment '$input' not found. Use --list to see available environments."
}

get_env_field() {
  local env_name="$1" field="$2"
  jq -r ".environments[\"$env_name\"].$field // empty" "$ENV_JSON"
}

# ── Commands ─────────────────────────────────────────────────────────────

cmd_list() {
  require_jq
  echo -e "${BOLD}Available environments:${NC}"
  echo ""

  local current
  current=$(get_current_env)

  jq -r '.environments | to_entries[] | "\(.key)|\(.value.alias // "")|\(.value.description // "")"' "$ENV_JSON" | \
  while IFS='|' read -r name alias desc; do
    local marker="  "
    if [[ "$name" == "$current" ]]; then
      marker="▸ "
      echo -e "${marker}${GREEN}${BOLD}${name}${NC} (${YELLOW}${alias}${NC}) — ${desc}"
    else
      echo -e "${marker}${name} (${YELLOW}${alias}${NC}) — ${desc}"
    fi
  done
}

cmd_current() {
  local current
  current=$(get_current_env)

  if [[ -z "$current" ]]; then
    echo -e "${YELLOW}No environment selected.${NC} Run: bash scripts/env-select.sh"
    return 1
  fi

  require_jq
  local alias desc
  alias=$(get_env_field "$current" "alias")
  desc=$(get_env_field "$current" "description")

  echo -e "📍 ${BOLD}${GREEN}${current}${NC} (${YELLOW}${alias}${NC}) — ${desc}"
}

cmd_select() {
  local target="$1"
  require_jq

  local resolved
  resolved=$(resolve_env "$target")

  echo "$resolved" > "$ENV_FILE"

  local alias desc
  alias=$(get_env_field "$resolved" "alias")
  desc=$(get_env_field "$resolved" "description")

  echo -e "✅ Switched to: ${BOLD}${GREEN}${resolved}${NC} (${YELLOW}${alias}${NC}) — ${desc}"
}

cmd_interactive() {
  require_jq

  echo -e "${BOLD}Select an environment:${NC}"
  echo ""

  local names=()
  while IFS= read -r name; do
    names+=("$name")
  done < <(jq -r '.environments | keys[]' "$ENV_JSON")

  local i=1
  for name in "${names[@]}"; do
    local alias desc
    alias=$(get_env_field "$name" "alias")
    desc=$(get_env_field "$name" "description")
    echo -e "  ${CYAN}${i})${NC} ${name} (${YELLOW}${alias}${NC}) — ${desc}"
    ((i++))
  done

  echo ""
  read -rp "Enter number: " choice

  if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#names[@]} )); then
    cmd_select "${names[$((choice-1))]}"
  else
    die "Invalid selection."
  fi
}

# ── Main ─────────────────────────────────────────────────────────────────

if [[ ! -f "$ENV_JSON" ]]; then
  die "environments/environments.json not found. Create it first.\n  See environments/environments.json.example for format."
fi

case "${1:-}" in
  --current|-c)
    cmd_current
    ;;
  --list|-l)
    cmd_list
    ;;
  "")
    cmd_interactive
    ;;
  -*)
    die "Unknown option: $1\nUsage: env-select.sh [--current|--list|<name-or-alias>]"
    ;;
  *)
    cmd_select "$1"
    ;;
esac
