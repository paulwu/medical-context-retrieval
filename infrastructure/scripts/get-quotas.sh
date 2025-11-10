# Get Azure OpenAI model availability and quota usage across specified regions
#!/usr/bin/env bash
set -euo pipefail

# Regions and model names to evaluate
locations=( "westus3" "eastus2" "swedencentral" )
models=("gpt-5-mini" "text-embedding-3-large" )

# Helper to join array values for display
join_by() {
  local IFS="$1"
  shift || return 0
  echo "$*"
}

# Verify required dependencies are present
for dependency in az jq; do
  if ! command -v "$dependency" >/dev/null 2>&1; then
    echo "Error: '$dependency' is required but was not found in PATH." >&2
    exit 1
  fi
done

# Optional pretty table output
if command -v column >/dev/null 2>&1; then
  format_table() { column -t -s $'\t'; }
else
  format_table() { cat; }
fi

printf '=== Azure OpenAI Model Availability and Quota Report ===\n'
printf 'Locations: %s\n' "$(join_by ', ' "${locations[@]}")"
printf 'Models: %s\n\n' "$(join_by ', ' "${models[@]}")"

# Prepare JSON array strings for later use
if [ ${#locations[@]} -eq 0 ]; then
  locations_json="[]"
else
  locations_json=$(printf '"%s",' "${locations[@]}")
  locations_json="[${locations_json%,}]"
fi

if [ ${#models[@]} -eq 0 ]; then
  models_json="[]"
else
  models_json=$(printf '"%s",' "${models[@]}")
  models_json="[${models_json%,}]"
fi

# Temporary files to accumulate model and quota results
models_tmp=$(mktemp)
quotas_tmp=$(mktemp)
printf '[]' >"$models_tmp"
printf '[]' >"$quotas_tmp"

for location in "${locations[@]}"; do
  printf 'Processing location: %s\n' "$location"

  # === Model availability ===
  printf '  - Checking available models...\n'
  if models_raw=$(az cognitiveservices model list --location "$location" --only-show-errors --output json); then
    filtered_models=$(jq --arg region "$location" --argjson models "$models_json" '
      [ .[]
        | select(.kind == "OpenAI")
        | .model.name as $model_name
        | select($models | index($model_name) != null)
        | {
            Region: $region,
            Name: $model_name,
            MaxCapacity: (if .model.maxCapacity == null then "N/A" else .model.maxCapacity end),
            LifecycleStatus: (if .model.lifecycleStatus == null then "Unknown" else .model.lifecycleStatus end),
            SKU: (if (.model.skus | type) == "array" and (.model.skus | length) > 0 then .model.skus[0].name else "N/A" end)
          }
      ]
    ' <<<"$models_raw")

    count_models=$(jq 'length' <<<"$filtered_models")
    if [ "$count_models" -eq 0 ]; then
      printf '    No matching models found in %s.\n' "$location"
    else
      printf '    Found %s matching model(s).\n' "$count_models"
    fi

    tmp_file=$(mktemp)
    jq --argjson new "$filtered_models" '. + $new' "$models_tmp" >"$tmp_file"
    mv "$tmp_file" "$models_tmp"
  else
    printf '    Error retrieving models for %s.\n' "$location" >&2
  fi

  # === Quota usage ===
  printf '  - Checking quota usage...\n'
  if quotas_raw=$(az cognitiveservices usage list -l "$location" --only-show-errors --output json); then
    filtered_quotas=$(jq --arg region "$location" --argjson models "$models_json" '
      def models_lower: [$models[] | ascii_downcase];
      def val_or_na($v): if $v == null then "N/A" else ($v | tostring) end;

      [ .[]
        | select(.name.value != null)
        | . as $item
        | ($item.name.value | ascii_downcase) as $lower
        | select(models_lower | any(. == $lower or ($lower | contains(.))))
        | {
            Location: $region,
            Name: $item.name.value,
            Limit: val_or_na($item.limit),
            Current: val_or_na($item.currentValue),
            Available: (if ($item.limit != null and $item.currentValue != null) then ($item.limit - $item.currentValue | tostring) else "N/A" end)
          }
      ]
    ' <<<"$quotas_raw")

    count_quotas=$(jq 'length' <<<"$filtered_quotas")
    if [ "$count_quotas" -eq 0 ]; then
      printf '    No quota entries found in %s.\n' "$location"
    else
      printf '    Found %s quota entry(ies).\n' "$count_quotas"
    fi

    tmp_file=$(mktemp)
    jq --argjson new "$filtered_quotas" '. + $new' "$quotas_tmp" >"$tmp_file"
    mv "$tmp_file" "$quotas_tmp"
  else
    printf '    Error retrieving quotas for %s.\n' "$location" >&2
  fi

  printf '\n'
done

models_count=$(jq 'length' "$models_tmp")
quota_count=$(jq 'length' "$quotas_tmp")

printf '=== AVAILABLE MODELS ===\n'
if [ "$models_count" -gt 0 ]; then
  jq -r '.[] | [.Region, .Name, (.MaxCapacity | tostring), .LifecycleStatus, .SKU] | @tsv' "$models_tmp" | format_table
else
  printf 'No matching models found in any location.\n'
fi

printf '\n=== QUOTA USAGE ===\n'
if [ "$quota_count" -gt 0 ]; then
  jq -r '.[] | [.Location, .Name, (.Limit | tostring), (.Current | tostring), (.Available | tostring)] | @tsv' "$quotas_tmp" | format_table
else
  printf 'No quota information found for matching models.\n'
fi

# Export results to CSV (if data exists)
if [ "$models_count" -gt 0 ]; then
  models_file="openai_models_availability.csv"
  jq -r '(["Region","Name","MaxCapacity","LifecycleStatus","SKU"], (.[] | [ .Region, .Name, (.MaxCapacity | tostring), .LifecycleStatus, .SKU ])) | @csv' "$models_tmp" >"$models_file"
  printf '\nModels exported to: %s\n' "$models_file"
fi

if [ "$quota_count" -gt 0 ]; then
  quotas_file="openai_quotas_usage.csv"
  jq -r '(["Location","Name","Limit","Current","Available"], (.[] | [ .Location, .Name, (.Limit | tostring), (.Current | tostring), (.Available | tostring) ])) | @csv' "$quotas_tmp" >"$quotas_file"
  printf 'Quotas exported to: %s\n' "$quotas_file"
fi

# Export combined JSON summary
summary_file="openai_availability_quotas_report.json"
timestamp=$(date '+%Y-%m-%d %H:%M:%S')
available_json=$(cat "$models_tmp")
quota_json=$(cat "$quotas_tmp")

jq -n \
  --arg generated "$timestamp" \
  --argjson locations "$locations_json" \
  --argjson models "$models_json" \
  --argjson available "$available_json" \
  --argjson quotas "$quota_json" \
  '{
     GeneratedAt: $generated,
     Locations: $locations,
     Models: $models,
     AvailableModels: $available,
     QuotaUsage: $quotas,
     Summary: {
       TotalModelsFound: ($available | length),
       TotalQuotaEntries: ($quotas | length),
       LocationsProcessed: ($locations | length)
     }
   }' >"$summary_file"

printf 'Combined report exported to: %s\n\n' "$summary_file"

printf '=== SUMMARY ===\n'
printf 'Locations processed: %d\n' "${#locations[@]}"
printf 'Models searched: %d\n' "${#models[@]}"
printf 'Available models found: %d\n' "$models_count"
printf 'Quota entries found: %d\n' "$quota_count"

# Clean up temporary files
rm -f "$models_tmp" "$quotas_tmp"
