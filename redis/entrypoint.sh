#!/bin/sh
# Redis on Railway.
#
# Railway volumes contain a root-owned `lost+found`, and Railway's own
# permission fix skips the volume when it sees it ("Unknown file
# './lost+found' found in data dir. Permissions will not be modified") —
# so the stock entrypoint's chown never makes /data itself writable for
# the redis user, and `redis-server --appendonly yes --dir /data` dies
# with "Can't open or create append-only dir appendonlydir: Permission
# denied" (proven in e2e 2026-11-19). Same shape as the Postgres PGDATA
# lesson: point the data dir at a SUBDIR of the mount. This entrypoint
# creates /data/redis and chowns it to redis (it runs as root), then
# hands off to the stock entrypoint, which drops to the redis user.
set -e

mkdir -p /data/redis
chown redis:redis /data/redis

exec docker-entrypoint.sh "$@"
