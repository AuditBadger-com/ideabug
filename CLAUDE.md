# ideabug

Self-hosted feedback platform with an embeddable widget for announcements, bug reports, feature requests, voting, and a public roadmap/changelog. Pre-1.0. Host apps embed `script.js`; anonymous identity is the default and RS256 JWT optionally identifies users. The widget polls `/api/v1/state` and loads tab content on demand.

## Stack
- Rails 8.1.4.1 (Ruby 4.0.9, Bundler 4.0.22) + Postgres 18 + Redis 8
- Hotwire (Turbo + Stimulus, importmap-rails), Tailwind + DaisyUI, ActionText/Lexxy
- Assets: Tailwind 3.4 + DaisyUI 4, Node 24.21.0 + Yarn 1.22.22; keep DaisyUI in production `dependencies` for Heroku builds
- Auth: cookie sessions for admin (`Authentication`), anonymous IDs + optional RS256 JWT for widget API (`WidgetAuthenticatable`)
- Serializers: Blueprinter (`app/blueprints/`)
- Tests: Minitest + shoulda + capybara/selenium + factory_bot. **No RSpec** despite stray `.rspec` file.
- Lint: Standard via rubocop (`.rubocop.yml`), TargetRubyVersion 4.0, line length 100
- Dev env: dip + Docker (`dip.yml`, `.dockerdev/`); plain `bin/dev` (Procfile.dev → puma:3001 + tailwind watch) also works

## Domain (see `db/schema.rb`)
- `User` + `Session` — admin login (email/password, bcrypt)
- `Contact` — end-user keyed by `anonymous_id` or `external_id` (JWT `id`); has `info_payload`, `segments_payload`, `announcements_opted_out`, and `last_seen_at`
- `Segment` / `SegmentValue` — targeting taxonomy; HABTM with Contact and Announcement
- `Announcement` — `has_rich_text :content`, HABTM `segment_values`; `AnnouncementRead` join tracks per-contact read state
- `Ticket` — enums `status` (new/in_progress/completed) + `classification` (unclassified/bug/feature_request/task); optional contact, source/context, roadmap visibility, schedule/shipped dates, vote counter
- `TicketVote` — unique contact/ticket vote; `ContactMergeService` transactionally transfers reads, votes, and submitted tickets to an identified contact, collapses duplicates, and removes the anonymous contact
- `RoadmapPresenter` — shared Now / Next / Shipped / Ideas buckets for API, public roadmap, and admin timeline; shipped takes priority over scheduled, then in-progress, then new ideas

## Routes
- Admin (cookie auth): `/dashboard`, `announcements`, `segments`, `segment_values` (create/destroy), `tickets` (including timeline and transition), `contacts` (index/show/destroy), `session`, `passwords/:token`
- Public: `/` (marketing page or redirect), `/script.js` (embed loader, CSRF-exempt, layout false), `/roadmap`, `/features/:id`, `/changelog`, `/changelog/:id`, `/up`. Changelog requires public announcements enabled.
- API: `POST /api/v1/identity` mints/resolves/merges contacts; remaining endpoints require anonymous ID or JWT: `GET /api/v1/state`, announcements index/show/read/read_all/opt_out/opt_in, tickets index/create/show/vote/unvote, `GET /api/v1/roadmap`
- Test-only: `GET /_test/widget_host` embeds the widget for browser tests

## Auth flow
- `ApplicationController` includes `Authentication` (Rails 8 generated). Use `allow_unauthenticated_access only: %i[...]` to opt out.
- API controllers inherit `Api::V1::BaseController`, skipping session auth/CSRF and including `WidgetAuthenticatable`. Identity comes from `X-Ideabug-Anon-Id` and/or `Authorization: Bearer ...`; verified JWT `info`/`segments` sync to `Current.contact`.
- Browser identity is stored under `localStorage["ideabug:state"]`. When both identities are present, the anonymous contact is merged; an empty `X-Ideabug-Anonymous-Id` response header clears its browser ID.
- `JwtCredentialService` verifies RS256 using `JwtConfig.public_key`: `JWT_PUBLIC_KEY_BASE64`, then `JWT_PUBLIC_KEY`, then `config/jwt/` + `JWT_PUBLIC_KEY_FILE` (default `public.pem`). Only the host app signs; private-key settings are used by `test/support/jwt_test_issuer.rb` only.
- `ANNOUNCEMENTS_PUBLICLY_ACCESSIBLE` is stored without boolean coercion; leave unset to disable (the string `"false"` is truthy). `CORS_ALLOWED_ORIGINS` configures API origins; Rack::Attack uses per-process memory counters. hCaptcha is not implemented.

