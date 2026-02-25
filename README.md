# Memex

A note-taking app built around the **pansophia** concept: knowledge is constructed from *observations* — timestamped connections between blocks of content and named entities.

The core question the system answers as you write:

> *"Have I seen or referenced this before, and when?"*

---

## Core Concepts

### Blocks

A block is a unit of content — a paragraph, heading, code snippet, todo item, etc. Blocks can be nested (via `parent_id`), and root blocks (where `parent_id` is null) serve as documents. There is no separate "document" model; a top-level block *is* the document.

Blocks use **fractional positioning** (`REAL` column) so siblings can be reordered by inserting a value between two existing positions, with no need to renumber.

### Entities

An entity is a named thing the system has noticed in your writing: a URL, a person (`@mention`), a concept (`[[wiki-link]]`), or a tag (`#hashtag`). Entities have two name fields:

- **`name`** — the original casing as first written (e.g. `[[Zettelkasten]]`)
- **`canonical`** — a normalized lookup key (e.g. `[[zettelkasten]]`)

This means `#PKM` and `#pkm` are the same entity but the display name preserves what you typed first.

### Observations

An observation is the connection between a block and an entity at a point in time. It answers: *"this block referenced this entity."*

Observations are **idempotent per block+entity pair** — editing a block ten times produces one observation, not ten. The system records "I thought about X here," not "I typed X here N times."

Observations have a lifecycle:

```
auto-extracted → pending → confirmed
                         → dismissed
```

The API auto-extracts entities when a block is saved and creates `pending` observations. The user confirms or dismisses them via the UI. Only confirmed observations count toward prior-reference context.

### Entity Extraction

The extractor is a pure function that scans markdown for four patterns (after stripping code fences to avoid false positives):

| Pattern | Type | Example |
|---|---|---|
| `https?://...` | `url` | `https://zettelkasten.de` |
| `[[text]]` | `concept` | `[[personal knowledge management]]` |
| `@word` | `person` | `@andy_matuschak` |
| `#word` | `tag` | `#zettelkasten` |

### "Have You Seen This Before?" UX

This is the primary feedback loop:

1. You type in the editor
2. After 800ms of inactivity, the block is auto-saved
3. The API extracts entities, creates pending observations, and returns enrichment context
4. A banner appears above the editor with tiles like:
   - *"You've referenced [[zettelkasten]] 7 times, last 40 days ago"* → **Add** / **Dismiss**
   - *"First time referencing https://example.com"* → **Add** / **Dismiss**
5. Confirming an observation records the connection permanently; dismissing discards it

Pending observations are stored in-memory in the Flutter app (they also persist in the DB, so nothing is lost on restart).

---

## Architecture

```
memex/
├── api/                        # Fastify + Node.js + TypeScript
│   ├── src/
│   │   ├── db/
│   │   │   ├── schema.ts       # Drizzle schema + inferred TS types
│   │   │   ├── index.ts        # SQLite connection (WAL mode)
│   │   │   └── migrate.ts      # Migration runner
│   │   ├── routes/
│   │   │   ├── blocks.ts
│   │   │   ├── entities.ts
│   │   │   └── observations.ts
│   │   ├── services/
│   │   │   ├── extractor.ts           # Pure markdown → entity extraction
│   │   │   └── observation_service.ts # Upsert + prior-count enrichment
│   │   └── server.ts
│   └── drizzle/                # Generated SQL migrations (commit these)
└── app/                        # Flutter frontend
    └── lib/
        ├── api/api_client.dart
        ├── models/             # Block, Entity, Observation, PendingObservation
        ├── providers/          # Riverpod providers
        ├── screens/            # HomeScreen, EditorScreen, EntityScreen
        └── main.dart
```

### Key Design Decisions

**SQLite with WAL mode** — SQLite is sufficient for a single-user local app and WAL (Write-Ahead Logging) allows concurrent reads without blocking writes, which matters because the Flutter app fires rapid auto-save requests.

**Drizzle ORM** — Migrations are generated from the TypeScript schema (`npm run db:generate`) and committed to version control. The schema file is the single source of truth for both the database structure and TypeScript types.

**No auth** — Single-user by design. The API is localhost-only.

**Riverpod for state** — `AsyncNotifierProvider` for the blocks list (supports mutation methods), `FutureProvider` for read-only entity/detail views, and a `StateProvider` for the in-memory pending observations map.

**go_router** — Declarative routing with URL-based navigation (`/`, `/blocks/:id`, `/entities`, `/entities/:id`), which makes deep-linking and back-navigation straightforward.

**`entity_relations` table** — Scaffolded in the schema but not wired to any routes yet. Intended for V2 edges between entities (e.g. URL authored-by person).

---

## Running

### Prerequisites

- Node.js v22+ (the API uses `better-sqlite3`, a native module that requires a recent Node)
- Flutter SDK (for the mobile/desktop app)

If you use nvm:
```bash
nvm install 22
nvm use 22
```

### API

```bash
cd api
npm install
npm run db:migrate   # creates memex.db and applies schema
npm run dev          # starts server on http://localhost:3000
```

Verify it's running:
```bash
curl http://localhost:3000/health
# → {"status":"ok","timestamp":...}
```

### Flutter App

If this is your first time (Flutter SDK must be installed):
```bash
cd app
flutter create --project-name memex --org com.memex .
flutter pub get
```

Then:
```bash
flutter run
```

The app talks to `http://localhost:3000` by default. If running on a physical device, update `_baseUrl` in `lib/api/api_client.dart` to your machine's local IP.

### API Reference

| Method | Path | Description |
|---|---|---|
| `GET` | `/health` | Health check |
| `GET` | `/api/v1/blocks` | List root blocks |
| `POST` | `/api/v1/blocks` | Create block |
| `GET` | `/api/v1/blocks/:id` | Block + children + observations |
| `PATCH` | `/api/v1/blocks/:id` | Update content; triggers extraction; returns `pending_observations` |
| `DELETE` | `/api/v1/blocks/:id` | Soft delete (sets `archived_at`) |
| `PATCH` | `/api/v1/blocks/:id/move` | Reparent or reposition |
| `GET` | `/api/v1/entities` | List all entities with `observation_count` |
| `GET` | `/api/v1/entities/search?q=` | Search by name or canonical |
| `GET` | `/api/v1/entities/:id` | Entity + full observation timeline |
| `GET` | `/api/v1/observations` | Filtered observation list |
| `POST` | `/api/v1/observations` | Create manual observation (confirmed immediately) |
| `PATCH` | `/api/v1/observations/:id` | Set status to `confirmed` or `dismissed` |

### Quick smoke test

```bash
# Create a block
curl -X POST http://localhost:3000/api/v1/blocks \
  -H "Content-Type: application/json" \
  -d '{"content": "Reading about [[zettelkasten]] and @andy_matuschak"}'

# Save it (triggers extraction — note the pending_observations in the response)
curl -X PATCH http://localhost:3000/api/v1/blocks/<id> \
  -H "Content-Type: application/json" \
  -d '{"content": "Reading about [[zettelkasten]] and @andy_matuschak"}'

# List entities
curl http://localhost:3000/api/v1/entities
```
