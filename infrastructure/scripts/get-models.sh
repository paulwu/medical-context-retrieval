# Get models available in specified regions
#!/usr/bin/env bash
set -euo pipefail

# Regions and model names to query, mirroring the PowerShell script
locations=( "westus3" "eastus2" "swedencentral" )
models=("gpt-5-mini" "text-embedding-3-large" )

# Ensure required dependencies are available before running
for dependency in az jq; do
  if ! command -v "$dependency" >/dev/null 2>&1; then
    echo "Error: '$dependency' is required but was not found in PATH." >&2
    exit 1
  fi
done

# Column formatting is optional; fall back to raw output if it is missing
if command -v column >/dev/null 2>&1; then
  format_with_column() { column -t -s $'\t'; }
else
  format_with_column() { cat; }
fi

# Build a JSON array of model names for jq filtering
models_json=$(printf '"%s",' "${models[@]}")
models_json="[${models_json%,}]"

# jq program mirrors the PowerShell Select-Object projection
jq_program='.[] |
  select(.kind == "OpenAI") |
  .model.name as $model_name |
  select($models | index($model_name) != null) |
  [$region,
   $model_name,
  (.model.version // "N/A"),
  (.model.raiPolicyName // "N/A"),
   (.model.maxCapacity // "N/A"),
   (.model.lifecycleStatus // "Unknown"),
   (if (.model.skus | type) == "array" and (.model.skus | length) > 0 then .model.skus[0].name else "N/A" end)
  ] |
  @tsv'

results=()

for location in "${locations[@]}"; do
  if ! mapfile -t location_results < <(
    az cognitiveservices model list --location "$location" --only-show-errors --output json |
    jq -r --arg region "$location" --argjson models "$models_json" "$jq_program"
  ); then
    echo "Warning: failed to query models for location '$location'." >&2
    continue
  fi

  if (( ${#location_results[@]} )); then
    results+=("${location_results[@]}")
  else
    echo "Info: no matching models found in $location." >&2
  fi
done

if (( ${#results[@]} )); then
  {
    printf "Region\tName\tVersion\tRAIPolicy\tMaxCapacity\tLifecycleStatus\tSKU\n"
    printf '%s\n' "${results[@]}"
  } | format_with_column
else
  echo "No matching models found for the provided regions." >&2
  exit 1
fi