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
# This image no longer needs the host's Docker socket for that reason; git,
# docker-ce-cli and docker-compose-plugin below are kept only because
# they're occasionally useful for in-container debugging over `docker exec`.
FROM debian:bookworm-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates git curl gnupg \
    && install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian bookworm stable" \
        > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends docker-ce-cli docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /data

COPY --from=build /tmp/build-output/bundle/ /app/bundle/

# The AI benchmark scenes the app downloads on demand (see
# server/benchmarks/README.md). Baked in read-only; the /data volume holds
# per-file operator overrides.
COPY --from=build /app/benchmarks/ /seed/benchmarks/

ENV LUMA_DATA_DIR=/data
ENV LUMA_PORT=8080
EXPOSE 8080
VOLUME /data

CMD ["/app/bundle/bin/luma_server"]
