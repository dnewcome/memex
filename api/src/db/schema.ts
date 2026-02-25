import { sqliteTable, text, real, integer } from "drizzle-orm/sqlite-core";
import { relations } from "drizzle-orm";

// ─── blocks ────────────────────────────────────────────────────────────────

export const blocks = sqliteTable("blocks", {
  id: text("id").primaryKey(),
  parent_id: text("parent_id"),
  type: text("type", {
    enum: ["text", "heading1", "heading2", "heading3", "code", "image", "link", "todo", "quote"],
  })
    .notNull()
    .default("text"),
  content: text("content").notNull().default(""),
  position: real("position").notNull().default(0),
  created_at: integer("created_at").notNull(),
  updated_at: integer("updated_at").notNull(),
  archived_at: integer("archived_at"),
});

// ─── entities ──────────────────────────────────────────────────────────────

export const entities = sqliteTable("entities", {
  id: text("id").primaryKey(),
  type: text("type", {
    enum: ["url", "person", "concept", "tag", "place", "product"],
  }).notNull(),
  name: text("name").notNull(),
  canonical: text("canonical").notNull().unique(),
  meta: text("meta").notNull().default("{}"),
  created_at: integer("created_at").notNull(),
  first_seen_at: integer("first_seen_at").notNull(),
});

// ─── observations ──────────────────────────────────────────────────────────

export const observations = sqliteTable("observations", {
  id: text("id").primaryKey(),
  entity_id: text("entity_id")
    .notNull()
    .references(() => entities.id, { onDelete: "cascade" }),
  block_id: text("block_id")
    .notNull()
    .references(() => blocks.id, { onDelete: "cascade" }),
  observed_at: integer("observed_at").notNull(),
  status: text("status", {
    enum: ["pending", "confirmed", "dismissed"],
  })
    .notNull()
    .default("pending"),
  source: text("source", { enum: ["auto", "manual"] })
    .notNull()
    .default("auto"),
  created_at: integer("created_at").notNull(),
});

// ─── entity_relations (V2 scaffold) ────────────────────────────────────────

export const entityRelations = sqliteTable("entity_relations", {
  id: text("id").primaryKey(),
  from_entity_id: text("from_entity_id")
    .notNull()
    .references(() => entities.id, { onDelete: "cascade" }),
  to_entity_id: text("to_entity_id")
    .notNull()
    .references(() => entities.id, { onDelete: "cascade" }),
  relation_type: text("relation_type").notNull(),
  created_at: integer("created_at").notNull(),
});

// ─── Drizzle relations ──────────────────────────────────────────────────────

export const blocksRelations = relations(blocks, ({ many, one }) => ({
  children: many(blocks, { relationName: "parent_children" }),
  parent: one(blocks, {
    fields: [blocks.parent_id],
    references: [blocks.id],
    relationName: "parent_children",
  }),
  observations: many(observations),
}));

export const entitiesRelations = relations(entities, ({ many }) => ({
  observations: many(observations),
  relationsFrom: many(entityRelations, { relationName: "from" }),
  relationsTo: many(entityRelations, { relationName: "to" }),
}));

export const observationsRelations = relations(observations, ({ one }) => ({
  entity: one(entities, {
    fields: [observations.entity_id],
    references: [entities.id],
  }),
  block: one(blocks, {
    fields: [observations.block_id],
    references: [blocks.id],
  }),
}));

export const entityRelationsRelations = relations(entityRelations, ({ one }) => ({
  fromEntity: one(entities, {
    fields: [entityRelations.from_entity_id],
    references: [entities.id],
    relationName: "from",
  }),
  toEntity: one(entities, {
    fields: [entityRelations.to_entity_id],
    references: [entities.id],
    relationName: "to",
  }),
}));

// ─── TypeScript types ────────────────────────────────────────────────────────

export type Block = typeof blocks.$inferSelect;
export type NewBlock = typeof blocks.$inferInsert;
export type Entity = typeof entities.$inferSelect;
export type NewEntity = typeof entities.$inferInsert;
export type Observation = typeof observations.$inferSelect;
export type NewObservation = typeof observations.$inferInsert;
export type EntityRelation = typeof entityRelations.$inferSelect;
