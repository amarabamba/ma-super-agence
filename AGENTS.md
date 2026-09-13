# AGENTS.md

Guidance for AI coding assistants working in this repository. Only facts confirmed by the
code, the configuration, or real runtime behaviour are documented here.

## Project overview

- **App**: "Mon Agence" — a French real-estate website (listings, search, contact, admin back office).
- **Origin**: personal learning project (Grafikart Symfony tutorial), intentionally kept simple — do not over-engineer.
- **Language of the app UI**: French. Locale is `fr` (`config/services.yaml`).
- **Backend**: Symfony `8.1.*`, PHP `>=8.4` (local: PHP 8.5.10 via Homebrew).
- **Database**: MySQL 8, database `masuperagence`, `utf8mb4`.
- **Frontend**: Webpack Encore 5 (npm), jQuery 3.7.1 + select2 4.1 (both also loaded from CDN), Bootstrap 4.3.1 (CDN).
- **No test suite currently** (`tests/` is empty, no `phpunit.xml.dist`).

## Stack / dependency constraints

- `symfony/*` are pinned to `8.1.*`(flex `require: "8.1.*"`). Do **not** upgrade Symfony majors casually.
- Major bundle versions that changed during the 4.x → 8.1 migration and **must be kept** on current majors:
  `doctrine-bundle ^3.3`, `doctrine/orm ^3.4.4`, `doctrine-migrations-bundle ^4.0`,
  `monolog-bundle ^4.1`, `vich/uploader-bundle ^3.0`, `knp-paginator-bundle ^6.11`,
  `liip/imagine-bundle ^2.17`, `webpack-encore-bundle ^2.4`, `phpunit/phpunit ^11.5`.
- Frontend npm: `@symfony/webpack-encore ^5.3`, `jquery ^3.7.1`, `select2 ^4.1.0-rc.0`.
- Composer `allow-plugins` is required for `symfony/flex`, `symfony/runtime`, `php-http/discovery`.

## Entry points / routing

- `public/index.php` → Symfony Runtime (`vendor/autoload_runtime.php`), `Kernel` via MicroKernelTrait.
- Routes are **PHP attributes**, auto-discovered in `config/routes.yaml` (`type: attribute`, path `../src/Controller/`).
- `config/routes/liip_imagine.yaml` loads the LiipImagineBundle routing.
- `config/routes/web_profiler.yaml` (`when@dev`) loads the profiler routing from the bundle's `.php` files.

Route map (names used with `path()`):

| Route name | Path | Action |
|---|---|---|
| `home` | `/` | latest 4 visible properties |
| `property.index` | `/biens` | paginated list (12/page) + search form |
| `property.show` | `/biens/{slug}-{id}` | detail + contact form (301 on slug mismatch) |
| `login` | `/login` | form login |
| `logout` | `/logout` | intercept by firewall |
| `admin.property.*` | `/admin(/property/...)` | CRUD properties |
| `admin.option.*` | `/admin/option(...)` | CRUD options |

## Architecture

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
public/                    # index.php, router.php, build/, asset media
config/                    # bundles, packages/{dev,prod,test}, routes
translations/              # forms.fr.yaml etc.
```

- `config/services.yaml`: autowire + autoconfigure on by default; `App\` excluded for Entity/, Migrations/, Kernel.php.
- DI: controllers use constructor injection with `readonly` promoted properties (see `AdminPropertyController`, `PropertyController`).
- Entity mapping style: **attributes** (`doctrine.yaml` → `type: attribute`), not YAML/XML/annotations.

## Domain model & DB

- `Property` (`property` table): title, description, surface, rooms, bedrooms, floor, price, heat, city,
  address, postal_code, sold, created_at, updated_at, filename (Vich image), ManyToMany `Option`.
  Unique `title`. `getSlug()` computed from title via `cocur/slugify`.
- `Option` (`option` table): name + ManyToMany with Property (inverse side).
- `User` (`user` table): username, password; `getRoles()` always returns `ROLE_ADMIN` (every user is an admin).
- `Contact`, `PropertySearch`: plain DTOs (form/validation only, **not** persisted).
- Migrations: `php bin/console doctrine:migrations:migrate`; schema is in sync, `doctrine:schema:validate` passes.

## Security

- `config/packages/security.yaml`: password hasher `auto`, entity provider on `username`, `form_login`
  (`login_path/check_path = login`), `logout` path `/logout` target `/`.
- `access_control`: `^/admin` requires `ROLE_ADMIN`.
- CSRF protection enabled (`framework.yaml`). Delete actions manually validate `isCsrfTokenValid()`.

## Images (Vich + Liip)

- **Vich Uploader v3**: namespace `Vich\UploaderBundle\Mapping\Attribute` (NOT `...\Annotation`)
  → `#[Vich\Uploadable]`, `#[Vich\UploadableField(mapping: 'property_image', fileNameProperty: 'filename')]`.
- Mapping `property_image`: uploads to `public/assets/images/properties`, `UniqidNamer`.
- Runtime uploads are gitignored; only `placeholder.jpg` is committed (also referenced by fixtures).
- `Assert\Image` requires `mimeTypes: ['image/jpeg']` as an **array** (string is rejected by the validator in v8).
- **Liip Imagine** (`gd` driver): filters `thumb` (360×230) and `medium` (800×530), outbound. Cache dir `public/media/cache/` (gitignored).
- `ImageCacheSubscriber` (`src/Controller/Listener/`): doctrine listener on preRemove/preUpdate that
  purges the liip cache for a property's image. Registered via `#[AsDoctrineListener]`, no service wiring needed.

