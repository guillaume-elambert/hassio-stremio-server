#!/bin/bash
set -e

CONFIG_PATH=${CONFIG_PATH:-"/data/options.json"}
LOCAL_STORAGE_PATH=${LOCAL_STORAGE_PATH:-"./localStorage.json"}
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

if [ "$WEB_UI_PROTOCOL" == "http" ]; then
    unset IPADDRESS
    unset CERT_FILE
    unset KEY_FILE
else
    if [ -z "$CERT_FILE" ] || [ -z "$KEY_FILE" ] || [ ! -f "/ssl/$CERT_FILE" ] || [ ! -f "/ssl/$KEY_FILE" ]; then
        export IPADDRESS=0.0.0.0
        unset CERT_FILE
        unset KEY_FILE
    else
        unset IPADDRESS
        CONFIG_FOLDER="${APP_PATH:-${HOME}/.stremio-server/}"
        cat /ssl/$CERT_FILE /ssl/$KEY_FILE > $CONFIG_FOLDER/$CERT_FILE
    fi
fi

# Auto redirect to correct protocol
sed -i '/server {/a \    error_page 497 =301 http://$host:$server_port$request_uri;' /etc/nginx/http.d/default.conf
sed -i '/server {/a \    error_page 497 =301 https://$host:$server_port$request_uri;' /etc/nginx/https.conf

# Setup VPN, it returns 1 if VPN setup fails, make sure it doesn't stop the script
./vpn-setup.sh || true

echo ""
echo "=================================="
echo "Loading Stremio Configuration"
echo "=================================="

if [ -n "$DEBUG_ENABLED" ] && [ "$DEBUG_ENABLED" = "1" ]; then
    # Enable verbose logging for Stremio
    export DEBUG="*"
    #export NODE_DEBUG="net,http,http2,tls"
else
    # Disable access logs
    sed -i 's/access_log \/dev\/stdout;/access_log off;/' /etc/nginx/http.d/default.conf
    sed -i 's/access_log \/dev\/stdout;/access_log off;/' /etc/nginx/https.conf
    
    unset DEBUG
    unset NODE_DEBUG
fi

# Handle local_storage option
LOCAL_STORAGE=$(jq -r '.local_storage // empty' "$CONFIG_PATH")
if [[ -n "$LOCAL_STORAGE" ]]; then
    echo "$LOCAL_STORAGE" >"$LOCAL_STORAGE_PATH"
    echo "  ✓ localStorage configuration saved to $(realpath $LOCAL_STORAGE_PATH)"
fi

# Make container use /config/.stremio-server/ for /root/.stremio-server/ config folder
VOLUME_CONFIG_DIR="/config/.stremio-server/"
SERVER_CONFIG_DIR="/root/.stremio-server/"

mkdir -p "$VOLUME_CONFIG_DIR"
rm -rf "$SERVER_CONFIG_DIR"

ln -sf "$VOLUME_CONFIG_DIR" "/root/"

if [ -n "$AUTO_TRANSCODING_PROFILE" ] && [ "$AUTO_TRANSCODING_PROFILE" == "1" ]; then
    ( ./setup-server-settings.sh "auto_transcoding" & )
fi

# Make sure current user has acess to /dev/dri devices
for dev in /dev/dri/*; do
    [ -e "$dev" ] || continue
    gid=$(stat -c %g "$dev")
    group_name=$(getent group "$gid" | cut -d: -f1)
    if [ -z "$group_name" ]; then
        group_name="dri_$gid"
        addgroup -g "$gid" -S "$group_name" 2>/dev/null || true
    fi
    adduser "$(whoami)" "$group_name" 2>/dev/null || true
done

echo ""
echo "=================================="
echo "Starting Stremio Server"
echo "=================================="

exec ./stremio-web-service-run.sh