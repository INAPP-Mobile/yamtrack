# Redis 8 companion for the Yamtrack Railway template.
#
# Bakes every constant as ENV/flags because Railway's `templates create`
# only carries ${{...}} expressions into template defaults — literals would
# land on the deploy form as required fields. This service has NO variables
# at all: no password (the stock image runs without auth by default, and it
# is reachable only over Railway's private network — same as upstream's own
# docker-compose, which sets no password either).
#
# Volume handling: the official redis image starts as root and its
# entrypoint chowns /data to the redis user before dropping privileges,
# which tolerates Railway's root-owned volumes. Append-only persistence is
# on so the Celery task queue and the metadata cache survive restarts.
#
# Digest pinned from the redis:8-alpine tag (a moving tag); the
# manifest-list digest is the pin.
# (amd64 sha256:41ed50f5c0d9cf8b2151ad63df24ba96d018ccc84804d0688e9b9f1ed3d9f558).
FROM redis:8-alpine@sha256:7958cfbb9d152f87dadfbc89f1b0b15938f0b81ff8982feb327476f4911935c3

# No Dockerfile VOLUME instruction — Railway's builder rejects it. The
# volume is attached by the deploy at /data (see railway.json in the repo
# root; the redis service gets its own volume when the template installs).

CMD ["redis-server", "--appendonly", "yes", "--dir", "/data"]

LABEL org.opencontainers.image.source="https://github.com/INAPP-Mobile/yamtrack"
