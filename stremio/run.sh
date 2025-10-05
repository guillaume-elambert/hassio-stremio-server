#!/bin/bash
set -e

CONFIG_PATH=/data/options.json
LOCAL_STORAGE_PATH=./localStorage.json
EXCLUDE_OPTIONS=("localStorage" "device")

# Function to check if element is in array
in_array() {
    local e
    for e in "${@:2}"; do [[ "$e" == "$1" ]] && return 0; done
    return 1
}

for opt in $(jq -r 'keys[]' "$CONFIG_PATH"); do
    # Skip empty options
    [[ -z "$opt" ]] && continue

    # Skip excluded options
    if in_array "$opt" "${EXCLUDE_OPTIONS[@]}"; then
        continue
    fi

    value=$(jq -r --arg key "$opt" '.[$key] | if type == "boolean" then (if . == true then 1 else 0 end) else . end' "$CONFIG_PATH")
    if [[ -n "$value" && "$value" != "null" ]]; then
        # Escape double quotes in value
        safe_value="${value//\"/\\\"}"
        export "${opt^^}"="$safe_value"
        echo "Exported ${opt^^}=$safe_value"
    fi
done

# Handle localStorage option
LOCAL_STORAGE=$(jq -r '.localStorage // empty' "$CONFIG_PATH")
if [[ -n "$LOCAL_STORAGE" ]]; then
    echo "$LOCAL_STORAGE" > "$LOCAL_STORAGE_PATH"
    echo "Wrote localStorage to $LOCAL_STORAGE_PATH"
fi

ls -la /dev/dri

exec ./stremio-web-service-run.sh