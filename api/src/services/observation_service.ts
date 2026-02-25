import { eq, and, count, max, sql } from "drizzle-orm";
import { v4 as uuidv4 } from "uuid";
import { db } from "../db/index.js";
import { entities, observations } from "../db/schema.js";
import type { ExtractedItem } from "./extractor.js";
import type { Entity, Observation } from "../db/schema.js";

export interface ObservationWithContext {
  observation: Observation;
  entity: Entity;
  prior_count: number;
  last_observed_at: number | null;
}

export async function upsertObservationsForBlock(
  blockId: string,
  extractedItems: ExtractedItem[],
  now: number
): Promise<ObservationWithContext[]> {
  const results: ObservationWithContext[] = [];

  for (const item of extractedItems) {
    // 1. Find or create entity
    let entity = await db.query.entities.findFirst({
      where: eq(entities.canonical, item.canonical),
    });

    if (!entity) {
      const newId = uuidv4();
      await db.insert(entities).values({
        id: newId,
        type: item.type,
        name: item.name,
        canonical: item.canonical,
        meta: "{}",
        created_at: now,
        first_seen_at: now,
      });
      entity = await db.query.entities.findFirst({
        where: eq(entities.id, newId),
      });
      if (!entity) continue;
    }

    // 2. Find or create observation (idempotent per block+entity)
    let observation = await db.query.observations.findFirst({
      where: and(
        eq(observations.entity_id, entity.id),
        eq(observations.block_id, blockId)
      ),
    });

    if (!observation) {
      const newObsId = uuidv4();
      await db.insert(observations).values({
        id: newObsId,
        entity_id: entity.id,
        block_id: blockId,
        observed_at: now,
        status: "pending",
        source: "auto",
        created_at: now,
      });
      observation = await db.query.observations.findFirst({
        where: eq(observations.id, newObsId),
      });
      if (!observation) continue;
    }

    // 3. Count prior confirmed observations for enrichment context
    const priorResult = await db
      .select({
        prior_count: count(),
        last_observed_at: max(observations.observed_at),
      })
      .from(observations)
      .where(
        and(
          eq(observations.entity_id, entity.id),
          eq(observations.status, "confirmed"),
          // Exclude current observation from prior count
          sql`${observations.id} != ${observation.id}`
        )
      );

    const prior_count = priorResult[0]?.prior_count ?? 0;
    const last_observed_at = priorResult[0]?.last_observed_at ?? null;

    results.push({
      observation,
      entity,
      prior_count,
      last_observed_at,
    });
  }

  return results;
}
