#!/bin/sh
set -eu

cd /app

APP_ENV=${APP_ENV:-prod}
PORT=${PORT:-8080}

php bin/console doctrine:migrations:migrate --env="$APP_ENV" --no-interaction --allow-no-migration

exec php -S 0.0.0.0:${PORT} -t public public/router.php