# Mon Agence

Application web d'agence immobilière en français : liste des biens, recherche par critères,
fiche détail avec formulaire de contact, et back-office d'administration (CRUD biens et options).

Projet personnel d'apprentissage Symfony, initialement construit en suivant le tutoriel de
[Grafikart](https://grafikart.fr/tutoriels/presentation-1064), migré depuis Symfony 4.x vers
**Symfony 8.1** et PHP 8.4+.

> Dépôt pédagogique et volontairement simple — n'y ajoute pas de complexité inutile.

## Sommaire

- [Fonctionnalités](#fonctionnalités)
- [Stack technique](#stack-technique)
- [Prérequis](#prérequis)
- [Installation](#installation)
- [Configuration de l'environnement](#configuration-de-lenvironnement)
- [Base de données](#base-de-données)
- [Lancement en local](#lancement-en-local)
- [Développement local avec Docker](#développement-local-avec-docker)
- [Déploiement (Docker)](#déploiement-docker-)
- [Tests](#tests)
- [Commandes utiles](#commandes-utiles)
- [Structure du projet](#structure-du-projet)
- [Points particuliers](#points-particuliers)

## Fonctionnalités

- Page d'accueil : 4 derniers biens disponibles (`sold = false`)
- Liste des biens paginée (12 par page) avec recherche (prix max, surface min, options)
- Fiche bien : galerie d'image (Liip Imagine), caractéristiques, options, formulaire de contact
  (envoi d'email via Symfony Mailer), redirection 301 si le slug de l'URL est incorrect
- Back-office `/admin` (réservé aux admins) : CRUD des biens (avec upload d'image Vich Uploader),
  CRUD des options, liaison ManyToMany biens ↔ options

## Stack technique

| Couche | Technologie |
|---|---|
| Backend | PHP ≥ 8.4, Symfony 8.1 (FrameworkBundle, Security, Form, Validator, Mailer, Twig) |
| ORM | Doctrine ORM 3, migrations Doctrine, fixtures |
| Base de données | MySQL 8 (`utf8mb4`) |
| Images | Vich Uploader 3 (upload) + Liip Imagine (+GD) (filtres `thumb`/`medium`) |
| Frontend | Webpack Encore 5, jQuery 3.7.1, select2 4.1, Bootstrap 4.3.1 (CDN) |
| Pagination | KnpPaginatorBundle |
| Tests | PHPUnit 11.5 (installé, aucun test pour l'instant) |

Versions de référence des bundles sensibles : `doctrine-bundle ^3.3`, `doctrine/orm ^3.4`,
`doctrine-migrations-bundle ^4`, `monolog-bundle ^4.1`, `vich/uploader-bundle ^3`,
`knp-paginator-bundle ^6.11`, `liip/imagine-bundle ^2.17`, `webpack-encore-bundle ^2.4`.

## Prérequis

- PHP ≥ 8.4 (développé sous PHP 8.5 via Homebrew)
- Composer 2
- Node.js ≥ 20 + npm
- MySQL 8 (serveur local)
- Docker (optionnel) : uniquement pour le [dev local Docker](#développement-local-avec-docker)
  ou le [déploiement](#déploiement-docker-)

## Installation

```bash
git clone git@github.com:amarabamba/ma-super-agence.git
cd ma-super-agence

composer install
npm install
```

### Build des assets

```bash
npm run build          # build de production (fichiers hashés, requis avant le mode prod)
# ou en développement, si tu modifies le front :
npm run dev            # build une fois
npm run watch          # build + re-build à chaque modification
npm run dev-server     # serveur Encore sur :8080 (rechargement à chaud)
```

## Configuration de l'environnement

Copie les valeurs de `.env` (déjà versionné, valeurs de dev uniquement) et surcharge
localement via `.env.local` (non versionné) si besoin :

```dotenv
APP_ENV=dev
APP_SECRET=<secret de dev>
DATABASE_URL=mysql://root:@127.0.0.1:3306/masuperagence
MAILER_DSN=null://null
VAR_DUMPER_SERVER=127.0.0.1:9912
```

- `MAILER_DSN=null://null` : sink volontaire en dev — les emails sont envoyés mais perdus (pas de crash).
- Ne mets **jamais** de secrets de production dans les fichiers versionnés.

## Base de données

```bash
# Créer la base (une fois)
mysql -u root -e "CREATE DATABASE masuperagence CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"

# Schéma (6 migrations existantes)
php bin/console doctrine:migrations:migrate
php bin/console doctrine:schema:validate   # doit afficher "synchronisées"

# Données de démo (100 biens faker + utilisateur admin)
php bin/console doctrine:fixtures:load
```

Accès admin après fixtures : **`demo` / `demo`**.

## Lancement en local

Méthode recommandée (serveur embarqué PHP + routeur — indispensable pour servir le statique
et les images Liip) :

```bash
php -S 127.0.0.1:8000 -t public public/router.php
# ou via npm :  npm run serve   (port 1212)
```

Puis ouvrir <http://127.0.0.1:8000>.

Si le backend tourne avec `npm run dev-server` actif, les assets sont chargés depuis le
dev-server Encore (:8080) automatiquement.

### Depuis IntelliJ / PhpStorm

1. `Run` → `Edit Configurations…` → `+` → **PHP Built-in Web Server**
2. Host `127.0.0.1`, Port `8000`, Document root `…/public`
3. Cocher **Use router script** → `…/public/router.php`
4. Lancer puis ouvrir <http://127.0.0.1:8000>

Alternative : les scripts npm (`dev`, `dev-server`, `watch`, `build`, `serve`) sont
auto-importés par PhpStorm dans les run configurations.

> Note : l'interpréteur PHP local n'a pas xdebug chargé — pas de débogage pas-à-pas
> via le serveur intégré.

## Développement local avec Docker

Une stack de développement isolée est fournie (`compose.yaml` + cible `standalone` du
`Dockerfile`) : Symfony + MariaDB, sans rien installer dans votre système.

```bash
docker compose up --build
# app sur http://127.0.0.1:8080
```

Au premier démarrage : migrations + fixtures (**100 biens faker** + utilisateur admin)
chargées automatiquement dans la base du conteneur `db`.

- `LOAD_FIXTURES=auto` (défaut) : charge les fixtures uniquement si la table `property` est vide.
  Passez `LOAD_FIXTURES=1` (toujours) ou `LOAD_FIXTURES=0` (jamais).
- Arrêt : `docker compose down` (les données de `db` sont dans un volume, conservées).
- Réinitialiser la base : `docker compose down -v && docker compose up --build`.
- Mémoire du serveur intégré PHP partagée avec le style du runway local, mais aucun
  `php`/`composer`/`node`/`mysql` n'est requis sur la machine hôte.

## Déploiement (Docker)

Déploiement **containerisé** : l'image de production est construite par `Dockerfile`
(pas de Railpack/FrankenPHP) et peut être poussée et déployée sur **Railway**, **Render**
ou toute plateforme qui exécute une image Docker.

```text
GitHub → Docker build → Railway/Render → image Symfony de production → MySQL externe (ex. Aiven)
```

Le `Dockerfile` est multi-stage et la **cible par défaut de `docker build .` est
l'image de production** (le dernier stage, un alias vide, force `production`).

### Image de production

```bash
docker build -t ma-super-agence .
```

Cette image contient uniquement Symfony en `APP_ENV=prod` : extensions PHP
(`gd`, `intl`, `pdo_mysql`, `zip`, `mbstring`, `opcache`), vendor de production,
assets frontend compilés, **aucune base de données embarquée** (pas de MySQL/MariaDB
dans l'image) et aucun outil de build (node, composer).

### Démarrage et migrations

L'entrypoint (`docker/docker-entrypoint.sh`) fait, à chaque démarrage du conteneur :

1. **Refuse une base "locale"** : `DATABASE_URL` doit pointer vers un MySQL externe —
   les URL `@localhost` / `@127.0.0.1` sont bloquées en production.
2. Attend que la base soit joignable (jusqu'à `DB_TIMEOUT=60` s).
3. Applique `doctrine:migrations:migrate --allow-no-migration`.
4. Démarre Symfony : `php -S 0.0.0.0:$PORT -t public public/router.php`.

### Variables d'environnement (cloud)

| Variable | Valeur à renseigner |
|---|---|
| `APP_ENV` | `prod` |
| `APP_DEBUG` | `0` |
| `APP_SECRET` | une chaîne aléatoire (`php -r 'echo bin2hex(random_bytes(32)), PHP_EOL;'`) |
| `DATABASE_URL` | URL du MySQL externe (ex. Aiven) — cf. `.env.example` |
| `MAILER_DSN` | `null://null` en attendant, ou un DSN SMTP |
| `PORT` | injecté automatiquement par Railway/Render |

Les variables cloud priment sur le `.env` commité (qui est embarqué dans l'image car
requis par le boot Symfony) — aucun secret dans Git.

> Les fixtures de démo (100 biens faker + utilisateur admin) sont en `require-dev` :
> elles ne sont **pas** présentes dans l'image de production. Pour créer un utilisateur
> admin, lancez une fois : `docker exec <conteneur> php bin/console doctrine:fixtures:load --env=prod`
> (ou créez le compte manuellement en base).

### Base de données

Le projet reste sur **MySQL/MariaDB**. Railway ne fournit pas de MySQL managé → utilisez
un MySQL externe (ex. Aiven, gratuit) et renseignez son `DATABASE_URL`
(`mysql://user:pass@host:3306/ma_super_agence`). Ne portez pas vers PostgreSQL :
les migrations et les requêtes `MEMBER OF` sont spécifiques à MySQL.

### Images

L'affichage public utilise des images externes **Lorem Picsum**
(`Property::getImageUrl()`) — aucun stockage de fichiers requis. Les uploads Vich du
back-office reposent sur le filesystem éphémère du conteneur (perdus à chaque
redéploiement), sans impact sur la vitrine.

## Tests

Aucun test pour l'instant (`tests/` est vide et il n'y a pas de `phpunit.xml.dist`).
PHPUnit 11.5 est installé :

```bash
vendor/bin/phpunit
```

> Utilise `vendor/bin/phpunit` et non `bin/phpunit` (ce dernier déclencherait un
> téléchargement PHPUnit). L'environnement de test n'a pas de `DATABASE_URL` dédié :
> il réutilise la base MySQL de dev — fais attention avant tout test qui écrit en base.

## Commandes utiles

```bash
# Console / cache
php bin/console cache:clear                    # --env=prod / --env=test
php bin/console debug:router

# Base de données
php bin/console doctrine:migrations:migrate
php bin/console doctrine:fixtures:load
php bin/console doctrine:schema:validate
php bin/console doctrine:migrations:list

# Qualité
php bin/console lint:yaml config
php bin/console lint:twig templates

# Health
php bin/console about
```

## Structure du projet

```
src/
├── Controller/            # Home, Property, Security (+ Admin/, Listener/)
├── DataFixtures/          # faker properties (100), user demo/demo
├── Entity/                # Property, Option, User (ORM) + Contact, PropertySearch (DTOs)
├── Form/                  # Contact, Option, PropertySearch, Property
├── Migrations/            # 6 migrations (2019), namespace DoctrineMigrations
├── Notification/          # ContactNotification (Symfony Mailer)
└── Repository/            # PropertyRepository (visible/search/filter queries)
templates/                 # base + admin/, emails/, pages/, property/, security/
assets/                    # js/app.js + css/app.css (Encore entry 'app')
docker/                    # entrypoint de prod/dev + php/prod.ini
public/                    # index.php, router.php, build/, assets/images/properties/
config/                    # bundles, packages/{dev,prod,test}, routes
Dockerfile                 # image multi-stage — cible par défaut = production
compose.yaml               # dev local : app (standalone) + service db (mariadb)
translations/              # forms.fr.yaml, KnpPaginatorBundle.fr.yml
```

## Points particuliers

- **Serveur intégré PHP** : toujours démarrer avec `-t public` **et** `public/router.php`.
  Sans it, les routes profondes et le statique cassent. Le routeur force
  `$_SERVER['SCRIPT_FILENAME']` vers `index.php` (obligatoire pour Symfony Runtime).
- **Config auto-générée** : `config/reference.php` est régénéré par les commandes console
  (gitignoré) — supprime-le s'il apparaît.
- **Vich Uploader 3** : les attributs utilisent le namespace `Mapping\Attribute`
  (`#[Vich\Uploadable]`), pas `Annotation`. Les uploads atterrissent dans
  `public/assets/images/properties` (gitignorés, seul `placeholder.jpg` est versionné).
- **jQuery** : chargé par CDN dans `base.html.twig` ; `webpack.config.js` expose l'externe
  `jquery → jQuery` (à conserver avec `.autoProvidejQuery()` quand tu modifies le JS).
- **Localisation** : locale `fr`, formulaires en `translation_domain: 'forms'` →
  `translations/forms.fr.yaml`.

## Crédits

Projet personnel d'apprentissage basé sur le tutoriel Symfony de Grafikart, migré et
entretenu par Amara Bamba. Ce dépôt n'est pas affilié à Grafikart.

## Licence

MIT — voir [LICENSE](LICENSE).