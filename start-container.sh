#!/bin/bash
set -e

# ── Railway (Railpack / FrankenPHP) ──────────────────────────────────────────
# Déploiement SANS Docker. Railpack détecte ce fichier à la racine et remplace
# son start-container.sh par défaut : on exécute les migrations, puis on démarre
# le serveur FrankenPHP (Caddyfile fourni par Railpack, racine web /app/public
# via la variable RAILPACK_PHP_ROOT_DIR).

echo "Running database migrations ..."
php bin/console doctrine:migrations:migrate --env="${APP_ENV:-prod}" --no-interaction --allow-no-migration

echo "Starting FrankenPHP server ..."
docker-php-entrypoint --config /Caddyfile --adapter caddyfile 2>&1