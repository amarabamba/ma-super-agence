# syntax=docker/dockerfile:1
#
# Multi-stage build for Render (and any Docker host).
#  - composer-deps: PHP deps (no dev) + production cache
#  - assets:        Encore assets (public/build)
#  - runtime:       slim PHP image running  php -S 0.0.0.0:$PORT -t public public/router.php

#########################
# Stage 1: PHP + Composer
#########################
FROM php:8.5-cli AS composer-deps

ARG APP_ENV=prod

ENV APP_ENV=${APP_ENV} \
    APP_DEBUG=0 \
    COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_HOME=/tmp/composer

RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        unzip \
        libicu-dev \
        libzip-dev \
        libonig-dev \
        libpng-dev \
        libjpeg62-turbo-dev \
        libfreetype6-dev \
        libwebp-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install gd \
    && docker-php-ext-install intl \
    && docker-php-ext-install mbstring \
    && docker-php-ext-install zip \
    && docker-php-ext-install pdo_mysql \
    && docker-php-ext-install exif \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /app
COPY . .

# --no-scripts: cache:clear runs at build time without a database available,
# so the prod cache is built at container startup instead (see entrypoint).
RUN composer install --no-dev --no-interaction --no-progress --prefer-dist --optimize-autoloader --no-scripts \
    && composer dump-autoload --no-dev --classmap-authoritative

#########################
# Stage 2: Web assets
#########################
FROM node:20-alpine AS assets

WORKDIR /app
COPY package.json package-lock.json webpack.config.js ./
COPY assets ./assets
RUN npm ci && npm run build

#########################
# Stage 3: Runtime
#########################
FROM php:8.5-cli AS runtime

ENV APP_ENV=prod \
    APP_DEBUG=0

RUN apt-get update && apt-get install -y --no-install-recommends \
        libicu-dev \
        libzip-dev \
        libonig-dev \
        libpng-dev \
        libjpeg62-turbo-dev \
        libfreetype6-dev \
        libwebp-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install gd \
    && docker-php-ext-install intl \
    && docker-php-ext-install mbstring \
    && docker-php-ext-install pdo_mysql \
    && docker-php-ext-install exif \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY docker/php/prod.ini /usr/local/etc/php/conf.d/prod.ini

RUN useradd --create-home --shell /usr/sbin/nologin --uid 1000 app

WORKDIR /app

COPY --from=composer-deps --chown=app:app /app /app
COPY --from=assets --chown=app:app /app/public/build /app/public/build
COPY --chown=app:app docker/docker-entrypoint.sh /usr/local/bin/docker-entrypoint

RUN mkdir -p /app/var/cache /app/var/log /app/public/assets/images/properties \
    && chown -R app:app /app/var /app/public/assets/images/properties \
    && chmod +x /usr/local/bin/docker-entrypoint

USER app

EXPOSE 8080

ENTRYPOINT ["docker-entrypoint"]

#########################
# Stage 4: Mon conteneur unique (app + MySQL) pour le dev local
#########################
# Tout tient dans UN conteneur : PHP + serveur MariaDB dans la même image,
# piloté par docker/docker-entrypoint-standalone.sh. MariaDB est un drop-in
# de MySQL 8 pour ce projet (plateforme Doctrine "mysql", utf8mb4, MEMBER OF).
# Pour Render on continue d'utiliser le stage `runtime` (base MySQL externe).
FROM runtime AS standalone

USER root

# L'exécution tourne en root : simple pour piloter mysqld et le serveur PHP
# dans un conteneur de dev local (pas de multi-utilisateurs ici).
RUN apt-get update && apt-get install -y --no-install-recommends \
        unzip \
        mariadb-server \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Besoin de composer pour ajouter les packages de DEV (DoctrineFixturesBundle,
# Faker...) par-dessus le vendor de production : c'est ce qui permet le chargement
# automatique des données de démo (admin demo/demo) dans le conteneur unique.
# --no-scripts : les auto-scripts (cache:clear) tentent de contacter la base,
# pas disponible pendant le build — le cache est construit au démarrage.
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
RUN composer install --no-interaction --no-progress --prefer-dist --optimize-autoloader --no-scripts

COPY --chown=root:root docker/docker-entrypoint-standalone.sh /usr/local/bin/docker-entrypoint-standalone
RUN chmod +x /usr/local/bin/docker-entrypoint-standalone

ENV MYSQL_DATABASE=masuperagence \
    MYSQL_USER=app \
    MYSQL_PASSWORD=app \
    LOAD_FIXTURES=auto

ENTRYPOINT ["docker-entrypoint-standalone"]