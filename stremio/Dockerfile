
# ARG IMAGE_VERSION
# FROM alpine/git:v2.49.1 as sources

# # Extract the git to /sources
# RUN git clone https://github.com/ananjaser1211/stremio-docker.git /sources


# # ======================
# # Stage 1: Base OS Layer
# # ======================
# FROM debian:bookworm as base

# ENV DEBIAN_FRONTEND=noninteractive

# RUN echo "deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware" > /etc/apt/sources.list && \
#     apt-get update && \
#     apt-get upgrade -y && \
#     apt-get install -y --no-install-recommends \
#         curl wget git gnupg2 ca-certificates && \
#     apt-get clean && rm -rf /var/lib/apt/lists/*


# # ===================================
# # Stage 2: Build Dependencies Layer
# # ===================================
# FROM base as build-deps

# RUN apt-get update && \
#     apt-get install -y --no-install-recommends \
#         build-essential yasm pkg-config nasm libtool autoconf automake cmake \
#         python3 python3-pip meson ninja-build \
#         libass-dev libfreetype6-dev libvorbis-dev libvpx-dev \
#         libxcb1-dev libxcb-shm0-dev libxcb-xfixes0-dev libnuma-dev \
#         libopus-dev libx264-dev libx265-dev libdrm-dev libomxil-bellagio-dev \
#         libmp3lame-dev libtheora-dev libdav1d-dev \
#         git wget curl && \
#     apt-get clean && rm -rf /var/lib/apt/lists/*

# # ==================================
# # Stage 3: Intel iGPU Drivers Layer
# # ==================================
# FROM base as intel-drivers

# RUN apt-get update && apt-get install -y --no-install-recommends \
#         intel-media-va-driver-non-free \
#         i965-va-driver \
#         intel-gpu-tools \
#         vainfo && \
#     apt-get clean && rm -rf /var/lib/apt/lists/*


# # ================================
# # Stage 4: FFmpeg Compilation
# # ================================
# FROM build-deps as ffmpeg

# WORKDIR /build

# # 1. Additional Dependencies
# RUN apt-get update && apt-get install -y --no-install-recommends \
#         cmake libnuma-dev libtool m4 autoconf libva-dev and libdrm-dev && \
#     apt-get clean && rm -rf /var/lib/apt/lists/*

# # 2. Build and install fdk-aac
# RUN git clone --depth 1 https://github.com/mstorsjo/fdk-aac.git && \
#     cd fdk-aac && \
#     autoreconf -fiv && \
#     ./configure --prefix=/usr/local && \
#     make -j$(nproc) && \
#     make install && \
#     ldconfig

# # 3. Build and install x265
# RUN git clone --branch stable --depth 1 https://bitbucket.org/multicoreware/x265_git && \
#     cd x265_git/build/linux && \
#     cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX=/usr/local ../../source && \
#     make -j$(nproc) && \
#     make install

# # Clone and build ffmpeg
# WORKDIR /opt/ffmpeg

# RUN git clone --depth 1 --branch v4.4.1-4 https://github.com/jellyfin/jellyfin-ffmpeg/ . && \
#     ./configure --prefix=/usr \
#         --pkg-config-flags="--static" \
#         --extra-cflags="-I/usr/include" \
#         --extra-ldflags="-L/usr/lib" \
#         --extra-libs="-lpthread -lm" \
#         --bindir=/usr/bin \
#         --enable-gpl --enable-nonfree \
#         --enable-libx264 --enable-libx265 --enable-libvpx --enable-libopus \
#         --enable-libass --enable-libfreetype --enable-libmp3lame \
#         --enable-libvorbis --enable-libtheora --enable-libdav1d \
#         --enable-vaapi --enable-hwaccel=h264_vaapi \
#         --enable-hwaccel=hevc_vaapi && \
#     make -j"$(nproc)" && make install


# # ========================
# # Stage 5: Node Environment
# # ========================
# FROM node:lts-bookworm as node-env

