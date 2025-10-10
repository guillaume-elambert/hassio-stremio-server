#!/bin/bash
set -e

CONFIG_PATH=${CONFIG_PATH:-"/data/options.json"}

JQ_VPN_CONFIG=$(jq 'to_entries | map(select(.key | startswith("vpn_"))) | from_entries' "$CONFIG_PATH")

# Export configuration options as environment variables (VPN config only)
for opt in $(jq -r 'keys[]' <<<"$JQ_VPN_CONFIG"); do
    # Skip empty options
    [[ -z "$opt" ]] && continue

    value=$(jq -r --arg key "$opt" '.[$key] | if type == "boolean" then (if . == true then 1 else 0 end) else . end' <<<"$JQ_VPN_CONFIG")
    if [[ -n "$value" && "$value" != "null" ]]; then
        # Escape double quotes in value
        safe_value="${value//\"/\\\"}"
        export "${opt^^}"="$safe_value"
    fi
done

echo ""
echo "=================================="
echo "VPN Setup"
echo "=================================="

# Check if VPN is enabled (exported 0 or 1) from options
VPN_ENABLED=${VPN_ENABLED:-0}

if [ "$VPN_ENABLED" = "0" ]; then
    echo "ℹ  VPN is disabled"
    exit 0
fi

echo "✓ VPN is enabled, configuring Gluetun..."