## Frontend (Encore 5)

- Single entry `app` from `assets/js/app.js`. Build output: `public/build/` (gitignored).
- `webpack.config.js`: `.autoProvidejQuery()` **and** `.addExternals({ jquery: 'jQuery' })` — jQuery is
  loaded from CDN in `base.html.twig` and exposed globally by `app.js`
  (`global.$ = global.jQuery = $`). Keep this pairing when working on JS.
- `app.js` applies `select2()` to **every** `<select>` and handles the contact-form toggle
  (`#contactButton` / `#contactForm`).
- CDN assets in `base.html.twig`: Bootstrap 4.3.1, select2 4.0.10 CSS, jQuery 3.7.1, popper 1.14.7.
- `encore_entry_link_tags/script_tags('app')` in `base.html.twig`.
- In dev, `npm run dev-server` (Encore dev-server, port 8080) rewrites `entrypoints.json` to `localhost:8080`
  URLs — the PHP server then serves those via its router. Plain `npm run dev` writes normal hashed paths.

## Working commands

```bash
# Install
composer install
npm install

# Assets
npm run build          # production build (hashed files) — required before serving in prod mode
npm run dev            # build once
npm run watch          # build + watch
npm run dev-server     # Encore dev server on :8080 (hot rebuild + serving)
npm run serve          # shortcut: php -S 127.0.0.1:1212 -t public public/router.php

# Serve the app (PHP ≥ 8.4 built-in server + router)
php -S 127.0.0.1:8000 -t public public/router.php

# Console
php bin/console cache:clear                 # per env: --env=prod / --env=test
php bin/console doctrine:migrations:migrate
php bin/console doctrine:fixtures:load      # 100 faker properties + user demo/demo
php bin/console doctrine:schema:validate
php bin/console lint:yaml config
php bin/console lint:twig templates
php bin/console about

# Tests (none exist yet) — use the installed PHPUnit, not the bridge download:
vendor/bin/phpunit
```

Admin credentials after fixtures: **`demo` / `demo`**.

## Environment & configuration

- `.env` is **committed** (it only holds dev defaults). Secret/local overrides go to `.env.local` (gitignored).
  Never put production secrets in committed files.
- Keys in `.env`: `APP_ENV`, `APP_SECRET`, `DATABASE_URL=mysql://root:@127.0.0.1:3306/masuperagence`,
  `MAILER_DSN=null://null`, `VAR_DUMPER_SERVER=127.0.0.1:9912`.
- Mailer: `MAILER_DSN=null://null` is an intentional dev sink (mails are dropped, no crash).
  `config/packages/mailer.yaml` maps `framework.mailer.dsn` from the env var.
- `APP_ENV=dev` default; profiles `dev/prod/test` all compile (`cache:clear` works for all three).
- Test env (`config/packages/test/`): `framework.test: true`, session via `session.storage.factory.mock_file`,
  profiler/debug/monolog enabled. `.env.test` has **no** `DATABASE_URL` → the test env uses the dev MySQL
  database unless you override it — be careful before running data-mutating tests.
- Locale `fr`, translation fallback `fr`. Forms use `translation_domain: 'forms'` →
  `translations/forms.fr.yaml`.

## Known pitfalls (confirmed)

- **PHP built-in server**: must be started with `-t public` and `public/router.php`. Plain `php -S`
  without the router breaks deep routes/static assets; a router must set `$_SERVER['SCRIPT_FILENAME']`
  to `index.php` before `require` (Symfony Runtime fatal) — do not "simplify" it away.
- `config/reference.php` is **auto-generated** by console commands → now gitignored; delete it if it reappears.
- `doctrine-bundle` 3.x removed `orm.auto_generate_proxy_classes`, `orm.enable_lazy_ghost_objects`,
  `orm.report_fields_where_declared` — do not re-add them.
- Doctrine mapping type is `attribute`; keep attributes elsewhere too (routes, Vich, listeners) for consistency.
- `swiftmailer`/`sensio_framework_extra`/`WebServerBundle` are gone — `MAILER_URL`, annotations routes,
  `@Route`, `@Template` etc. are obsolete.
- Migrations expect MySQL (`instanceof AbstractMySQLPlatform` guard) — keep them MySQL-compatible.

## Verification checklist before finishing a task

1. `composer install` clean (no PHP/plugin warnings).
2. `php bin/console lint:yaml config` and `php bin/console lint:twig templates` pass.
3. `php bin/console cache:clear` on `dev`, `prod`, `test`.
4. `php bin/console doctrine:schema:validate` still passes if the mapping changed.
5. Smoke-test through the router (see "Working commands") every route touched (`/`, `/biens`,
   `/biens/{slug}-{id}`, `/login`, `/admin`, liip image URLs).

## Git / repo hygiene

- Commit only intended files. Never commit: `vendor/`, `node_modules/`, `var/`, `public/build/`,
  `public/media/cache/`, `.env.local*`, uploaded images (gitignored except `placeholder.jpg`),
  `config/reference.php`.
- `composer.lock` and `package-lock.json` are committed (dependencies reproducible).