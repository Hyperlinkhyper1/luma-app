FROM node:24-bookworm-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends chromium \
        libgl1-mesa-dri libegl-mesa0 libegl1 mesa-vulkan-drivers \
        fonts-liberation fonts-noto-cjk fonts-noto-color-emoji \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 10001 renderer \
    && useradd --uid 10001 --gid renderer --no-create-home renderer
WORKDIR /app/tool
COPY tool/package.json tool/package-lock.json ./
RUN npm ci --omit=dev --ignore-scripts --no-audit --no-fund
COPY tool/render_previews.mjs tool/renderer_network.mjs tool/renderer_service.mjs \
    tool/renderer_smoke.mjs tool/shot_control.mjs tool/benchmark_scene_file.mjs ./
ENV LUMA_CHROMIUM_BIN=/usr/bin/chromium
# Only safe where the service is init's sole child: compose's `init: true`.
ENV LUMA_RENDERER_REAP_ORPHANS=1
ENV HOME=/tmp
ENV XDG_CONFIG_HOME=/tmp/chromium-config
ENV XDG_CACHE_HOME=/tmp/chromium-cache
USER renderer
EXPOSE 8081
CMD ["node", "renderer_service.mjs"]
