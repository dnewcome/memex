import type { FastifyInstance } from "fastify";
import { eq, isNull, asc } from "drizzle-orm";
import { v4 as uuidv4 } from "uuid";
import { db } from "../db/index.js";
import { blocks, observations, entities } from "../db/schema.js";
import { extractEntities } from "../services/extractor.js";
import { upsertObservationsForBlock } from "../services/observation_service.js";

export async function blocksRoutes(app: FastifyInstance) {
  // GET /api/v1/blocks — list root blocks (not archived)
  app.get("/", async (req, reply) => {
    const rootBlocks = await db
      .select()
      .from(blocks)
      .where(and_null_parent(blocks))
      .orderBy(asc(blocks.position));
    return { data: rootBlocks };
  });

  // POST /api/v1/blocks — create block
  app.post<{
    Body: {
      parent_id?: string | null;
      type?: string;
      content?: string;
      position?: number;
    };
  }>("/", async (req, reply) => {
    const { parent_id = null, type = "text", content = "", position } = req.body;
    const now = Date.now();

    // Calculate position: max sibling position + 1000
    let pos = position;
    if (pos === undefined) {
      const siblings = await db
        .select({ position: blocks.position })
        .from(blocks)
        .where(parent_id ? eq(blocks.parent_id, parent_id) : isNull(blocks.parent_id));
      const maxPos = siblings.reduce((m, s) => Math.max(m, s.position), 0);
      pos = maxPos + 1000;
    }

    const id = uuidv4();
    await db.insert(blocks).values({
      id,
      parent_id: parent_id ?? null,
      type: type as any,
      content,
      position: pos,
      created_at: now,
      updated_at: now,
    });

    const block = await db.query.blocks.findFirst({ where: eq(blocks.id, id) });
    reply.code(201);
    return { data: block };
  });

  // GET /api/v1/blocks/:id — block + children + observations with entities
  app.get<{ Params: { id: string } }>("/:id", async (req, reply) => {
    const block = await db.query.blocks.findFirst({
      where: eq(blocks.id, req.params.id),
    });
    if (!block) return reply.code(404).send({ error: "Block not found" });

    const children = await db
      .select()
      .from(blocks)
      .where(eq(blocks.parent_id, block.id))
      .orderBy(asc(blocks.position));

    const blockObservations = await db
      .select({
        observation: observations,
        entity: entities,
      })
      .from(observations)
      .innerJoin(entities, eq(observations.entity_id, entities.id))
      .where(eq(observations.block_id, block.id));

    return { data: { block, children, observations: blockObservations } };
  });

  // PATCH /api/v1/blocks/:id — update; triggers extraction
  app.patch<{
    Params: { id: string };
    Body: { content?: string; type?: string };
  }>("/:id", async (req, reply) => {
    const now = Date.now();
    const existing = await db.query.blocks.findFirst({
      where: eq(blocks.id, req.params.id),
    });
    if (!existing) return reply.code(404).send({ error: "Block not found" });

    const updates: Partial<typeof blocks.$inferInsert> = { updated_at: now };
    if (req.body.content !== undefined) updates.content = req.body.content;
    if (req.body.type !== undefined) updates.type = req.body.type as any;

    await db.update(blocks).set(updates).where(eq(blocks.id, req.params.id));

    const updated = await db.query.blocks.findFirst({
      where: eq(blocks.id, req.params.id),
    });

    // Extract entities and upsert observations
    const content = updates.content ?? existing.content;
    const extracted = extractEntities(content);
    const pending_observations = await upsertObservationsForBlock(
      req.params.id,
      extracted,
      now
    );

    return { data: updated, pending_observations };
  });

  // DELETE /api/v1/blocks/:id — soft delete
  app.delete<{ Params: { id: string } }>("/:id", async (req, reply) => {
    const existing = await db.query.blocks.findFirst({
      where: eq(blocks.id, req.params.id),
    });
    if (!existing) return reply.code(404).send({ error: "Block not found" });

    await db
      .update(blocks)
      .set({ archived_at: Date.now() })
      .where(eq(blocks.id, req.params.id));

    reply.code(204).send();
  });

  // PATCH /api/v1/blocks/:id/move — reparent / reposition
  app.patch<{
    Params: { id: string };
    Body: { parent_id?: string | null; position?: number };
  }>("/:id/move", async (req, reply) => {
    const existing = await db.query.blocks.findFirst({
      where: eq(blocks.id, req.params.id),
    });
    if (!existing) return reply.code(404).send({ error: "Block not found" });

    const updates: Partial<typeof blocks.$inferInsert> = { updated_at: Date.now() };
    if (req.body.parent_id !== undefined) updates.parent_id = req.body.parent_id;
    if (req.body.position !== undefined) updates.position = req.body.position;

    await db.update(blocks).set(updates).where(eq(blocks.id, req.params.id));

    const updated = await db.query.blocks.findFirst({
      where: eq(blocks.id, req.params.id),
    });
    return { data: updated };
  });
}

// Helper: filter for blocks with null parent_id (root blocks)
function and_null_parent(table: typeof blocks) {
  return isNull(table.parent_id);
}
