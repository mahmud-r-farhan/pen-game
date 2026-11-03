// server_deno/catalog.ts
// Server-owned shop and gameplay catalog. Clients only display these values;
// prices, unlock rules, and authoritative loadout physics are enforced here.
export interface PenCatalogEntry {
  id: string;
  unlockPrice: number;
  minLevel: number;
  /** Full visual/physical length in client world meters. */
  length: number;
  /** Barrel half-thickness in client world meters. */
  radius: number;
  density: number;
  linearDamping: number;
  angularDamping: number;
  restitution: number;
}

export const PEN_CATALOG: Readonly<Record<string, PenCatalogEntry>> = {
  hiSchoolClassic: {
    id: "hiSchoolClassic",
    unlockPrice: 0,
    minLevel: 1,
    length: 5.3,
    radius: 0.16,
    density: 0.85,
    linearDamping: 2.2,
    angularDamping: 1.6,
    restitution: 0.65,
  },
  econoStriker: {
    id: "econoStriker",
    unlockPrice: 200,
    minLevel: 1,
    length: 5.4,
    radius: 0.165,
    density: 0.95,
    linearDamping: 2.4,
    angularDamping: 1.8,
    restitution: 0.60,
  },
  oceanGelPro: {
    id: "oceanGelPro",
    unlockPrice: 500,
    minLevel: 2,
    length: 5.3,
    radius: 0.18,
    density: 1.35,
    linearDamping: 3.0,
    angularDamping: 2.8,
    restitution: 0.50,
  },
  hectorMetalTank: {
    id: "hectorMetalTank",
    unlockPrice: 1200,
    minLevel: 3,
    length: 5.5,
    radius: 0.19,
    density: 2.10,
    linearDamping: 3.4,
    angularDamping: 3.2,
    restitution: 0.72,
  },
  doubleCapMod: {
    id: "doubleCapMod",
    unlockPrice: 2000,
    minLevel: 4,
    length: 5.6,
    radius: 0.18,
    density: 1.65,
    linearDamping: 2.6,
    angularDamping: 2.4,
    restitution: 0.68,
  },
  goldParkerVIP: {
    id: "goldParkerVIP",
    unlockPrice: 4000,
    minLevel: 5,
    length: 5.5,
    radius: 0.185,
    density: 1.95,
    linearDamping: 2.8,
    angularDamping: 2.6,
    restitution: 0.65,
  },
  neonSpinner: {
    id: "neonSpinner",
    unlockPrice: 6500,
    minLevel: 6,
    length: 5.4,
    radius: 0.175,
    density: 1.40,
    linearDamping: 2.0,
    angularDamping: 1.5,
    restitution: 0.75,
  },
};

export const STARTER_PENS = ["hiSchoolClassic", "econoStriker"] as const;
export const DAILY_REWARD_COINS = 200;
export const DAILY_REWARD_COOLDOWN_MS = 20 * 60 * 60 * 1000;

export function playerLevel(wins: number): number {
  return Math.floor(Math.max(0, wins) / 3) + 1;
}
