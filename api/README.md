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

The response is `201 { "id": "..." }`.

List the authenticated user's chats, ordered by most recently updated:

```text
GET /chats
```

The response is an array of chat summaries:

```json
[
  {
    "id": "...",
    "createdAt": "2026-08-28T10:00:00.000Z",
    "updatedAt": "2026-08-28T10:02:00.000Z"
  }
]
```

Stream a turn against that chat:

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
{ "type": "end", "sessionId": "...", "finishReason": "stop", "messages": [
  { "id": "...", "role": "user", "text": "Help me plan my workday." },
  { "id": "...", "role": "assistant", "text": "...", "reasoningDurationSeconds": 1.42 }
] }
```

Tool events use `toolId`, `toolName`, and a UI-friendly `label`. Tools are not
currently configured. Attachments are not accepted by this API slice. The
`end.messages` payload contains the canonical user and assistant messages for
the completed turn. For the complete ordered transcript, fetch the chat:

```text
GET /chats/:id
```

```json
{
  "id": "...",
  "messages": [
    { "id": "...", "role": "user", "text": "..." },
    { "id": "...", "role": "assistant", "text": "...", "reasoningDurationSeconds": 1.42 }
  ]
}
```

Server-side chat history continues to use AI SDK `ModelMessage` values. The
client-facing messages are intentionally flattened to user/assistant text;
non-text content and tool metadata are omitted.

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
- `GET /chats` — list authenticated chat summaries.
- `GET /chats/:id` — fetch an authenticated chat transcript.
- `POST /chats/:id/stream` — stream an authenticated chat turn as SSE.

Type-check the project with:

```bash
bun run typecheck
```