# # Install yarn classic
# RUN corepack enable && corepack prepare yarn@1.22.21 --activate

# # ========================
# # Stage 6: App Build Layer
# # ========================
# FROM node-env as builder

# WORKDIR /srv

# ARG BRANCH=development

# # Clone repo and patch localStorage
# RUN git clone --depth 1 --branch "$BRANCH" https://github.com/Stremio/stremio-web.git

# WORKDIR /srv/stremio-web

# COPY --from=sources /sources/load_localStorage.js ./src/load_localStorage.js
# RUN sed -i "/entry: {/a \\        loader: './src/load_localStorage.js'," webpack.config.js

# RUN yarn install --no-audit --no-optional --mutex network --no-progress --ignore-scripts && \
#     yarn build

# # Fetch stremio shell resources
# RUN wget $(wget -O- https://raw.githubusercontent.com/Stremio/stremio-shell/master/server-url.txt) && \
#     wget -mkEpnp -nH \
#         "https://app.strem.io/" \
#         "https://app.strem.io/worker.js" \
#         "https://app.strem.io/images/stremio.png" \
#         "https://app.strem.io/images/empty.png" \
#         -P build/shell/ || true


# # ================================
# # Stage 7: Final Runtime Container
# # ================================
# # Build arguments
# ARG BUILD_ARCH
# ARG BUILD_DESCRIPTION
# ARG BUILD_NAME
# ARG BUILD_VERSION
# FROM node-env as final

# WORKDIR /srv/stremio-server

# RUN apt-get update && apt-get install -y --no-install-recommends jq bash && apt-get clean && rm -rf /var/lib/apt/lists/*

# # Copy Intel GPU drivers
# COPY --from=intel-drivers /usr/lib/x86_64-linux-gnu/dri /usr/lib/x86_64-linux-gnu/dri
# COPY --from=intel-drivers /usr/bin/vainfo /usr/bin/vainfo

# # Copy compiled FFmpeg binaries
# COPY --from=ffmpeg /usr/lib /usr/lib
# COPY --from=ffmpeg /usr/bin/ffmpeg /usr/bin/ffmpeg
# COPY --from=ffmpeg /usr/bin/ffprobe /usr/bin/ffprobe

# # Copy all shared libs used by ffmpeg
# COPY --from=ffmpeg /usr/local/lib/libx265* /usr/lib/
# COPY --from=ffmpeg /usr/lib/x86_64-linux-gnu/libx264.so.* /usr/lib/x86_64-linux-gnu/
# COPY --from=ffmpeg /usr/lib/x86_64-linux-gnu/libvpx.so.*   /usr/lib/x86_64-linux-gnu/
# COPY --from=ffmpeg /usr/lib/x86_64-linux-gnu/libdav1d.so.* /usr/lib/x86_64-linux-gnu/
# COPY --from=ffmpeg /usr/lib/x86_64-linux-gnu/libxvidcore.so.* /usr/lib/x86_64-linux-gnu/

# # Copy additional
# COPY --from=ffmpeg /usr/lib/x86_64-linux-gnu/*.so* /usr/lib/x86_64-linux-gnu/

# # Copy frontend app build
# COPY --from=builder /srv/stremio-web/build ./build
# COPY --from=builder /srv/stremio-web/server.js ./

# # Custom scripts and config
# COPY --from=sources /sources/stremio-web-service-run.sh ./
# COPY --from=sources /sources/certificate.js ./
# COPY --from=sources /sources/restart_if_idle.sh ./
# COPY --from=sources /sources/localStorage.json ./

# # Additional Config
# ENV FFMPEG_BIN=
# ENV FFPROBE_BIN=
# # default https://app.strem.io/shell-v4.4/
# ENV WEBUI_LOCATION=
# ENV WEBUI_INTERNAL_PORT=
# ENV OPEN=
# ENV HLS_DEBUG=
# ENV DEBUG=
# ENV DEBUG_MIME=
# ENV DEBUG_FD=
# ENV FFMPEG_DEBUG=
# ENV FFSPLIT_DEBUG=
# ENV NODE_DEBUG=
# ENV NODE_ENV=production
# ENV HTTPS_CERT_ENDPOINT=
# ENV DISABLE_CACHING=
# # disable or enable
# ENV READABLE_STREAM=
# # remote or local
# ENV HLSV2_REMOTE=

