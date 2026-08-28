import app from "./src/app";
import { startMDNSBroadcast } from "./src/infrastructure/mdns";

const port = Number(Bun.env.PORT ?? 3000);
console.log(`[API] Starting server on port ${port}`);
const stopMDNSBroadcast = startMDNSBroadcast(port);

process.once("SIGINT", stopMDNSBroadcast);
process.once("SIGTERM", stopMDNSBroadcast);

export default {
  port,
  fetch: app.fetch,
};
