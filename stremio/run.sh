#!/bin/bash
set -e

CONFIG_PATH=${CONFIG_PATH:-"/data/options.json"}
LOCAL_STORAGE_PATH=${LOCAL_STORAGE_PATH:-"./local_storage.json"}
EXCLUDE_OPTIONS=("local_storage" "local_network" "^vpn_.*$")

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

    # Skip excluded options (VPN and local_storage handled separately)
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

if [ -n "$DEBUG_ENABLED" ] && [ "$DEBUG_ENABLED" = "1" ]; then
    # Enable verbose logging for Stremio
    export DEBUG="*"
    export NODE_DEBUG="net,http,http2,tls"
fi

# Handle local_storage option
LOCAL_STORAGE=$(jq -r '.local_storage // empty' "$CONFIG_PATH")
if [[ -n "$LOCAL_STORAGE" ]]; then
    echo "$LOCAL_STORAGE" >"$LOCAL_STORAGE_PATH"
    echo "  ✓ localStorage configuration saved"
fi

echo ""
echo "=================================="
echo "Starting Stremio Server"
echo "=================================="

exec ./stremio-web-service-run.sh