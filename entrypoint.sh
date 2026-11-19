#!/bin/sh
# Yamtrack on Railway.
#
# - Maps Railway's injected PORT onto nginx via YAMTRACK_INTERNAL_PORT
#   (the upstream entrypoint rewrites both nginx confs with sed on every
#   boot). When PORT is unset it defaults to 8080 — Railway's healthcheck
#   prober targets its default service port. Never 23847: reserved for
#   gunicorn inside the container (upstream entrypoint refuses it).
# - Derives CSRF trusted origins + allowed hosts from the live
#   RAILWAY_PUBLIC_DOMAIN via URLS (upstream's shortcut for both settings;
#   SECURE_PROXY_SSL_HEADER is already set upstream). Never bake a
#   ${{RAILWAY_PUBLIC_DOMAIN}} template expression — it resolves to a bare
#   https:// on first deploy, before any domain exists (same shape as the
#   Spliit BASE_URL / LLDAP LLDAP_HTTP_URL lessons).
# - Composes REDIS_URL in shell from the single-ref REDIS_HOST variable
#   (${{redis.RAILWAY_PRIVATE_DOMAIN}} from the redis companion) — never
#   compose several ${{...}} refs inside one variable value.
# - Seeds the admin account (admin / YAMTRACK_ADMIN_PASSWORD, email
#   admin@yamtrack.local) with Django's createsuperuser --noinput, exactly
#   once per volume: the command fails when the user already exists, and
#   that failure is swallowed. Upstream ships NO admin account and open
#   registration; this wrapper closes registration (REGISTRATION=False is
#   baked in the Dockerfile) so the seeded admin is the only account.
# - Delegates to the upstream entrypoint (/entrypoint.sh), which re-runs
#   migrations, maps PUID/PGID onto the abc user, chowns /yamtrack + db +
#   staticfiles, and execs supervisord (nginx + gunicorn + celery worker).
set -e

export YAMTRACK_INTERNAL_PORT="${PORT:-8080}"

if [ -z "$URLS" ] && [ -n "$RAILWAY_PUBLIC_DOMAIN" ]; then
  export URLS="https://${RAILWAY_PUBLIC_DOMAIN}"
fi

export REDIS_URL="redis://${REDIS_HOST:-localhost}:6379"

: "${SECRET:?SECRET is required (generated template variable)}"
: "${YAMTRACK_ADMIN_PASSWORD:?YAMTRACK_ADMIN_PASSWORD is required (generated template variable)}"

# Migrate first: createsuperuser needs the auth tables. Runs as root; the
# upstream entrypoint chowns the db dir to abc afterwards, so gunicorn
# (user abc) can write the SQLite file created here.
python manage.py migrate --noinput

DJANGO_SUPERUSER_USERNAME="${YAMTRACK_ADMIN_USERNAME:-admin}" \
DJANGO_SUPERUSER_EMAIL="admin@yamtrack.local" \
DJANGO_SUPERUSER_PASSWORD="$YAMTRACK_ADMIN_PASSWORD" \
python manage.py createsuperuser --noinput 2>/dev/null || true

exec /entrypoint.sh
