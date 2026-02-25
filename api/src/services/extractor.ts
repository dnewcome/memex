export type EntityType = "url" | "person" | "concept" | "tag" | "place" | "product";

export interface ExtractedItem {
  type: EntityType;
  name: string;
  canonical: string;
}

/**
 * Pure function: extract entities from markdown text.
 * Strips code fences before scanning to avoid false positives.
 */
export function extractEntities(markdown: string): ExtractedItem[] {
  // Strip fenced code blocks to avoid extracting from code
  const stripped = markdown.replace(/```[\s\S]*?```/g, "").replace(/`[^`]+`/g, "");

  const seen = new Set<string>();
  const results: ExtractedItem[] = [];

  function add(item: ExtractedItem) {
    if (!seen.has(item.canonical)) {
      seen.add(item.canonical);
      results.push(item);
    }
  }

  // URLs: https?://...
  const urlRegex = /https?:\/\/[^\s\])"'>]+/g;
  for (const match of stripped.matchAll(urlRegex)) {
    const raw = match[0].replace(/[.,;:!?]+$/, ""); // strip trailing punctuation
    try {
      const url = new URL(raw);
      const canonical = (url.hostname + url.pathname + url.search + url.hash)
        .toLowerCase()
        .replace(/\/+$/, "");
      add({ type: "url", name: raw, canonical: `url:${canonical}` });
    } catch {
      // skip malformed URLs
    }
  }

  // Wiki-links: [[text]]
  const wikiRegex = /\[\[([^\]]+)\]\]/g;
  for (const match of stripped.matchAll(wikiRegex)) {
    const name = match[1].trim();
    const canonical = `[[${name.toLowerCase()}]]`;
    add({ type: "concept", name: `[[${name}]]`, canonical });
  }

  // @mentions: @word (word chars only)
  const mentionRegex = /@([\w][\w.-]*)/g;
  for (const match of stripped.matchAll(mentionRegex)) {
    const name = match[1];
    const canonical = `@${name.toLowerCase()}`;
    add({ type: "person", name: `@${name}`, canonical });
  }

  // #tags: #word
  const tagRegex = /#([\w][\w-]*)/g;
  for (const match of stripped.matchAll(tagRegex)) {
    const name = match[1];
    const canonical = `#${name.toLowerCase()}`;
    add({ type: "tag", name: `#${name}`, canonical });
  }

  return results;
}
