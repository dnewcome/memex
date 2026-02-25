import type { FastifyInstance } from "fastify";
import { eq, and } from "drizzle-orm";
import { v4 as uuidv4 } from "uuid";
import { db } from "../db/index.js";
import { observations, entities, blocks } from "../db/schema.js";

export async function observationsRoutes(app: FastifyInstance) {
  // GET /api/v1/observations?entity_id=&block_id= — filtered query
  app.get<{ Querystring: { entity_id?: string; block_id?: string } }>(
    "/",
    async (req, reply) => {
      const filters = [];
      if (req.query.entity_id) filters.push(eq(observations.entity_id, req.query.entity_id));
      if (req.query.block_id) filters.push(eq(observations.block_id, req.query.block_id));

      const rows = filters.length
        ? await db.select().from(observations).where(and(...filters))
        : await db.select().from(observations);

      return { data: rows };
    }
  );

  // POST /api/v1/observations — manual creation (confirmed immediately)
  app.post<{
    Body: {
      entity_id: string;
      block_id: string;
    };
  }>("/", async (req, reply) => {
    const { entity_id, block_id } = req.body;
    const now = Date.now();

    // Verify entity and block exist
    const entity = await db.query.entities.findFirst({ where: eq(entities.id, entity_id) });
    if (!entity) return reply.code(404).send({ error: "Entity not found" });

    const block = await db.query.blocks.findFirst({ where: eq(blocks.id, block_id) });
    if (!block) return reply.code(404).send({ error: "Block not found" });

    // Check for existing observation
    const existing = await db.query.observations.findFirst({
      where: and(eq(observations.entity_id, entity_id), eq(observations.block_id, block_id)),
    });
    if (existing) return reply.code(409).send({ error: "Observation already exists", data: existing });

    const id = uuidv4();
    await db.insert(observations).values({
      id,
      entity_id,
      block_id,
      observed_at: now,
      status: "confirmed",
      source: "manual",
      created_at: now,
    });

    const observation = await db.query.observations.findFirst({
      where: eq(observations.id, id),
    });
    reply.code(201);
    return { data: observation };
  });

  // PATCH /api/v1/observations/:id — confirm or dismiss
  app.patch<{
    Params: { id: string };
    Body: { status: "confirmed" | "dismissed" };
  }>("/:id", async (req, reply) => {
    const existing = await db.query.observations.findFirst({
      where: eq(observations.id, req.params.id),
    });
    if (!existing) return reply.code(404).send({ error: "Observation not found" });

    const { status } = req.body;
    if (!["confirmed", "dismissed"].includes(status)) {
      return reply.code(400).send({ error: "status must be confirmed or dismissed" });
    }

    await db
      .update(observations)
      .set({ status })
      .where(eq(observations.id, req.params.id));

    const updated = await db.query.observations.findFirst({
      where: eq(observations.id, req.params.id),
    });
    return { data: updated };
  });
}
