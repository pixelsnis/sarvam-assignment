# Sarvam API

Bun API foundation using Hono, Better Auth email OTP, Drizzle ORM, Resend, and PostgreSQL 16.

## Setup

Install dependencies and create local environment variables:

```bash
bun install
cp .env.example .env
```

The PostgreSQL service is defined in `docker-compose.yml`:

```bash
docker compose up -d postgres
```

## Database schema and migrations

Better Auth owns the shape of its required tables. Generate the Drizzle schema
with the Better Auth CLI, then generate and apply migrations:

```bash
bun run auth:generate
bun run db:generate
bun run db:migrate
```

Do not manually add Better Auth tables to `src/db/schema.ts`.

## Email OTP

Set `RESEND_API_KEY` and `RESEND_FROM` in `.env`. The sender address must use a
verified Resend domain. The server sends OTPs only for the `sign-in` flow.

Authentication endpoints:

1. `POST /auth/email-otp/send-verification-otp` with `{ "email": "...", "type": "sign-in" }`.
2. `POST /auth/sign-in/email-otp` with `{ "email": "...", "otp": "...", "name": "..." }`.

## Speech transcription

Transcription requires the Better Auth session cookie and the
`SARVAM_API_KEY` environment variable. Uploaded audio is sent to Sarvam's
Speech-to-Text REST API using the `saaras:v3` model.

Upload one audio file as multipart form data under the `file` field:

```text
POST /transcriptions
```

The response contains the transcript:

```json
{ "transcript": "नमस्ते, आप कैसे हैं?" }
```

## Run the API

```bash
bun run dev
```

The API listens on `http://localhost:3000` by default and broadcasts the
`_sarvam-api._tcp` Bonjour service on the local network. Set `PORT` to
advertise a different HTTP port.

Routes:

- `GET /health` — API liveness check.
- `GET /auth/*` and `POST /auth/*` — Better Auth email OTP authentication.
- `POST /transcriptions` — transcribe one authenticated audio upload with Saaras.

Type-check the project with:

```bash
bun run typecheck
```
