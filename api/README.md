# memex-api

Fastify REST API for the Memex note-taking app. Handles block storage, entity extraction, and observation tracking.

## Requirements

- Node.js v22+ (uses `better-sqlite3`, a native module)
- nvm recommended: `nvm use 22`

## Setup

```bash
npm install
npm run db:migrate
npm run dev
```

The server starts on `http://localhost:3000`.

## Scripts

| Command | Description |
|---|---|
| `npm run dev` | Start with hot-reload via tsx |
| `npm run build` | Compile TypeScript to `dist/` |
| `npm start` | Run compiled output |
| `npm run db:generate` | Generate a new SQL migration from schema changes |
| `npm run db:migrate` | Apply pending migrations to `memex.db` |

## Structure

```
src/
├── db/
│   ├── schema.ts           # Drizzle schema — edit this to change the data model
│   ├── index.ts            # SQLite connection (WAL mode, foreign keys on)
│   └── migrate.ts          # Migration runner
├── routes/
│   ├── blocks.ts           # CRUD + soft delete + move
│   ├── entities.ts         # List, search, detail with observation timeline
│   └── observations.ts     # Confirm / dismiss / manual create
├── services/
│   ├── extractor.ts        # Pure fn: markdown → ExtractedItem[]
│   └── observation_service.ts  # Upsert observations + prior-count enrichment
└── server.ts
drizzle/                    # Generated SQL migrations — commit these
memex.db                    # Local SQLite database — gitignored
```

## Changing the schema

1. Edit `src/db/schema.ts`
2. `npm run db:generate` — creates a new file in `drizzle/`
3. `npm run db:migrate` — applies it to `memex.db`

Never edit the generated files in `drizzle/` by hand.
