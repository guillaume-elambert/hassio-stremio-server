#!/bin/bash
set -e

CONFIG_PATH=${CONFIG_PATH:-"/data/options.json"}
LOCAL_STORAGE_PATH=${LOCAL_STORAGE_PATH:-"./localStorage.json"}
EXCLUDE_OPTIONS=("localStorage" "local_network" "^vpn_.*$")

# Function to check if element is in array
in_array() {
    local e
    for e in "${@:2}"; do
        [[ "$1" == "$e" ]] && return 0
        [[ "$1" =~ $e ]] && return 0
    done
    return 1
}

# Export configuration options as environment variables (Stremio config only)
for opt in $(jq -r 'keys[]' "$CONFIG_PATH"); do
    # Skip empty options
    [[ -z "$opt" ]] && continue

    # Skip excluded options (VPN and localStorage handled separately)
    if in_array "$opt" "${EXCLUDE_OPTIONS[@]}"; then
        continue
    fi

    value=$(jq -r --arg key "$opt" '.[$key] | if type == "boolean" then (if . == true then 1 else 0 end) else . end' "$CONFIG_PATH")
    if [[ -n "$value" && "$value" != "null" ]]; then
        # Escape double quotes in value
        safe_value="${value//\"/\\\"}"
        export "${opt^^}"="$safe_value"
    fi
done

# Setup VPN, it returns 1 if VPN setup fails, make sure it doesn't stop the script
./vpn-setup.sh || true

echo ""
echo "=================================="
echo "Loading Stremio Configuration"
echo "=================================="

# Handle localStorage option
LOCAL_STORAGE=$(jq -r '.localStorage // empty' "$CONFIG_PATH")
if [[ -n "$LOCAL_STORAGE" ]]; then
    echo "$LOCAL_STORAGE" >"$LOCAL_STORAGE_PATH"
    echo "  ✓ localStorage configuration saved"
fi

echo ""
echo "=================================="
echo "Starting Stremio Server"
echo "=================================="

# Start Stremio
exec ./stremio-web-service-run.sh
