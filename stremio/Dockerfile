# Build arguments
ARG BUILD_FROM
ARG IMAGE_VERSION=latest
ARG BUILD_ARCH
ARG BUILD_DESCRIPTION
ARG BUILD_NAME
ARG BUILD_VERSION

# Use the stremio-docker base image
FROM tsaridas/stremio-docker:${IMAGE_VERSION} as final

# Install hardware acceleration packages
# The base image already has libva, we need to add drivers and utils
RUN apk add --no-cache \
    bash \
    jq \
    openvpn \
    iproute2
    # avahi \
    # avahi-compat-libdns_sd

# Add Intel media driver only for x86_64 (already done in base but ensuring latest)
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

# Copy VPN setup script
COPY ./vpn-setup.sh /usr/local/bin/vpn-setup.sh
RUN chmod +x /usr/local/bin/vpn-setup.sh

# Copy VPN run script
COPY ./vpn-up.sh /usr/local/bin/vpn-up
RUN chmod +x /usr/local/bin/vpn-up

# Copy custom startup script
COPY ./run.sh /srv/stremio-server/run.sh
RUN chmod +x /srv/stremio-server/run.sh

# Clear cache
RUN rm -rf /var/cache/apk/* && rm -rf /tmp/*

# Set working directory
WORKDIR /srv/stremio-server

# Fix self certificate when node calling it self with https and not localhost url
ENV NODE_TLS_REJECT_UNAUTHORIZED=0

# Expose ports (already exposed in base, but documenting)
EXPOSE 8080

# Use our custom startup script instead of the default
ENTRYPOINT []
CMD ["/srv/stremio-server/run.sh"]

# Labels
LABEL \
    io.hass.name="${BUILD_NAME}" \
    io.hass.description="${BUILD_DESCRIPTION}" \
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.type="addon" \
    io.hass.version=${BUILD_VERSION}