## Conventions
- Models follow ordered comment skeleton: `## SCOPES / CONCERNS / CONSTANTS / ATTRIBUTES & RELATED / ASSOCIATIONS / VALIDATIONS / CALLBACKS / OTHER`. Preserve when editing.
- Leave `# == Schema Information` blocks intact. The optional `mlitwiniuk/annotate_models` gem is currently commented out; annotations are not automatically regenerated unless enabled.
- `Current` (ActiveSupport::CurrentAttributes) holds `session` (admin) and `contact` (API).
- Stray `.null-ls_*.tmp` files in `app/views/layouts/` are editor crashes — safe to ignore/delete, do not commit.

## Common commands
- `bin/dev` — start puma + tailwind watch
- `bin/rails test` (or via dip: `dip test`) — full Minitest suite
- `bin/rails test:system` — headless Chrome browser suite; use `PARALLEL_WORKERS=1` for a single local test database
- `bin/rails test test/models/foo_test.rb` — single file
- `bundle exec rubocop` — lint (Standard preset)
- `bundle exec bundle-audit check --update` — gem vulnerability scan (also in `bin/ci`)
- CI: `.github/workflows/ci.yml` runs lint, bundle-audit + importmap audit, unit tests + seeds, and system tests on PRs and `master`. Pre-existing rubocop offenses live in `.rubocop_todo.yml`; shrink it, don't grow it.
- `bin/rails db:prepare` — create + migrate + seed
- `dip provision` — bootstrap docker stack
- Use `mise exec -- ...` locally if needed to select `.ruby-version`; `mise exec -- env PARALLEL_WORKERS=1 bin/rails test`

## Gotchas
- `Announcement#read` reads from `attributes["read"]` first (set via SQL select in index queries) — preserve when refactoring.
- `Contact#update_segments_from_payload` short-circuits if normalized payload unchanged; only creates new `SegmentValue`s if `segment.allow_new_values?`.
- Announcement targeting is OR within a segment and AND across selected segments, shared through `Announcement.visible_to_contact`. No targets means broadcast.
- `/script.js` is a bootstrap in `app/views/welcome/script.js.erb`; the main widget is `vendor/javascript/ideabug_widget.js` (plain IIFE, not ESM/Stimulus), styled by `app/assets/stylesheets/ideabug_widget.css`.
- Tickets created through `POST /api/v1/tickets` are never public: an admin sets `public_on_roadmap` after rewriting the text, because submissions quote host-app data. Source is `agent` only when the verified JWT carries `src: "agent"`, otherwise `widget`; never read it from params.
- Tests: unset a shell-exported `JWT_PRIVATE_KEY` (`env -u JWT_PRIVATE_KEY`), or `JwtTestIssuer` signs with it instead of `private_test.pem` and every JWT test returns 401.
- JWT `id` is a stable string from the host app, stored as `Contact.external_id`; do not use ideabug's internal contact ID. `jti` is not checked for replay; `exp`/`iat` are validated when present, not required by the verifier.
- Keep the shoulda reporter compatibility shim, the Capybara Chrome storage-clear shim (Chrome 158+ rejects Capybara 3.40's `"*"` origin), and Chrome password-manager preferences in test support when upgrading.
- Docker provisioning preserves volumes; PostgreSQL 18 uses `postgres_18` separately from historical PostgreSQL 14 data. Never delete old volumes as part of an upgrade.
- `AGENTS.md` is a symlink to this file (`CLAUDE.md`).
