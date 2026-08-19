# Build stage: compile the server to a single native executable.
FROM dart:stable AS build
WORKDIR /app
COPY pubspec.yaml pubspec.lock* ./
RUN dart pub get
COPY . .
RUN dart pub get --offline && dart compile exe bin/luma_server.dart -o /app/luma_server

# Runtime stage: minimal image.
#
# Runs as root and gets the host's Docker socket mounted (see
# docker-compose.yml) so the admin dashboard's "Update & restart server"
# button can git-pull, rebuild and redeploy this very container — see
# Api._adminDeploy. That socket already grants root-equivalent control of the
# host to anything that can reach it, so keeping this process itself
# unprivileged would add negligible defense in depth; the actual security
# boundary here is LUMA_ADMIN_KEY. Deployments that don't set LUMA_REPO_PATH
# never mount the socket and the deploy button refuses to run — see
# .env.example.
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
