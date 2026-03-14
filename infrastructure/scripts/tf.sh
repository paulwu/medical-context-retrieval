#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# tf.sh — Terraform wrapper that auto-injects ARM_* environment variables
# ═══════════════════════════════════════════════════════════════════════════
#
# Usage:
#   bash scripts/tf.sh plan          # terraform plan with env var-files
#   bash scripts/tf.sh apply         # terraform apply with env var-files
#   bash scripts/tf.sh init          # terraform init with backend config
#   bash scripts/tf.sh <any command> # passes through with var-files appended
#
# Reads .current-env to determine the active environment, then automatically
# adds -var-file and -backend-config flags. No long commands to type.
#
# For single-environment usage (no environments.json), set ARM_SUBSCRIPTION_ID
# directly or use: bash scripts/tf.sh plan (falls back to az account show).
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
INFRA_DIR="$REPO_ROOT/infrastructure"
ENV_FILE="$REPO_ROOT/.current-env"
ENV_JSON="$REPO_ROOT/environments/environments.json"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

die() { echo -e "${RED}ERROR: $1${NC}" >&2; exit 1; }

# ── Resolve environment ──────────────────────────────────────────────────

TFVARS_ARGS=""
BACKEND_ARGS=""

if [[ -f "$ENV_JSON" ]] && [[ -f "$ENV_FILE" ]]; then
  # Multi-environment mode (env-select.sh was used)
  command -v jq &>/dev/null || die "jq is required. Install with: apt install jq"

  CURRENT_ENV=$(cat "$ENV_FILE")
  [[ -z "$CURRENT_ENV" ]] && die "Empty .current-env file. Run: bash scripts/env-select.sh"

  TFVARS=$(jq -r ".environments[\"$CURRENT_ENV\"].tfvars // empty" "$ENV_JSON")
  BACKEND=$(jq -r ".environments[\"$CURRENT_ENV\"].backend // empty" "$ENV_JSON")
  ALIAS=$(jq -r ".environments[\"$CURRENT_ENV\"].alias // empty" "$ENV_JSON")

  [[ -z "$TFVARS" ]] && die "Environment '$CURRENT_ENV' not found in environments.json"

  SUB_ID=$(grep '^\s*subscription_id' "$REPO_ROOT/$TFVARS" 2>/dev/null | awk -F'"' '{print $2}' | head -1)

  if [[ -n "$SUB_ID" ]]; then
    export ARM_SUBSCRIPTION_ID="$SUB_ID"
  fi

  TFVARS_ARGS="-var-file=$REPO_ROOT/$TFVARS"
  [[ -n "$BACKEND" ]] && BACKEND_ARGS="-backend-config=$REPO_ROOT/$BACKEND"

  echo -e "📍 ${BOLD}${GREEN}${CURRENT_ENV}${NC} (${YELLOW}${ALIAS:-no-alias}${NC}) | sub: ...${SUB_ID:(-4)}"
  echo ""

elif [[ -z "${ARM_SUBSCRIPTION_ID:-}" ]]; then
  # Fallback: get subscription from az CLI
  if command -v az &>/dev/null; then
    SUB_ID=$(az account show --query id -o tsv 2>/dev/null || true)
    if [[ -n "$SUB_ID" ]]; then
      export ARM_SUBSCRIPTION_ID="$SUB_ID"
      echo -e "📍 Using active Azure CLI subscription: ...${SUB_ID:(-4)}"
      echo ""
    fi
  fi
fi

cd "$INFRA_DIR"

TF_CMD="${1:-}"
shift || true

case "$TF_CMD" in
  init)
    if [[ -n "$BACKEND_ARGS" ]]; then
      terraform init $BACKEND_ARGS "$@"
    else
      echo -e "${YELLOW}No backend config — initializing with local state only${NC}"
      terraform init -backend=false "$@"
    fi
    ;;
  plan|apply|destroy|import|refresh)
    terraform "$TF_CMD" $TFVARS_ARGS "$@"
    ;;
  validate|fmt|"state"|console|output|show|graph|providers|force-unlock)
    terraform "$TF_CMD" "$@"
    ;;
  "")
    die "Usage: tf.sh <command> [args...]\n  Example: tf.sh plan\n           tf.sh apply -target=module.ai_search"
    ;;
  *)
    terraform "$TF_CMD" $TFVARS_ARGS "$@"
    ;;
esac
