# Sarvam Indus — iOS app

An iOS implementation of a redesigned sign up and core chat experience for Sarvam Indus.

This project was built as a design engineering assignment. The goal was to translate the visual language and interaction model from the accompanying Figma designs into a working iOS experience, with particular attention to the onboarding flow, chat composition, streaming responses, and the details that make the interface feel considered.

**Approximately 90% of the UI was written by hand in SwiftUI, rather than generated with AI.**

## Demo Screen Recording

https://github.com/user-attachments/assets/f8e939de-251d-43a0-af8f-1e96ef7e92c8

## What’s implemented

| Area                     | Implemented                                             | Status / notes                   |
| ------------------------ | ------------------------------------------------------- | -------------------------------- |
| Email authentication     | Email sign-in and account creation with OTPs            | Working, including OTP resend    |
| User setup               | First-time user name collection and session persistence | Working                          |
| Chat streaming           | Streaming assistant responses                           | Working; uses Sarvam 105B        |
| Conversation persistence | User and assistant messages stored in PostgreSQL        | Working at the API level         |
| Web search tool          | Tavily-powered web search during chat responses         | Working                          |
| Voice dictation          | Audio recording and speech-to-text                      | Working; uses Saaras             |
| Local API discovery      | Bonjour/mDNS discovery of the development API           | Working for the local demo setup |
| Google sign-in           | UI is present                                           | No-op                            |
| Apple sign-in            | UI is present                                           | No-op                            |
| Phone authentication     | UI is present                                           | No-op                            |
| Attachments              | Included in the Figma direction                         | Figma designs only               |
| Agent switching          | Included in the Figma direction                         | Figma designs only               |
| Chat history and sidebar | Included in the Figma direction                         | OOS for this assignment          |
| Connectors               | Included in the Figma direction                         | OOS for this assignment          |

The assignment focused on bringing the onboarding and core chat stream to life. The remaining surfaces are represented according to their current design or scope status above.

## Project structure

```text
app/   SwiftUI iOS application
api/   Bun + Hono API, authentication, chat streaming, transcription, and database
```

The API uses Better Auth for email OTP sessions, Drizzle ORM for PostgreSQL access, and an OpenAI-compatible chat provider. Chat interactions use Sarvam 105B, with a Tavily-powered web search tool available when the conversation requires current web information. The API also exposes a small Bonjour/mDNS service so the iOS app can discover a locally running server during the demo.

## Requirements

- macOS 26.0 or newer
- Xcode 26.0 or newer
- iOS 26.0 or newer, either on a device or simulator
- Bun 1.x
- Docker Desktop (or another Docker installation with Compose)
- A Resend API key and verified sender address for OTP email
- Sarvam API credentials for speech transcription
- Credentials for the configured OpenAI-compatible chat provider
- A Tavily API key if web tools are enabled

## Running locally

### 1. Configure the API

```bash
cd api
bun install
cp .env.example .env
```

Fill in the values in `api/.env`. The expected variables and provider configuration are documented in [`api/.env.example`](api/.env.example).

### 2. Start PostgreSQL

From the `api/` directory:

```bash
docker compose up -d postgres
```

Apply the committed migrations:

```bash
bun run db:migrate
```

### 3. Start the API

```bash
bun run dev
```

The API runs on port `3000` by default. It also advertises itself on the local network using the `_sarvam-api._tcp` Bonjour service.

### 4. Run the iOS app

Open [`app/SarvamDemoApp.xcodeproj`](app/SarvamDemoApp.xcodeproj) in Xcode and run the `SarvamDemoApp` scheme on an iOS 27.0+ simulator or device.

When running on a physical device, allow local-network access when prompted. The device and the machine running the API must be on the same network so endpoint discovery can work.

## API development commands

From `api/`:

```bash
bun run typecheck
bun test
```

The API includes coverage for authentication, chat ownership, chat history, streaming, transcription, and error handling.

## Notes

- Do not commit `api/.env` or any provider credentials.
- Email OTP requires a verified Resend sender domain.
- The social sign-in buttons are visual placeholders for the corresponding designs; email OTP is the working authentication path.
- The backend persists chat data, but the chat-history/sidebar experience from the Figma designs is outside the implemented assignment scope.
