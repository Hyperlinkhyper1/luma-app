# Build stage: compile the server to a self-contained bundle.
FROM dart:stable AS build
# sqlite3 ships its native library via Dart build hooks, which compile C
# sources on the build machine — so the build stage needs a C toolchain.
RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY pubspec.yaml pubspec.lock* ./
RUN dart pub get
COPY . .
# NB: `dart compile exe` refuses to run when any dependency has a build hook
# (sqlite3 does), so build with `dart build cli` instead. It runs the hooks
# and emits bundle/bin/luma_server next to bundle/lib/*.so — the two must
# stay together, the exe loads its native libraries via ../lib.
RUN dart pub get --offline && dart build cli --target bin/luma_server.dart -o /tmp/build-output

# Runtime stage: minimal image.
#
# The admin dashboard's "Update & restart server" button (DeployConsole)
# only drops a request file on the /data volume — the actual git pull and
# `docker compose up -d --build` run on the host via deploy-watcher.sh (a
# systemd service, see luma-deploy-watcher.service), not in this container.
# Nothing here runs git, curl or docker, so none of them are installed: each
# was only more to work with for whoever got code execution in here.
FROM debian:bookworm-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /data

# Node only parses inline scripts here. AI-generated HTML executes in the
# separate renderer service, which cannot mount server data or credentials.
RUN apt-get update \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*
COPY tool/check_syntax.mjs tool/shot_control.mjs /app/tool/
ENV LUMA_PREVIEW_TOOL=/app/tool/render_previews.mjs

COPY --from=build /tmp/build-output/bundle/ /app/bundle/

# The AI benchmark scenes the app downloads on demand (see
# server/benchmarks/README.md). Baked in read-only; the /data volume holds
# per-file operator overrides.
COPY --from=build /app/benchmarks/ /seed/benchmarks/

ENV LUMA_DATA_DIR=/data
ENV LUMA_PORT=8080
EXPOSE 8080
VOLUME /data

# Starts as root only to hand /data to an unprivileged user, then drops to
# it with no capabilities left — see docker-entrypoint.sh.
COPY docker-entrypoint.sh /app/docker-entrypoint.sh
RUN chmod 0755 /app/docker-entrypoint.sh
ENTRYPOINT ["/app/docker-entrypoint.sh"]
