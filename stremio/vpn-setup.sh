#!/bin/bash
set -e

VPN_CONFIG_DIR="/config/vpn"
CONFIG_PATH="/data/options.json"

echo ""
echo "=================================="
echo "VPN Configuration"
echo "=================================="

# Get VPN config file from options
VPN_CONFIG_FILENAME=$(jq -r '.vpn_config_filename // ""' "$CONFIG_PATH")
POSSIBLE_FILES=("$VPN_CONFIG_FILENAME" "vpn.ovpn" "vpn.conf")

# Check if one of VPN config exists
for FILE in "${POSSIBLE_FILES[@]}"; do
    if [ -n "$FILE" ] && [ -f "$VPN_CONFIG_DIR/$FILE" ]; then
        VPN_CONFIG="$VPN_CONFIG_DIR/$FILE"
        break
    fi
done

# Exit if no config found
if [ -z "$VPN_CONFIG" ]; then
    echo "ℹ  No VPN configuration found - skipping VPN setup"
    exit 0
fi

echo "ℹ VPN config found: $VPN_CONFIG"

# Auto-detect local network
AUTO_DETECT_NETWORK() {
    # Get default gateway interface
    DEFAULT_IFACE=$(ip route | grep default | grep -v tun | awk '{print $5}' | head -n1)
    
    if [ -z "$DEFAULT_IFACE" ]; then
        echo "⚠ Could not detect default network interface"
        exit 1
    fi
    
    # Get IP and netmask of default interface
    LOCAL_IP=$(ip -o -f inet addr show "$DEFAULT_IFACE" | awk '{print $4}')
    
    if [ -z "$LOCAL_IP" ]; then
        echo "⚠ Could not detect local IP"
        exit 1
    fi
    
    echo "$LOCAL_IP"
}

# Get local network from config or auto-detect
LOCAL_NETWORK=$(jq -r '.local_network // ""' "$CONFIG_PATH")

if [ -z "$LOCAL_NETWORK" ]; then
    echo "→ Auto-detecting local network..."
    LOCAL_NETWORK=$(AUTO_DETECT_NETWORK)
    
    if [ $? -eq 0 ]; then
        echo "✓ Detected local network: $LOCAL_NETWORK"
    else
        echo "⚠ Auto-detection failed, using common private ranges"
        LOCAL_NETWORK="auto"
    fi
else
    echo "✓ Using configured local network: $LOCAL_NETWORK"
fi

# Store for use in routing script
export LOCAL_NETWORK
export DEFAULT_GATEWAY=$(ip route | grep default | grep -v tun | awk '{print $3}' | head -n1)
export DEFAULT_IFACE=$(ip route | grep default | grep -v tun | awk '{print $5}' | head -n1)

echo "  Gateway: $DEFAULT_GATEWAY via $DEFAULT_IFACE"

# Prepare OpenVPN config
mkdir -p /etc/openvpn
cp "$VPN_CONFIG" /etc/openvpn/client.conf

# Add authentication if exists
if [ -f "$VPN_CONFIG_DIR/auth.txt" ]; then
    cp "$VPN_CONFIG_DIR/auth.txt" /etc/openvpn/auth.txt
    chmod 600 /etc/openvpn/auth.txt
    
    if ! grep -q "auth-user-pass" /etc/openvpn/client.conf; then
        echo "auth-user-pass /etc/openvpn/auth.txt" >> /etc/openvpn/client.conf
    else
        sed -i 's|auth-user-pass.*|auth-user-pass /etc/openvpn/auth.txt|g' /etc/openvpn/client.conf
    fi
    echo "✓ VPN authentication configured"
fi

# Configure OpenVPN for split tunneling
# if ! grep -q "route-nopull" /etc/openvpn/client.conf; then
#     echo "route-nopull" >> /etc/openvpn/client.conf
# fi

# if ! grep -q "script-security 2" /etc/openvpn/client.conf; then
#     echo "script-security 2" >> /etc/openvpn/client.conf
# fi

# # Prevent DNS changes
# if ! grep -q "pull-filter ignore \"dhcp-option DNS\"" /etc/openvpn/client.conf; then
#     echo "pull-filter ignore \"dhcp-option DNS\"" >> /etc/openvpn/client.conf
# fi

# Start OpenVPN
echo "→ Starting OpenVPN..."
openvpn --config /etc/openvpn/client.conf --daemon

# Wait for connection
echo -n "→ Waiting for VPN connection"
for i in {1..30}; do
    sleep 1
    echo -n "."
    
    TUN_IFACE=$(ip -o link show | awk -F': ' '/tun[0-9]+/ {print $2}' | head -n1)
    if [ -n "$TUN_IFACE" ]; then
        echo ""
        echo "✓ VPN connection established!"
        
        # Get VPN IP
        VPN_IP=$(ip addr show "$TUN_IFACE" | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)
        echo "  VPN IP: $VPN_IP"
        
        # Get public IP
        PUBLIC_IP=$(timeout 5 curl -s ifconfig.me 2>/dev/null || echo "unknown")
        echo "  Public IP: $PUBLIC_IP"
    
        exit 0
    fi
done

echo ""
echo "✗ VPN connection timeout - continuing without VPN"
exit 1