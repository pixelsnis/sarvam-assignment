// types: project logic for this module.
export type TranscriptionUser = { user: { id: string } };

export type TranscriptionFetcher = (
  input: string | URL | Request,
  init?: RequestInit,
) => Promise<Response>;

export type TranscriptionDependencies = {
  getSession: (headers: Headers) => Promise<TranscriptionUser | null>;
  fetch: TranscriptionFetcher;
  sarvamApiKey: string | undefined;
};
