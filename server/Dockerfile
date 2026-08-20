# Build stage: compile the server to a single native executable.
FROM dart:stable AS build
WORKDIR /app
COPY pubspec.yaml pubspec.lock* ./
RUN dart pub get
COPY . .
RUN dart pub get --offline && dart compile exe bin/luma_server.dart -o /app/luma_server

# Runtime stage: minimal image.
#
# The admin dashboard's "Update & restart server" button (Api._adminDeploy)
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

COPY --from=build /app/luma_server /usr/local/bin/luma_server

ENV LUMA_DATA_DIR=/data
ENV LUMA_PORT=8080
EXPOSE 8080
VOLUME /data

CMD ["luma_server"]
