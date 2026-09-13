#!/bin/sh
set -eu

cd /app

APP_ENV=${APP_ENV:-prod}
PORT=${PORT:-8080}
DATADIR=/var/lib/mysql
SOCKET=/run/mysqld/mysqld.sock
MYSQL_DATABASE=${MYSQL_DATABASE:-masuperagence}
MYSQL_USER=${MYSQL_USER:-app}
MYSQL_PASSWORD=${MYSQL_PASSWORD:-app}

# Sans DATABASE_URL explicite, on se branche sur le MySQL du conteneur avec le
# compte applicatif créé ci-dessous — jamais sur le .env dev (root@127.0.0.1).
if [ -z "${DATABASE_URL:-}" ]; then
    export DATABASE_URL="mysql://$MYSQL_USER:$MYSQL_PASSWORD@127.0.0.1:3306/$MYSQL_DATABASE"
fi

mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld

# Premier démarrage : initialiser le datadir (persisté dans le volume db_data)
if [ ! -d "$DATADIR/mysql" ]; then
    echo "[entrypoint] Initialisation du datadir MariaDB..."
    mariadb-install-db -q --user=mysql --datadir="$DATADIR" --auth-root-authentication-method=normal
fi

echo "[entrypoint] Démarrage de MariaDB..."
# Pas de --log-error : MariaDB crée /var/log/mysql/error.log (config Debian).
mariadbd --user=mysql --datadir="$DATADIR" \
    --socket="$SOCKET" --port=3306 --bind-address=127.0.0.1 &

i=0
until mariadb --socket="$SOCKET" -uroot -e 'SELECT 1' >/dev/null 2>&1; do
    i=$((i + 1))
    if [ "$i" -gt 60 ]; then
        echo "[entrypoint] MariaDB ne démarre pas (voir logs ci-dessus)" >&2
        exit 1
    fi
    sleep 1
done

echo "[entrypoint] Création de la base '$MYSQL_DATABASE' et de l'utilisateur '$MYSQL_USER'..."
mariadb --socket="$SOCKET" -uroot <<SQL
CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$MYSQL_USER'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD';
CREATE USER IF NOT EXISTS '$MYSQL_USER'@'127.0.0.1' IDENTIFIED BY '$MYSQL_PASSWORD';
GRANT ALL PRIVILEGES ON \`$MYSQL_DATABASE\`.* TO '$MYSQL_USER'@'localhost';
GRANT ALL PRIVILEGES ON \`$MYSQL_DATABASE\`.* TO '$MYSQL_USER'@'127.0.0.1';
FLUSH PRIVILEGES;
SQL

php bin/console doctrine:migrations:migrate --env="$APP_ENV" --no-interaction --allow-no-migration

case "${LOAD_FIXTURES:-auto}" in
    0|false|no|off)
        ;;
    1|true|yes|on)
        # DoctrineFixturesBundle n'est activé qu'en dev/test (config/bundles.php),
        # d'où --env=test (même base MySQL, pas de profiler).
        php bin/console doctrine:fixtures:load --env=test --no-interaction
        ;;
    auto)
        count=$(mariadb --socket="$SOCKET" -uroot -Nse "SELECT COUNT(*) FROM \`$MYSQL_DATABASE\`.property")
        if [ "${count:-0}" = "0" ]; then
            echo "[entrypoint] Base vide : chargement des fixtures (admin demo/demo)..."
            php bin/console doctrine:fixtures:load --env=test --no-interaction
        fi
        ;;
esac

trap 'echo "[entrypoint] Arrêt de MariaDB..."; mariadb-admin --socket="$SOCKET" -uroot shutdown' TERM INT

echo "[entrypoint] Prêt → http://127.0.0.1:${PORT}"
exec php -S 0.0.0.0:${PORT} -t public public/router.php