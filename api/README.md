# Sarvam API

Bun API foundation using Hono, Better Auth email OTP, Drizzle ORM, Resend, and PostgreSQL 16.

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

## Email OTP

Set `RESEND_API_KEY` and `RESEND_FROM` in `.env`. The sender address must use a
verified Resend domain. The server sends OTPs only for the `sign-in` flow.

The email OTP lifecycle is:

1. `POST /auth/email-otp/send-verification-otp` with `{ "email": "...", "type": "sign-in" }`.
2. `POST /auth/sign-in/email-otp` with `{ "email": "...", "otp": "...", "name": "..." }`.

The second request can automatically create a new account when the email is
not registered yet. Resending an OTP uses the first endpoint again.

## Chat streaming

Chat routes require the Better Auth session cookie. Configure the OpenAI-
compatible Sarvam provider in `.env`:

```bash
OPENAI_BASE_URL=https://api.sarvam.ai/v1
OPENAI_API_KEY=sk_xxxxxxxxx
```

Create an empty chat:

```text
POST /chats/new
```

The response is `201 { "id": "..." }`. Stream a turn against that chat:

```text
POST /chats/:id/stream
```

```json
{ "text": "Help me plan my workday." }
```

The stream is Server-Sent Events. Each `data` payload is a flat JSON event:

```json
{ "type": "start", "sessionId": "..." }
{ "type": "status", "status": "thinking" }
{ "type": "text-delta", "text": "..." }
{ "type": "status", "status": "complete" }
{ "type": "end", "sessionId": "...", "finishReason": "stop" }
```

Tool events use `toolId`, `toolName`, and a UI-friendly `label`. Tools are not
currently configured. Attachments are not accepted by this API slice.

## Run the API

Development mode:

```bash
bun run dev
```

The API listens on `http://localhost:3000` by default.

Routes:

- `GET /health` — API liveness check.
- `GET /auth/*` and `POST /auth/*` — Better Auth endpoints, including email OTP authentication.
- `POST /chats/new` — create an authenticated chat.
- `POST /chats/:id/stream` — stream an authenticated chat turn as SSE.

Type-check the project with:

```bash
bun run typecheck
```
