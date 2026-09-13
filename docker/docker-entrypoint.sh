#!/bin/sh
set -e

APP_ENV="${APP_ENV:-prod}"
PORT="${PORT:-8080}"
DB_TIMEOUT="${DB_TIMEOUT:-60}"

cd /app

# 1) Refuser toute base "locale" : en production la base doit être EXTERNE.
case "${DATABASE_URL-}" in
    "" | *"@127.0.0.1"* | *"@localhost"*)
        echo "[entrypoint] ERREUR : DATABASE_URL n'est pas défini pour APP_ENV=$APP_ENV." >&2
        echo "[entrypoint] L'image chute sur le .env commité (mysql://root:@127.0.0.1:3306/masuperagence)," >&2
        echo "[entrypoint] injoignable depuis le cloud et interdit en production." >&2
        echo "[entrypoint] Définissez DATABASE_URL vers votre MySQL externe, ex :" >&2
        echo "[entrypoint]   DATABASE_URL=mysql://user:pass@hote:3306/nom_base" >&2
        exit 1
        ;;
esac

# 2) Attendre que la base externe soit joignable (Doctrine teste la connexion).
echo "[entrypoint] Attente de la base de données (au plus ${DB_TIMEOUT}s)..." >&2
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

# 3) Migrations (no-op si déjà synchronisé).
php bin/console doctrine:migrations:migrate --env="$APP_ENV" --no-interaction --allow-no-migration

# 4) Démarrer Symfony sur 0.0.0.0:$PORT.
echo "[entrypoint] Démarrage de Symfony (php -S) sur 0.0.0.0:${PORT} (APP_ENV=$APP_ENV)." >&2
exec php -S 0.0.0.0:"${PORT}" -t public public/router.php