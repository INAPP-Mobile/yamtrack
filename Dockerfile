# Yamtrack 0.26.3 — self-hosted media tracker (FuzzyGrim/Yamtrack, AGPL-3.0).
#
# Upstream image pinned by manifest-list digest, WITHOUT a tag: Railpack
# 0.43.0 fails to detect a Dockerfile whose FROM carries both a tag and a
# digest, so redeploys die in the plan phase while the first deploy succeeds.
# The digest-only form builds under both builders. Version lives here in the
# comment: ghcr.io/fuzzygrim/yamtrack:0.26.3, manifest list
# sha256:78497b454b2b52d3b1062f6fd238351d714cff0895db4369e49ace36f4622e75
# (amd64 sha256:186754674a14c1c3ab094f59c1906a6256f09ab7a27665491a83be982fcc4d18).
#
# The stock image runs as root (no USER directive) — state it explicitly:
# Railway mounts persistent volumes root-owned, and the upstream entrypoint
# itself maps PUID/PGID onto its `abc` user and chowns /yamtrack, db and
# staticfiles before execing supervisord (nginx + gunicorn + celery).
#
# PORT: the stock image listens on 8000 via nginx, but 0.26.3's own
# entrypoint does NOT honour YAMTRACK_INTERNAL_PORT (upstream added that
# support after this release — verified against the v0.26.3 tag). The
# wrapper entrypoint remaps the nginx listen port itself with the same sed
# upstream added later. Never set YAMTRACK_INTERNAL_PORT=8001: that is
# gunicorn's bind port inside this image (0.26.3's config/gunicorn.py).
#
# HEALTHCHECK: the image ships its own HEALTHCHECK probing
# 127.0.0.1:8000/health/ — stale once the port is remapped, and Railway
# probes /health/ externally anyway, so the wrapper disables the
# in-container probe (HEALTHCHECK NONE below) rather than letting it
# report the container unhealthy forever.
#
# Persistence: SQLite lives at /yamtrack/db/db.sqlite3 (settings create the
# dir on import; DB_HOST unset selects SQLite). The Railway volume mounts
# there; the upstream entrypoint chowns it to abc, so gunicorn (user abc)
# can write. Redis is a companion service (redis/); its own volume holds
# the append-only file. Nothing else on disk needs persisting — posters are
# remote URLs, metadata is cached in Redis.
#
# Accounts: upstream ships open registration (REGISTRATION defaults True)
# and a WELL-KNOWN default SECRET_KEY ("ifx7bdUWo5EwC2NQNihjRjOrW00Cdv5Y"
# in settings.py) — both are closed by this wrapper: REGISTRATION=False is
# baked in, SECRET is a generated template variable, and the entrypoint
# seeds an admin account (admin / YAMTRACK_ADMIN_PASSWORD) with Django's
# createsuperuser before handing off to the upstream entrypoint. The admin
# logs into the web UI; /admin/ is enabled (ADMIN_ENABLED=True) for user
# management. Search works out of the box: TMDB/MAL/IGDB/Hardcover/
# ComicVine ship shared default API keys upstream (rate-limited; bring
# your own for heavy use — see README Configuration).
#
# Healthcheck: upstream's own /health/ (its Dockerfile HEALTHCHECK probes
# it with wget). It answers 200 without auth.
FROM ghcr.io/fuzzygrim/yamtrack@sha256:78497b454b2b52d3b1062f6fd238351d714cff0895db4369e49ace36f4622e75

# The stock image carries no USER directive (it runs as root) — state it
# explicitly: Railway mounts persistent volumes root-owned, and the upstream
# entrypoint needs root for usermod/groupmod + chown before it drops to abc.
USER root

# Baked defaults. These literals never appear on the one-click deploy form.
# REGISTRATION=False closes open signup (the seeded admin is the account);
# ADMIN_ENABLED=True exposes Django's /admin/ for user management.
# SECRET / YAMTRACK_ADMIN_PASSWORD / REDIS_HOST come from the template
# variables (see template-vars.json / companion-mapping.json).
ENV TZ=UTC \
    REGISTRATION=False \
    ADMIN_ENABLED=True

# Missing upstream static files: base.html references
# favicon/safari-pinned-tab.svg and favicon/browserconfig.xml, but neither
# exists in the v0.26.3 tree (verified via the git tree — the favicon dir
# holds only the PNGs, .ico and site.webmanifest), so both 404 on every
# page. Ship replacements in the wrapper image at the exact static paths
# nginx serves (/yamtrack/staticfiles/ is the STATIC_ROOT): the SVG is a
# monochrome Y in upstream's pinned-tab style (black shape, color applied
# by the browser from the template's color="#181a1b"), and the XML points
# at the shipped android-chrome-192x192 tile with the same #181a1b tile
# color. Same fix shape as the Stump run's missing apple-touch-icon.
COPY static/favicon/ /yamtrack/staticfiles/favicon/

COPY entrypoint.sh /railway-entrypoint.sh
RUN chmod +x /railway-entrypoint.sh

# No Dockerfile VOLUME instruction — Railway's builder rejects it
# ("docker VOLUME ... is not supported, use Railway Volumes"). The volume
# is attached by the deploy at /yamtrack/db (see railway.json).

# The upstream entrypoint listens on YAMTRACK_INTERNAL_PORT (mapped from
# Railway's PORT by the wrapper entrypoint); when PORT is unset it defaults
# to 8080 — Railway's healthcheck prober targets its default service port.
EXPOSE 8080

# Disable the image's in-container HEALTHCHECK: it probes the hardcoded
# 127.0.0.1:8000/health/ and would report unhealthy after the port remap.
# Railway probes /health/ externally (see railway.json) — that is the
# health signal that matters.
HEALTHCHECK NONE

# No CMD: the wrapper entrypoint migrates + seeds the admin, then execs
# the upstream entrypoint, which re-runs migrations, maps PUID/PGID, chowns
# the volume dirs, and starts supervisord (nginx + gunicorn + celery).
ENTRYPOINT ["/railway-entrypoint.sh"]

LABEL org.opencontainers.image.source="https://github.com/INAPP-Mobile/yamtrack"
