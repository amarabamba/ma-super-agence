# syntax=docker/dockerfile:1
#
# Image "Mon Agence" — Symfony 8.1 sur PHP 8.5 (alpine).
#
# Stages :
#   composer-deps-dev  — installs dev dependencies (fixtures bundle, faker, ...)
#   composer-deps      — installs ONLY production dependencies
#   assets             — builds the frontend (Encore) into /app/public/build
#   production         — the production image (Symfony, NO MariaDB embedded)
#   standalone         — production + dev vendor (local dev, used by compose.yaml)
#
# CRITIQUE : le DERNIER stage est un alias vide de `production`.
# « docker build . » (sans --target) produit donc TOUJOURS l'image de
# production, y compris depuis Render/Railway/GitHub Actions.
# Le stage dev n'est jamais construit par défaut.

# ---------------------------------------------------------------------------
# 1. Base PHP avec les extensions de production
# ---------------------------------------------------------------------------
FROM php:8.5-cli-alpine AS php-base

# opcache est compilé DANS l'image officielle PHP : pas de docker-php-ext-install,
# il est simplement activé via docker/php/prod.ini (opcache.enable_cli=1).
RUN apk add --no-cache --virtual .build-deps $PHPIZE_DEPS \
        icu-dev libpng-dev libjpeg-turbo-dev libwebp-dev freetype-dev libzip-dev \
    && apk add --no-cache \
        icu-libs libpng libjpeg-turbo libwebp freetype libzip \
    && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install -j2 gd intl pdo_mysql zip \
    && apk del .build-deps

# ---------------------------------------------------------------------------
# 2. Dépendances de production (composer, --no-dev)
# ---------------------------------------------------------------------------
FROM php-base AS composer-deps

RUN apk add --no-cache git
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /app
ENV COMPOSER_ALLOW_SUPERUSER=1

COPY composer.json composer.lock ./
RUN composer install --no-dev --optimize-autoloader --no-interaction --no-scripts

# ---------------------------------------------------------------------------
# 3. Dépendances dev (uniquement pour la cible standalone)
# ---------------------------------------------------------------------------
FROM php-base AS composer-deps-dev

RUN apk add --no-cache git
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /app
ENV COMPOSER_ALLOW_SUPERUSER=1

COPY composer.json composer.lock ./
RUN composer install --no-interaction --no-scripts

# ---------------------------------------------------------------------------
# 4. Build des assets frontend (Encore -> public/build)
# ---------------------------------------------------------------------------
FROM node:20-alpine AS assets

WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY webpack.config.js ./
COPY assets ./assets
RUN mkdir -p public && npm run build

# ---------------------------------------------------------------------------
# 5. Production
# ---------------------------------------------------------------------------
FROM php-base AS production

RUN addgroup -S app && adduser -S app -G app

WORKDIR /app

# La config applicative COMMITÉE (le .env est nécessaire au boot de Symfony ;
# les variables cloud priment en runtime, voir docker-entrypoint.sh)
COPY . .

# Vendors + assets construits DANS l'image (jamais ceux de la machine hôte)
COPY --from=composer-deps /app/vendor ./vendor
COPY --from=assets /app/public/build ./public/build

# Conf PHP + entrypoint
COPY docker/php/prod.ini /usr/local/etc/php/conf.d/zz-prod.ini
COPY docker/docker-entrypoint.sh /usr/local/bin/docker-entrypoint
RUN chmod +x /usr/local/bin/docker-entrypoint \
    && chown -R app:app /app

USER app

ENV APP_ENV=prod \
    APP_DEBUG=0

EXPOSE 8080

ENTRYPOINT ["docker-entrypoint"]

# ---------------------------------------------------------------------------
# 6. Standalone (DEV LOCAL via docker compose — JAMAIS par défaut)
#    MariaDB n'est PAS dans cette image : c'est le service `db` de compose.yaml.
# ---------------------------------------------------------------------------
FROM production AS standalone

USER root
COPY --from=composer-deps-dev /app/vendor /app/vendor
COPY docker/docker-entrypoint-standalone.sh /usr/local/bin/docker-entrypoint-standalone
RUN chmod +x /usr/local/bin/docker-entrypoint-standalone \
    && chown -R app:app /app/vendor
USER app

# Installe les assets des bundles (profiler/web profiler, dev) dans public/
RUN php bin/console assets:install public --no-interaction

ENTRYPOINT ["docker-entrypoint-standalone"]

# ---------------------------------------------------------------------------
# 7. CIBLE PAR DÉFAUT = PRODUCTION
# ---------------------------------------------------------------------------
FROM production