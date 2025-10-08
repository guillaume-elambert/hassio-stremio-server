#!/bin/bash
set -e

echo "→ Configuring split tunnel routing..."

# Get the VPN gateway
VPN_GW="${route_vpn_gateway}"

if [ -z "$VPN_GW" ]; then
    echo "⚠ VPN gateway not provided"
    exit 1
fi

# Add default route through VPN with higher metric (lower priority initially)
ip route add default via "$VPN_GW" dev tun0 metric 100 2>/dev/null || true
echo "  ✓ Default route via VPN: $VPN_GW"

# Preserve local network routes
if [ "$LOCAL_NETWORK" = "auto" ]; then
    # Use common private ranges
    NETWORKS=("10.0.0.0/8" "172.16.0.0/12" "192.168.0.0/16" "169.254.0.0/16" "224.0.0.0/4")
else
    # Use detected/configured network
    NETWORKS=("$LOCAL_NETWORK")
    
    # Also add common ranges to be safe
    NETWORKS+=("169.254.0.0/16")  # Link-local
    NETWORKS+=("224.0.0.0/4")     # Multicast
    NETWORKS+=("172.30.0.0/16")   # Home Assistant supervisor
fi

# Add local routes with lower metric (higher priority)
for NET in "${NETWORKS[@]}"; do
    if [ -n "$DEFAULT_GATEWAY" ] && [ -n "$DEFAULT_IFACE" ]; then
        ip route add "$NET" via "$DEFAULT_GATEWAY" dev "$DEFAULT_IFACE" metric 50 2>/dev/null || true
        echo "  ✓ Local route: $NET via $DEFAULT_GATEWAY"
    fi
done

# Enable mDNS/Avahi for local discovery
# This allows services like homeassistant.local to work
# if command -v avahi-daemon >/dev/null 2>&1; then
#     avahi-daemon -D 2>/dev/null || true
#     echo "  ✓ mDNS/Avahi enabled for local discovery"
# fi

echo "✓ Split tunnel configured successfully"
echo ""
echo "Routing table:"
ip route | head -n 15