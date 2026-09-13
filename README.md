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
- [Déploiement (Docker / Render)](#déploiement-docker--render)
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

## Déploiement (Docker / Render)

Le dépôt contient un `Dockerfile` multi-stage conçu pour Render (ou tout hôte Docker) :
installation Composer **sans** deps de dev, build Encore, puis image d'exécution légère
qui lance `php -S 0.0.0.0:$PORT -t public public/router.php`.

### Construire et tester localement

```bash
docker build -t masuperagence:test .

# Lancer le conteneur en se branchant sur le MySQL local (Mac : host.docker.internal) :
docker run --rm -p 8080:8080 \
  -e PORT=8080 \
  -e APP_ENV=prod \
  -e APP_DEBUG=0 \
  -e APP_SECRET="$(php -r 'echo bin2hex(random_bytes(32));')" \
  -e DATABASE_URL=mysql://root:@host.docker.internal:3306/masuperagence \
  -e MAILER_DSN=null://null \
  masuperagence:test
# → http://127.0.0.1:8080  (les migrations sont exécutées au démarrage)
```

### Tout en un seul conteneur (app + MySQL) pour démarrer vite

Le dépôt propose aussi un mode « mon conteneur unique » via `compose.yaml` :
l'application **et** un serveur MySQL (MariaDB 11, drop-in de MySQL 8 pour ce projet :
plateforme Doctrine `mysql`, `utf8mb4`, requêtes `MEMBER OF`) tiennent dans la même image,
construite avec un stage `standalone` du `Dockerfile`.

```bash
docker compose up --build
# → http://127.0.0.1:8080
```

Au premier démarrage, la base est créée, les migrations sont appliquées et les fixtures
de démo sont chargées automatiquement si la base est vide (100 biens + admin **`demo` / `demo`**).
Les données persistent dans le volume Docker `db_data` (restart sans perte).

Réglages utiles (`compose.yaml`) :

- `LOAD_FIXTURES` : `auto` (défaut, charge la démo si base vide), `1` (recharge à chaque
  démarrage), `0` (jamais).
- `DATABASE_URL`, `MYSQL_DATABASE`, `MYSQL_USER`, `MYSQL_PASSWORD` : connexion interne
  (`127.0.0.1:3306` dans le conteneur) — rien d'externe à installer.

> Ce mode est réservé au dev/démo local. En production (Render) on garde le stage `runtime`
> du `Dockerfile` avec une base MySQL externe.

### Variables d'environnement (à définir sur l'hébergeur)

`APP_ENV=prod`, `APP_DEBUG=0`, `APP_SECRET` (secret aléatoire, jamais en clair dans Git),
`DATABASE_URL`, `MAILER_DSN`, et `PORT` (injecté automatiquement par Render).

### Base de données sur Render

Render ne fournit **pas** de MySQL managé, seulement du Postgres managé. Ce projet est
intentionnellement MySQL (migrations et requêtes `MEMBER OF` spécifiques) — il ne faut pas
migrer vers le Postgres de Render. Utilise un MySQL externe (ex. Clever Cloud,
TiDB Cloud Serverless, Aiven) et renseigne son `DATABASE_URL`.

### Uploads d'images admin (Vich)

Le système de fichiers du conteneur Render est **éphémère** : les images uploadées depuis
le back-office sont perdues à chaque redéploiement/redémarrage. L'affichage public utilise
des images externes (Lorem Picsum via `Property::getImageUrl()`), donc la vitrine n'est pas
impactée ; seule l'upload admin est non persistante (pas de stockage objet type S3 pour l'instant).

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
public/                    # index.php, router.php, build/, assets/images/properties/
config/                    # bundles, packages/{dev,prod,test}, routes
docker/                    # Entrypoints (Render + conteneur unique), php.ini de prod, .env.example
compose.yaml               # « Un seul conteneur » : app + MySQL (stage standalone du Dockerfile)
translations/              # forms.fr.yaml, KnpPaginatorBundle.fr.yml
```

## Points particuliers

- **Serveur intégré PHP** : toujours démarrer avec `-t public` **et** `public/router.php`.
  Sans it, les routes profondes et le statique cassent. Le routeur force
  `$_SERVER['SCRIPT_FILENAME']` vers `index.php` (obligatoire pour Symfony Runtime).
- **Docker** : l'image d'exécution utilise le même serveur intégré `php -S` + `router.php`.
  Le port vient de `$PORT` (Render). `public/build/` est généré dans l'image (non versionné).
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