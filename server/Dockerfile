# Build stage: compile the server to a single native executable.
FROM dart:stable AS build
WORKDIR /app
COPY pubspec.yaml pubspec.lock* ./
RUN dart pub get
COPY . .
RUN dart pub get --offline && dart compile exe bin/luma_server.dart -o /app/luma_server

# Runtime stage: minimal image, non-root user.
FROM debian:bookworm-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --create-home --uid 1000 luma \
    && mkdir -p /data && chown luma:luma /data

COPY --from=build /app/luma_server /usr/local/bin/luma_server

USER luma
ENV LUMA_DATA_DIR=/data
ENV LUMA_PORT=8080
EXPOSE 8080
VOLUME /data

CMD ["luma_server"]
