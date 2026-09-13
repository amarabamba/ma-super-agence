#!/bin/sh
set -e

APP_ENV="${APP_ENV:-dev}"
PORT="${PORT:-8080}"
DB_TIMEOUT="${DB_TIMEOUT:-90}"
LOAD_FIXTURES="${LOAD_FIXTURES:-auto}"   # auto | 1 | 0

cd /app

if [ -z "${DATABASE_URL-}" ]; then
    # Avec compose.yaml, DATABASE_URL est fourni par le service (app -> db).
    MYSQL_USER="${MYSQL_USER:-app}"
    MYSQL_PASSWORD="${MYSQL_PASSWORD:-app}"
    MYSQL_DATABASE="${MYSQL_DATABASE:-masuperagence}"
    export DATABASE_URL="mysql://${MYSQL_USER}:${MYSQL_PASSWORD}@db:3306/${MYSQL_DATABASE}"
fi

echo "[entrypoint] Attente du service 'db' (au plus ${DB_TIMEOUT}s)..." >&2
i=0
until php bin/console doctrine:migrations:status --env="$APP_ENV" --no-interaction >/dev/null 2>&1; do
    i=$((i + 1))
    if [ "$i" -ge "$DB_TIMEOUT" ]; then
        echo "[entrypoint] La base n'est pas devenue joignable en ${DB_TIMEOUT}s." >&2
        exit 1
    fi
    sleep 1
done
echo "[entrypoint] Base de données joignable." >&2

php bin/console doctrine:migrations:migrate --env="$APP_ENV" --no-interaction --allow-no-migration

# Fixtures (dev uniquement) :
#   auto -> uniquement si la table property est absente/vide (mise en route)
#   1    -> toujours
#   0    -> jamais
if [ "$LOAD_FIXTURES" = "1" ] || {
   [ "$LOAD_FIXTURES" != "0" ] && ! php bin/console doctrine:query:sql "SELECT COUNT(*) FROM property" >/dev/null 2>&1;
}; then
    echo "[entrypoint] Chargement des fixtures (LOAD_FIXTURES=$LOAD_FIXTURES)..." >&2
    php bin/console doctrine:fixtures:load --env="$APP_ENV" --no-interaction
else
    echo "[entrypoint] Fixtures ignorées (LOAD_FIXTURES=$LOAD_FIXTURES, données présentes)." >&2
fi

exec php -S 0.0.0.0:"${PORT}" -t public public/router.php