# # Custom application path for storing server settings, certificates, etc
# # You can change this but server.js always saves cache to /root/.stremio-server/
# ENV APP_PATH=
# ENV NO_CORS=1
# ENV CASTING_DISABLED=

# # Do not change the above ENVs.

# # Set this to your lan or public ip.
# ENV IPADDRESS=
# # Set this to your domain name
# ENV DOMAIN=
# # Set this to the path to your certificate file
# ENV CERT_FILE=

# # Server url
# ENV SERVER_URL=

# RUN chmod +x stremio-web-service-run.sh restart_if_idle.sh

# # Install HTTP server globally
# RUN npm install -g http-server

# ENV NODE_ENV=production
# ENV LIBVA_DRIVER_NAME=i965
# ENV DISPLAY=:0
# ENV LD_LIBRARY_PATH="/usr/lib:$LD_LIBRARY_PATH"

# VOLUME ["/root/.stremio-server"]

# EXPOSE 8080 11470 12470

# COPY ./run.sh ./run.sh
# RUN chmod +x ./run.sh

# ENTRYPOINT []
# # Override CMD to source env_vars.sh before running the main process
# CMD ["/bin/bash", "-c", "./run.sh"]

# # Labels
# LABEL \
#     io.hass.name="${BUILD_NAME}" \
#     io.hass.description="${BUILD_DESCRIPTION}" \
#     io.hass.arch="${BUILD_ARCH}" \
#     io.hass.type="addon" \
#     io.hass.version=${BUILD_VERSION}


# # Build arguments
# ARG BUILD_FROM
# ARG IMAGE_VERSION
# ARG BUILD_ARCH
# ARG BUILD_DESCRIPTION
# ARG BUILD_NAME
# ARG BUILD_VERSION

# FROM tsaridas/stremio-docker:$IMAGE_VERSION as final

# COPY ./run.sh ./run.sh
# RUN chmod +x ./run.sh

# # Install jq for JSON parsing
# RUN apk add --no-cache jq bash

# # Add Intel VAAPI driver for Sandy Bridge and similar
# RUN apk add --no-cache libva-intel-driver mesa-dri-gallium mesa-va-gallium intel-media-driver linux-firmware-i915 mesa-va-drivers


# # Add AMD libraries for hardware acceleration
# RUN apk add --no-cache linux-firmware-amdgpu linux-firmware-radeon mesa-vulkan-ati xf86-video-amdgpu

# # Force VAAPI to use legacy i965 driver
# ENV LIBVA_DRIVER_NAME=i965
# ENV LIBVA_DRIVERS_PATH=/usr/lib/x86_64-linux-gnu/dri
# ENV LIBVA_DRIVER_DEVICE=/dev/dri/renderD128

# # Clear cache
# RUN rm -rf /var/cache/apk/* && rm -rf /tmp/*

# # Expose default ports
# EXPOSE 8080 11470 12470

# ENTRYPOINT []
# # Override CMD to source env_vars.sh before running the main process
# CMD ["./run.sh"]

# # Labels
# LABEL \
#     io.hass.name="${BUILD_NAME}" \
#     io.hass.description="${BUILD_DESCRIPTION}" \
#     io.hass.arch="${BUILD_ARCH}" \
#     io.hass.type="addon" \
#     io.hass.version=${BUILD_VERSION}

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
    adduser root video 2>/dev/null || truee

# Copy custom startup script
COPY ./run.sh /srv/stremio-server/run.sh
RUN chmod +x /srv/stremio-server/run.sh

# Set working directory
WORKDIR /srv/stremio-server

# Expose ports (already exposed in base, but documenting)
EXPOSE 8080 11470 12470

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