import type { FastifyInstance } from "fastify";
import { eq, like, or, count, max, desc } from "drizzle-orm";
import { db } from "../db/index.js";
import { entities, observations, blocks } from "../db/schema.js";

export async function entitiesRoutes(app: FastifyInstance) {
  // GET /api/v1/entities/search?q= — MUST be registered before /:id
  app.get<{ Querystring: { q?: string } }>("/search", async (req, reply) => {
    const q = req.query.q?.trim() ?? "";
    if (!q) return { data: [] };

    const pattern = `%${q}%`;
    const results = await db
      .select()
      .from(entities)
      .where(or(like(entities.name, pattern), like(entities.canonical, pattern)))
      .limit(20);

    return { data: results };
  });

  // GET /api/v1/entities — list all with observation_count and last_observed_at
  app.get("/", async (req, reply) => {
    const rows = await db
      .select({
        id: entities.id,
        type: entities.type,
        name: entities.name,
        canonical: entities.canonical,
        meta: entities.meta,
        created_at: entities.created_at,
        first_seen_at: entities.first_seen_at,
        observation_count: count(observations.id),
        last_observed_at: max(observations.observed_at),
      })
      .from(entities)
      .leftJoin(
        observations,
        eq(entities.id, observations.entity_id)
      )
      .groupBy(entities.id)
      .orderBy(desc(max(observations.observed_at)));

    return { data: rows };
  });

  // GET /api/v1/entities/:id — entity + full observation timeline with block data
  app.get<{ Params: { id: string } }>("/:id", async (req, reply) => {
    const entity = await db.query.entities.findFirst({
      where: eq(entities.id, req.params.id),
    });
    if (!entity) return reply.code(404).send({ error: "Entity not found" });

    const timeline = await db
      .select({
        observation: observations,
        block: blocks,
      })
      .from(observations)
      .innerJoin(blocks, eq(observations.block_id, blocks.id))
      .where(eq(observations.entity_id, entity.id))
      .orderBy(desc(observations.observed_at));

    return { data: { entity, timeline } };
  });
}
