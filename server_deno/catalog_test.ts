// server_deno/catalog_test.ts
/// <reference path="./deno.d.ts" />
import { ARENA_ROOMS } from "./arena_config.ts";
import { PEN_CATALOG } from "./catalog.ts";

interface ContentContract {
  pens: string[];
  arenas: string[];
}

function readContentContract(): ContentContract {
  try {
    return JSON.parse(
      Deno.readTextFileSync("../test_vectors/content_catalog.json"),
    ) as ContentContract;
  } catch {
    return JSON.parse(
      Deno.readTextFileSync("test_vectors/content_catalog.json"),
    ) as ContentContract;
  }
}

function assert(condition: unknown, message: string): void {
  if (!condition) throw new Error(message);
}

function assertSameSet(actual: string[], expected: string[], label: string): void {
  const missing = expected.filter((id) => !actual.includes(id));
  const unexpected = actual.filter((id) => !expected.includes(id));
  assert(
    missing.length === 0 && unexpected.length === 0,
    `${label} drifted from test_vectors/content_catalog.json. ` +
      `Missing: [${missing.join(", ")}] Unexpected: [${unexpected.join(", ")}]`,
  );
}

Deno.test("Content contract - pen and arena IDs stay in sync", () => {
  const contract = readContentContract();
  assertSameSet(
    Object.keys(PEN_CATALOG),
    contract.pens,
    "PEN_CATALOG",
  );
  assertSameSet(
    Object.keys(ARENA_ROOMS),
    contract.arenas,
    "ARENA_ROOMS",
  );
});

Deno.test("Content contract - pen loadouts are valid and prices escalate", () => {
  let previousPrice = -1;
  for (const pen of Object.values(PEN_CATALOG)) {
    assert(pen.id.length > 0, "Every pen needs an id.");
    assert(pen.unlockPrice >= 0, `${pen.id} has a negative price.`);
    assert(pen.minLevel >= 1, `${pen.id} has an invalid minimum level.`);
    assert(pen.length > 0, `${pen.id} needs a positive length.`);
    assert(pen.radius > 0, `${pen.id} needs a positive radius.`);
    assert(pen.density > 0, `${pen.id} needs a positive density.`);
    assert(
      pen.linearDamping > 0 && pen.angularDamping > 0,
      `${pen.id} needs positive surface damping.`,
    );
    assert(
      pen.restitution > 0 && pen.restitution < 1,
      `${pen.id} needs restitution between 0 and 1.`,
    );
    assert(
      pen.unlockPrice >= previousPrice,
      `${pen.id} is cheaper than an earlier pen in the catalog.`,
    );
    previousPrice = pen.unlockPrice;
  }
});

Deno.test("Content contract - arena stakes keep the 5% sink", () => {
  for (const arena of Object.values(ARENA_ROOMS)) {
    const sink = Math.floor(arena.potCoins * 0.05);
    assert(
      arena.payoutCoins === arena.potCoins - sink,
      `${arena.id} payout must equal the pot minus the 5% sink.`,
    );
    assert(
      arena.potCoins === arena.entryCoins * 2,
      `${arena.id} pot must equal both entry stakes.`,
    );
    assert(
      arena.friction > 0 &&
        arena.angularDamping > 0 &&
        arena.bounce > 0 &&
        arena.bounce < 1,
      `${arena.id} has invalid surface physics.`,
    );
  }
});
