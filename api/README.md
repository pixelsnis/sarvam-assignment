# Sarvam API

Bun API foundation using Hono, Better Auth, Drizzle ORM, and PostgreSQL 16.

## Setup

Install dependencies:

```bash
bun install
```

Create local environment variables:

```bash
cp .env.example .env
```

The PostgreSQL service is defined in `docker-compose.yml`. Start it when you
are ready to use the database:

```bash
docker compose up -d postgres
```

## Database schema and migrations

Better Auth owns the shape of its required tables. Generate the Drizzle schema
with the Better Auth CLI:

```bash
bun run auth:generate
```

Do not manually add Better Auth tables to `src/db/schema.ts`.

Generate a committed Drizzle migration from the CLI-generated schema:

```bash
bun run db:generate
```

Apply migrations to the configured PostgreSQL database:

```bash
bun run db:migrate
```

## Run the API

Development mode:

```bash
bun run dev
```

The API listens on `http://localhost:3000` by default.

Routes:

- `GET /health` — API liveness check.
- `GET /auth/*` and `POST /auth/*` — Better Auth endpoints, including email/password authentication.

Type-check the project with:

```bash
bun run typecheck
```