# Get Home Assistant network info
HOST_NETWORK_INFO=$(curl -sSL -H "Authorization: Bearer $SUPERVISOR_TOKEN" http://supervisor/network/info)

if [ -n "$HOST_NETWORK_INFO" ] && jq . >/dev/null <<<"$HOST_NETWORK_INFO" 2>&1; then
    # Extract local networks
    LOCAL_NETWORKS=""

    # Get docker network
    DOCKER_NETWORK=$(jq -r '.data.docker.address // ""' <<<"$HOST_NETWORK_INFO")
    if [ -n "$DOCKER_NETWORK" ] && [ "$DOCKER_NETWORK" != "null" ]; then
        LOCAL_NETWORKS="$DOCKER_NETWORK"
    fi

    # Get all interface networks
    readarray -t IPS < <(jq -c '.data.interfaces[]?.ipv4?.address[]? // empty' <<<"$HOST_NETWORK_INFO")

    for IP in "${IPS[@]}"; do
        if [ -n "$IP" ] && [ "$IP" != "null" ]; then
            # Remove quotes if present
            IP=$(tr -d '"' <<<"$IP")

            # Calculate network CIDR
            NETWORK=$(ipcalc -n "$IP" 2>/dev/null | cut -d= -f2)
            PREFIX=$(ipcalc -p "$IP" 2>/dev/null | cut -d= -f2)

            if [ -z "$NETWORK" ] || [ -z "$PREFIX" ]; then
                continue
            fi

            CIDR="$NETWORK/$PREFIX"
            if [ -z "$LOCAL_NETWORKS" ]; then
                LOCAL_NETWORKS="$CIDR"
            elif ! grep -q "$CIDR" <<<"$LOCAL_NETWORKS"; then
                # Check if CIDR already exists in LOCAL_NETWORKS
                LOCAL_NETWORKS="$LOCAL_NETWORKS,$CIDR"
            fi
        fi
    done

    #export FIREWALL_VPN_INPUT_PORTS="8080"
    export FIREWALL_OUTBOUND_SUBNETS="$LOCAL_NETWORKS"
    export FIREWALL="on"
    export FIREWALL_DEBUG="on"

    echo "  Local networks: $LOCAL_NETWORKS"
fi

# Get VPN configuration from options
VPN_SERVICE_PROVIDER=$(jq -r '.vpn_service_provider // "custom"' "$CONFIG_PATH")
VPN_TYPE=$(jq -r '.vpn_type // "openvpn"' "$CONFIG_PATH")

export VPN_SERVICE_PROVIDER
export VPN_TYPE

if [ "$VPN_SERVICE_PROVIDER" != "custom" ]; then
    # Using a known provider
    # VPN_USERNAME=$(jq -r '.vpn_username // ""' "$CONFIG_PATH")
    # VPN_PASSWORD=$(jq -r '.vpn_password // ""' "$CONFIG_PATH")
    # VPN_SERVER_COUNTRIES=$(jq -r '.vpn_server_countries // ""' "$CONFIG_PATH")
    # VPN_SERVER_REGIONS=$(jq -r '.vpn_server_regions // ""' "$CONFIG_PATH")
    # VPN_SERVER_CITIES=$(jq -r '.vpn_server_cities // ""' "$CONFIG_PATH")
    # VPN_SERVER_HOSTNAMES=$(jq -r '.vpn_server_hostnames // ""' "$CONFIG_PATH")

    # Export based on VPN type
    if [ "$VPN_TYPE" = "wireguard" ]; then
        [ -n "$VPN_USERNAME" ] && export WIREGUARD_PRIVATE_KEY="$VPN_USERNAME"
        [ -n "$VPN_PASSWORD" ] && export WIREGUARD_PRESHARED_KEY="$VPN_PASSWORD"
        [ -n "$VPN_SERVER_COUNTRIES" ] && export SERVER_COUNTRIES="$VPN_SERVER_COUNTRIES"
        [ -n "$VPN_SERVER_REGIONS" ] && export SERVER_REGIONS="$VPN_SERVER_REGIONS"
        [ -n "$VPN_SERVER_CITIES" ] && export SERVER_CITIES="$VPN_SERVER_CITIES"
        [ -n "$VPN_SERVER_HOSTNAMES" ] && export SERVER_HOSTNAMES="$VPN_SERVER_HOSTNAMES"
    else
        # OpenVPN
        [ -n "$VPN_USERNAME" ] && export OPENVPN_USER="$VPN_USERNAME"
        [ -n "$VPN_PASSWORD" ] && export OPENVPN_PASSWORD="$VPN_PASSWORD"
        [ -n "$VPN_SERVER_COUNTRIES" ] && export SERVER_COUNTRIES="$VPN_SERVER_COUNTRIES"
        [ -n "$VPN_SERVER_REGIONS" ] && export SERVER_REGIONS="$VPN_SERVER_REGIONS"
        [ -n "$VPN_SERVER_CITIES" ] && export SERVER_CITIES="$VPN_SERVER_CITIES"
        [ -n "$VPN_SERVER_HOSTNAMES" ] && export SERVER_HOSTNAMES="$VPN_SERVER_HOSTNAMES"
    fi

    echo "  Provider: $VPN_SERVICE_PROVIDER"
    echo "  Type: $VPN_TYPE"
    [ -n "$VPN_SERVER_COUNTRIES" ] && echo "  Countries: $VPN_SERVER_COUNTRIES"
    [ -n "$VPN_SERVER_REGIONS" ] && echo "  Regions: $VPN_SERVER_REGIONS"
else
    # Using custom VPN config
    VPN_CONFIG_DIR="/config/vpn"
    # VPN_CONFIG_FILENAME=$(jq -r '.vpn_config_filename // ""' "$CONFIG_PATH")

    if [ "$VPN_TYPE" = "wireguard" ]; then
        POSSIBLE_FILES=("$VPN_CONFIG_FILENAME" "wg0.conf" "wireguard.conf" "vpn.conf")
    else
        POSSIBLE_FILES=("$VPN_CONFIG_FILENAME" "vpn.ovpn" "vpn.conf")
    fi

    for FILE in "${POSSIBLE_FILES[@]}"; do
        if [ -z "$FILE" ] || [ "$FILE" == "null" ] || [ ! -f "$VPN_CONFIG_DIR/$FILE" ]; then
            continue
        fi

        if [ "$VPN_TYPE" = "wireguard" ]; then
            export WIREGUARD_CONF_FILE="/config/vpn/$FILE"
            echo "  Using custom WireGuard config: $FILE"
            break
        fi

        export OPENVPN_CUSTOM_CONFIG="/config/vpn/$FILE"

        # Check for auth file
        if [ -f "$VPN_CONFIG_DIR/auth.txt" ]; then
            export OPENVPN_USER=$(head -n 1 "$VPN_CONFIG_DIR/auth.txt")
            export OPENVPN_PASSWORD=$(tail -n 1 "$VPN_CONFIG_DIR/auth.txt")
            echo "  Using auth.txt for credentials"
        fi

        echo "  Using custom OpenVPN config: $FILE"
        break
    done

    if [ "$VPN_TYPE" = "wireguard" ] && [ -z "$WIREGUARD_CONF_FILE" ]; then
        echo "  ⚠ No WireGuard config found, continuing without VPN"
        VPN_ENABLED=0
    elif [ "$VPN_TYPE" = "openvpn" ] && [ -z "$OPENVPN_CUSTOM_CONFIG" ]; then
        echo "  ⚠ No OpenVPN config found, continuing without VPN"
        VPN_ENABLED=0
    fi
fi

if [ "$VPN_ENABLED" = "0" ]; then
    echo "ℹ  VPN is disabled"
    exit 0
fi

# Disable pprof to prevent nil pointer dereference
export PPROF_ENABLED=no
# export PPROF_HTTP_SERVER_ADDRESS=":0"
unset PPROF_HTTP_SERVER_ADDRESS

# Disable HTTP control server and proxies
export HTTPPROXY=off
export SHADOWSOCKS=off
# export HTTP_CONTROL_SERVER_ADDRESS=":0"
export HTTP_CONTROL_SERVER_ADDRESS=""

# DNS settings
export DOT=off
export DNS_KEEP_NAMESERVER=on
export DNS_ADDRESS=127.0.0.1

# Health check settings
export HEALTH_VPN_DURATION_INITIAL=30s
export HEALTH_VPN_DURATION_ADDITION=10s
export HEALTH_SUCCESS_WAIT_DURATION=5s

# Logging
export LOG_LEVEL=debug
export LOG_TO_STDOUT=on
export GOTRACEBACK=all

# Updater settings - disable to prevent issues
export UPDATER_PERIOD=0

# Version information
export VERSION_INFORMATION=on

env

# Start Gluetun in background
echo "→ Starting Gluetun VPN..."
/gluetun-entrypoint 2>&1 | tee /tmp/gluetun.log &
GLUETUN_PID=$!

# Give it a moment to initialize
sleep 5

# Wait for VPN to connect
echo -n "→ Waiting for VPN connection"
VPN_CONNECTED=0
for i in {1..60}; do
    sleep 1
    echo -n "."

    # Check if tun interface exists
    if ip link show tun0 >/dev/null 2>&1; then
        VPN_CONNECTED=1
        break
    fi

    # Check if Gluetun is still running
    if ! kill -0 $GLUETUN_PID 2>/dev/null; then
        echo ""
        echo "✗ Gluetun exited unexpectedly"
        echo "Last 30 lines of Gluetun log:"
        tail -n 30 /tmp/gluetun.log 2>/dev/null || echo "No log available"
        break
    fi
done

if [ "$VPN_CONNECTED" = "1" ]; then
    echo ""
    echo "✓ VPN connected successfully!"

    # Get VPN IP
    sleep 2
    VPN_IP=$(curl -s --max-time 10 https://api.ipify.org 2>/dev/null || echo "unknown")
    echo "  Public IP: $VPN_IP"

    # Show routing info
    echo "  VPN Interface: tun0"
    echo "  Local networks bypassing VPN: $LOCAL_NETWORKS"
    exit 0
fi

echo ""
echo "✗ VPN connection timeout"
echo "Last 30 lines of Gluetun log:"
tail -n 30 /tmp/gluetun.log 2>/dev/null || echo "No log available"
exit 1
