# Build arguments
ARG BUILD_FROM
ARG IMAGE_VERSION=latest
ARG BUILD_ARCH
ARG BUILD_DESCRIPTION
ARG BUILD_NAME
ARG BUILD_VERSION

# Stage 1: Get Gluetun VPN binaries (using specific stable version)
FROM qmcgaw/gluetun:v3.40 as gluetun

# Stage 2: Build final image
FROM tsaridas/stremio-docker:${IMAGE_VERSION} as final

# Glutun environment variables with default values
ENV VPN_SERVICE_PROVIDER=pia \
    VPN_TYPE=openvpn \
    # Common VPN options
    VPN_INTERFACE=tun0 \
    # OpenVPN
    OPENVPN_ENDPOINT_IP= \
    OPENVPN_ENDPOINT_PORT= \
    OPENVPN_PROTOCOL=udp \
    OPENVPN_USER= \
    OPENVPN_PASSWORD= \
    OPENVPN_USER_SECRETFILE=/run/secrets/openvpn_user \
    OPENVPN_PASSWORD_SECRETFILE=/run/secrets/openvpn_password \
    OPENVPN_VERSION=2.6 \
    OPENVPN_VERBOSITY=1 \
    OPENVPN_FLAGS= \
    OPENVPN_CIPHERS= \
    OPENVPN_AUTH= \
    OPENVPN_PROCESS_USER=root \
    OPENVPN_CUSTOM_CONFIG= \
    # Wireguard
    WIREGUARD_ENDPOINT_IP= \
    WIREGUARD_ENDPOINT_PORT= \
    WIREGUARD_CONF_SECRETFILE=/run/secrets/wg0.conf \
    WIREGUARD_PRIVATE_KEY= \
    WIREGUARD_PRIVATE_KEY_SECRETFILE=/run/secrets/wireguard_private_key \
    WIREGUARD_PRESHARED_KEY= \
    WIREGUARD_PRESHARED_KEY_SECRETFILE=/run/secrets/wireguard_preshared_key \
    WIREGUARD_PUBLIC_KEY= \
    WIREGUARD_ALLOWED_IPS= \
    WIREGUARD_PERSISTENT_KEEPALIVE_INTERVAL=0 \
    WIREGUARD_ADDRESSES= \
    WIREGUARD_ADDRESSES_SECRETFILE=/run/secrets/wireguard_addresses \
    WIREGUARD_MTU=1400 \
    WIREGUARD_IMPLEMENTATION=auto \
    # VPN server filtering
    SERVER_REGIONS= \
    SERVER_COUNTRIES= \
    SERVER_CITIES= \
    SERVER_HOSTNAMES= \
    SERVER_CATEGORIES= \
    # # Mullvad only:
    ISP= \
    OWNED_ONLY=no \
    # # Private Internet Access only:
    PRIVATE_INTERNET_ACCESS_OPENVPN_ENCRYPTION_PRESET= \
    VPN_PORT_FORWARDING=off \
    VPN_PORT_FORWARDING_LISTENING_PORT=0 \
    VPN_PORT_FORWARDING_PROVIDER= \
    VPN_PORT_FORWARDING_STATUS_FILE="/tmp/gluetun/forwarded_port" \
    VPN_PORT_FORWARDING_USERNAME= \
    VPN_PORT_FORWARDING_PASSWORD= \
    # # Cyberghost only:
    OPENVPN_CERT= \
    OPENVPN_KEY= \
    OPENVPN_CLIENTCRT_SECRETFILE=/run/secrets/openvpn_clientcrt \
    OPENVPN_CLIENTKEY_SECRETFILE=/run/secrets/openvpn_clientkey \
    # # VPNSecure only:
    OPENVPN_ENCRYPTED_KEY= \
    OPENVPN_ENCRYPTED_KEY_SECRETFILE=/run/secrets/openvpn_encrypted_key \
    OPENVPN_KEY_PASSPHRASE= \
    OPENVPN_KEY_PASSPHRASE_SECRETFILE=/run/secrets/openvpn_key_passphrase \
    # # Nordvpn only:
    SERVER_NUMBER= \
    # # PIA only:
    SERVER_NAMES= \
    # # ProtonVPN only:
    FREE_ONLY= \
    SECURE_CORE_ONLY= \
    TOR_ONLY= \
    # # Surfshark only:
    MULTIHOP_ONLY= \
    # # VPN Secure only:
    PREMIUM_ONLY= \
    # # PIA only:
    PORT_FORWARD_ONLY= \
    # Firewall
    FIREWALL_ENABLED_DISABLING_IT_SHOOTS_YOU_IN_YOUR_FOOT=on \
    FIREWALL_VPN_INPUT_PORTS= \
    FIREWALL_INPUT_PORTS= \
    FIREWALL_OUTBOUND_SUBNETS= \
    FIREWALL_DEBUG=off \
    # Logging
    LOG_LEVEL=info \
    # Health
    HEALTH_SERVER_ADDRESS=127.0.0.1:9999 \
    HEALTH_TARGET_ADDRESS=cloudflare.com:443 \
    HEALTH_SUCCESS_WAIT_DURATION=5s \
    HEALTH_VPN_DURATION_INITIAL=6s \
    HEALTH_VPN_DURATION_ADDITION=5s \
    # DNS over TLS
    DOT=on \
    DOT_PROVIDERS=cloudflare \
    DOT_PRIVATE_ADDRESS=127.0.0.1/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,169.254.0.0/16,::1/128,fc00::/7,fe80::/10,::ffff:7f00:1/104,::ffff:a00:0/104,::ffff:a9fe:0/112,::ffff:ac10:0/108,::ffff:c0a8:0/112 \
    DOT_VERBOSITY=1 \
    DOT_VERBOSITY_DETAILS=0 \
    DOT_VALIDATION_LOGLEVEL=0 \
    DOT_CACHING=on \
    DOT_IPV6=off \
    BLOCK_MALICIOUS=on \
    BLOCK_SURVEILLANCE=off \
    BLOCK_ADS=off \
    UNBLOCK= \
    DNS_UPDATE_PERIOD=24h \
    DNS_ADDRESS=127.0.0.1 \
    DNS_KEEP_NAMESERVER=off \
    # HTTP proxy
    HTTPPROXY= \
    HTTPPROXY_LOG=off \
    HTTPPROXY_LISTENING_ADDRESS=":8888" \
    HTTPPROXY_STEALTH=off \
    HTTPPROXY_USER= \
    HTTPPROXY_PASSWORD= \
    HTTPPROXY_USER_SECRETFILE=/run/secrets/httpproxy_user \
    HTTPPROXY_PASSWORD_SECRETFILE=/run/secrets/httpproxy_password \
    # Shadowsocks
    SHADOWSOCKS=off \
    SHADOWSOCKS_LOG=off \
    SHADOWSOCKS_LISTENING_ADDRESS=":8388" \
    SHADOWSOCKS_PASSWORD= \
    SHADOWSOCKS_PASSWORD_SECRETFILE=/run/secrets/shadowsocks_password \
    SHADOWSOCKS_CIPHER=chacha20-ietf-poly1305 \
    # Control server
    HTTP_CONTROL_SERVER_LOG=on \
    HTTP_CONTROL_SERVER_ADDRESS=":8000" \
    HTTP_CONTROL_SERVER_AUTH_CONFIG_FILEPATH=/gluetun/auth/config.toml \
    # Server data updater
    UPDATER_PERIOD=0 \
    UPDATER_MIN_RATIO=0.8 \
    UPDATER_VPN_SERVICE_PROVIDERS= \
    # Public IP
    PUBLICIP_FILE="/tmp/gluetun/ip" \
    PUBLICIP_PERIOD=12h \
    PUBLICIP_API=ipinfo \
    PUBLICIP_API_TOKEN= \
    # Pprof
    PPROF_ENABLED=no \
    PPROF_BLOCK_PROFILE_RATE=0 \
    PPROF_MUTEX_PROFILE_RATE=0 \
    PPROF_HTTP_SERVER_ADDRESS=":6060" \
    # Extras
    VERSION_INFORMATION=on \
    TZ= \
    PUID= \
    PGID=

