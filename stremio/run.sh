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

if [ -n "$DEBUG_ENABLED" ] && [ "$DEBUG_ENABLED" = "1" ]; then
    # Enable verbose logging for Stremio
    export DEBUG="*"
    export NODE_DEBUG="net,http,http2,tls"
fi

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

# Add stremio group bypass rules BEFORE Gluetun's DROP rules
# These rules match on group ownership and bypass VPN

# # Create stremio group (GID 3000)
# addgroup -g 3000 stremio 2>/dev/null || true

# # Allow ALL traffic for stremio group (both INPUT and OUTPUT)
# iptables -I OUTPUT 1 -m owner --gid-owner 3000 -j ACCEPT 2>/dev/null || true
# iptables -I INPUT 1 -j ACCEPT 2>/dev/null || true  # Input doesn't have owner match

# # Allow forwarding for stremio group
# iptables -I FORWARD 1 -m owner --gid-owner 3000 -j ACCEPT 2>/dev/null || true
# # iptables -I FORWARD 1 -j ACCEPT 2>/dev/null || true

# echo "  ✓ Firewall bypass rules applied"
# echo "  → Stremio processes will bypass VPN firewall completely"

# # Start Stremio withe stremio group (./stremio-web-service-run.sh)
# exec sg stremio "./stremio-web-service-run.sh"  

exec ./stremio-web-service-run.sh

# Create cgroup
# mkdir -p /sys/fs/cgroup/net_cls/stremio
# echo 3000 > /sys/fs/cgroup/net_cls/stremio/net_cls.classid

# # Run process under cgroup (e.g., stremio)
# # Then use iptables with cgroup match (if module is loaded)
# iptables -I OUTPUT -m cgroup --cgroup 3000 -j ACCEPT
# iptables -I INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
# iptables -I FORWARD -m cgroup --cgroup 3000 -j ACCEPT

# exec sh -c "echo $$ > /sys/fs/cgroup/net_cls/stremio/cgroup.procs && sg stremio ./stremio-web-service-run.sh"