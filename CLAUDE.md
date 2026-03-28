# CLAUDE.md — worthy-shared

## What is this

`@worthy/shared` is the shared npm package for the Worthy platform. It contains pure TypeScript logic shared between `worthy-app` (React Native) and `worthy-admin` (Next.js). No UI, no framework dependencies.

## Database

- **Supabase URL:** `https://enophqzovmvhhwtfddnm.supabase.co`
- **Project ID:** `enophqzovmvhhwtfddnm`
- This package OWNS the database schema. All migrations live in `supabase/migrations/`.
- Neither `worthy-app` nor `worthy-admin` may create/alter tables, columns, functions, triggers, indexes, or RLS policies.

## Commands

```bash
npm run build          # tsup → dist/ (ESM + CJS + DTS)
npm test               # vitest (54 tests)
npm run test:scoring   # scoring tests only
npm run lint           # eslint
npm run db:gen-types   # regenerate types from production DB
npm run db:push        # apply migrations to production (confirm first!)
npm run db:reset       # reset local DB (requires Docker)
```

## Architecture

```
src/
├── types/        # TypeScript types for all 17 tables + enums
├── scoring/      # Worthy Score engine (composition, QPR, verdict)
├── constants/    # Fibers, badges, categories, brands, limits
├── validation/   # Product, composition, price, barcode validation
└── index.ts      # Re-exports everything

supabase/
├── migrations/   # 25 SQL migrations (applied to production)
├── seed.sql      # 9 categories, 12 brands, 5 badges
└── config.toml   # Supabase CLI config
```

## Rules

- **NO React, React Native, Next.js, Expo, or any UI dependency.** Pure logic only.
- **NO database connections.** No `createClient()`, no API keys, no secrets.
- **NO platform-specific code.** No `window`, `document`, `process.env`, `Platform.OS`.
- **NO async functions that make network calls.** Only synchronous pure logic.
- Schema changes ONLY via new migration files. Never modify already-applied migrations.
- Scoring formula changes must be documented and tested.
- Do not rename exported types without checking impact on worthy-app and worthy-admin.

## Consuming this package

In `worthy-app` and `worthy-admin` package.json:
```json
"@worthy/shared": "file:../worthy-shared"
```

## Migration workflow

1. `supabase migration new <name>` — creates empty SQL file
2. Write SQL
3. Test locally with `supabase db reset` (requires Docker)
4. `npm run db:gen-types` — regenerate TypeScript types
5. Update manual types in `src/types/` if needed
6. `npm run db:push` — apply to production (ask user first!)
