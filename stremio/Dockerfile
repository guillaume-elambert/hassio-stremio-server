# Build arguments
ARG BUILD_FROM
ARG STREMIO_IMAGE_VERSION=latest
ARG GLUETUN_IMAGE_VERSION=v3.40
ARG BUILD_ARCH
ARG BUILD_DESCRIPTION
ARG BUILD_NAME
ARG BUILD_VERSION

# Stage 1: Get Gluetun VPN binaries (using specific stable version)
FROM qmcgaw/gluetun:${GLUETUN_IMAGE_VERSION} as gluetun

RUN env > /tmp/env

# Stage 2: Build final image
FROM tsaridas/stremio-docker:${STREMIO_IMAGE_VERSION} as final

# Install required packages from custom scripts 
RUN apk add --no-cache --update \
    bash \
    jq \
    ipcalc

# Get env variables from Gluetun
COPY --from=gluetun /tmp/env /tmp/gluetun.env
# RUN xargs bash -c 'printf "export %q\n" "$@"' -- < /tmp/gluetun.env > /gluetun.env
RUN xargs -I@ bash -c 'key="${1%%=*}"; val="${1#*=}"; printf "export %s=\${%s:-%q}\n" "$key" "$key" "$val"' -- @ < /tmp/gluetun.env > /gluetun.env

# Install required packages for Gluetun
RUN apk add --no-cache --update \
    ca-certificates \
    iptables \
    unbound \
    tzdata \
    openvpn

# Copy Gluetun binaries and scripts from the Gluetun image
COPY --from=gluetun /gluetun /gluetun
COPY --from=gluetun /gluetun-entrypoint /gluetun-entrypoint

COPY --from=gluetun /usr/sbin/openvpn2.5 /usr/sbin/openvpn2.5
COPY --from=gluetun /usr/sbin/openvpn2.6 /usr/sbin/openvpn2.6
COPY --from=gluetun /usr/lib/openvpn /usr/lib/

RUN rm -rf /usr/sbin/openvpn /var/cache/apk/* /etc/unbound/* /usr/sbin/unbound-* /etc/openvpn/*.sh /usr/lib/openvpn/plugins/openvpn-plugin-down-root.so && \
    deluser openvpn || true && \
    deluser unbound || true


# Add media driver only for x86_64
RUN if [ "$(uname -m)" = "x86_64" ]; then \
    apk add --no-cache intel-media-driver mesa-va-gallium mesa-vulkan-ati; \
    fi

RUN rm -rf /root/.stremio-server && \
    ln -s "/.stremio-server/" "/root/"

# Copy custom startup script
COPY ./run.sh /srv/stremio-server/run.sh
RUN chmod +x /srv/stremio-server/run.sh

# Copy vpn setup script
COPY ./vpn-setup.sh /srv/stremio-server/vpn-setup.sh
RUN chmod +x /srv/stremio-server/vpn-setup.sh

# Copy stremio server settings script
COPY ./setup-server-settings.sh /srv/stremio-server/setup-server-settings.sh
RUN chmod +x /srv/stremio-server/setup-server-settings.sh

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