# Install required packages
RUN apk add --no-cache \
    bash \
    jq

# Copy Gluetun binaries and scripts from the Gluetun image
COPY --from=gluetun /gluetun /gluetun
COPY --from=gluetun /gluetun-entrypoint /gluetun-entrypoint

RUN apk add --no-cache --update -l wget && \
    apk add --no-cache --update -X "https://dl-cdn.alpinelinux.org/alpine/v3.17/main" openvpn\~2.5 && \
    mv /usr/sbin/openvpn /usr/sbin/openvpn2.5 && \
    apk del openvpn
RUN apk add --no-cache --update openvpn ca-certificates iptables iptables unbound tzdata
RUN mv /usr/sbin/openvpn /usr/sbin/openvpn2.6 && \
    rm -rf /var/cache/apk/* /etc/unbound/* /usr/sbin/unbound-* /etc/openvpn/*.sh /usr/lib/openvpn/plugins/openvpn-plugin-down-root.so && \
    deluser openvpn || true && \
    deluser unbound || true

# Add Intel media driver only for x86_64
RUN if [ "$(uname -m)" = "x86_64" ]; then \
    apk add --no-cache intel-media-driver mesa-va-gallium; \
    fi

# Add AMD support for x86_64
RUN if [ "$(uname -m)" = "x86_64" ]; then \
    apk add --no-cache mesa-vulkan-ati || true; \
    fi

# Ensure video group exists and add root user to it
RUN addgroup -g 44 video 2>/dev/null || true && \
    adduser root video 2>/dev/null || true

# Copy custom startup script
COPY ./run.sh /srv/stremio-server/run.sh
RUN chmod +x /srv/stremio-server/run.sh

# Copy vpn setup script
COPY ./vpn-setup.sh /srv/stremio-server/vpn-setup.sh
RUN chmod +x /srv/stremio-server/vpn-setup.sh

# Copy iptables post-rules for Gluetun
COPY ./post-rules.txt /iptables/post-rules.txt

# Clear cache
RUN rm -rf /var/cache/apk/* && rm -rf /tmp/*

# Set working directory
WORKDIR /srv/stremio-server

# Fix self certificate when node calling it self with https and not localhost url
ENV NODE_TLS_REJECT_UNAUTHORIZED=0

# Expose ports
EXPOSE 8080

# Use our custom startup script
ENTRYPOINT ["/srv/stremio-server/run.sh"]
CMD []

# Labels
LABEL \
    io.hass.name="${BUILD_NAME}" \
    io.hass.description="${BUILD_DESCRIPTION}" \
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.type="addon" \
    io.hass.version=${BUILD_VERSION}