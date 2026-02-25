import Fastify from "fastify";
import cors from "@fastify/cors";
import { blocksRoutes } from "./routes/blocks.js";
import { entitiesRoutes } from "./routes/entities.js";
import { observationsRoutes } from "./routes/observations.js";

const app = Fastify({ logger: true });

await app.register(cors, { origin: true });

// Health check
app.get("/health", async () => ({ status: "ok", timestamp: Date.now() }));

// API routes
await app.register(blocksRoutes, { prefix: "/api/v1/blocks" });
await app.register(entitiesRoutes, { prefix: "/api/v1/entities" });
await app.register(observationsRoutes, { prefix: "/api/v1/observations" });

const port = parseInt(process.env.PORT ?? "3000", 10);
const host = process.env.HOST ?? "0.0.0.0";

try {
  await app.listen({ port, host });
  console.log(`Memex API running at http://localhost:${port}`);
} catch (err) {
  app.log.error(err);
  process.exit(1);
}
