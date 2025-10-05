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
    jq

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

# Copy custom startup script
COPY ./run.sh /srv/stremio-server/run.sh
RUN chmod +x /srv/stremio-server/run.sh

# Set working directory
WORKDIR /srv/stremio-server

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