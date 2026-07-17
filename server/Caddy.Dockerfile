# Stock caddy:2 has no DNS provider plugins built in. This adds the
# Cloudflare one so Caddy can prove domain ownership via a DNS-01 TXT
# record instead of the default HTTP-01/TLS-ALPN-01 challenges — those
# both require Let's Encrypt to reach this machine directly on 80/443,
# which doesn't work for a home server sitting behind Cloudflare's proxy
# (it terminates/intercepts both before they reach the real origin).
FROM caddy:2-builder AS builder
RUN xcaddy build --with github.com/caddy-dns/cloudflare

FROM caddy:2
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
