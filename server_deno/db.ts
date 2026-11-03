// server_deno/db.ts
/// <reference path="./deno.d.ts" />
import {
  DAILY_REWARD_COINS,
  DAILY_REWARD_COOLDOWN_MS,
  PEN_CATALOG,
  playerLevel,
  STARTER_PENS,
} from "./catalog.ts";
import {
  BangladeshiDivision,
  Club,
  TrophyCupTier,
  UserProfile,
  UserStats,
} from "./types.ts";
import {
  cleanAvatar,
  cleanDivision,
  cleanFlag,
  cleanPenId,
  cleanRegion,
  cleanUsername,
  HttpError,
  optionalText,
} from "./validation.ts";

// Keep the KV handle in one module. Production uses Deno Deploy KV; local tests
// can supply DENO_KV_PATH before startup.
const kv = await Deno.openKv(Deno.env.get("DENO_KV_PATH") ?? undefined);

interface CacheEntry<T> {
  data: T;
  expiresAt: number;
}

interface EscrowRecord {
  roomId: string;
  stake: number;
  pot: number;
  participantCount: number;
  ranked: boolean;
  settled: boolean;
}

export interface SettlementSide {
  newBalance: number;
  payout: number;
  trophyDelta: number;
  newTrophies: number;
  cupTier: TrophyCupTier;
  profile: UserProfile;
}

export interface MatchSettlement {
  winner: SettlementSide | null;
  loser: SettlementSide | null;
}

const leaderboardCache = new Map<string, CacheEntry<UserProfile[]>>();
const EMPTY_STATS: UserStats = {
  totalMatches: 0,
  wins: 0,
  losses: 0,
  winStreak: 0,
  highestStreak: 0,
};

function generateTag(): string {
  const digits = crypto.getRandomValues(new Uint32Array(1))[0] % 900000 +
    100000;
  return `#KLM-${digits}`;
}

function newProfile(
  userId: string,
  isGuest: boolean,
  name?: string,
  avatar?: string,
  division?: BangladeshiDivision,
  region?: string,
  flagEmoji?: string,
  tag = generateTag(),
): UserProfile {
  const now = Date.now();
  return {
    id: userId,
    tag,
    username: cleanUsername(
      name,
      isGuest ? `Guest_${tag.slice(-6)}` : "Kolom Player",
    ),
    avatar: cleanAvatar(avatar, "avatar_shuvo"),
    coins: isGuest ? 75 : 120,
    trophyPoints: 100,
    cupTier: "bronze",
    region: cleanRegion(region, "BD"),
    flagEmoji: cleanFlag(flagEmoji, "🇧🇩"),
    clubId: null,
    clubName: null,
    clubTag: null,
    clubRole: null,
    equippedPen: "hiSchoolClassic",
    unlockedPens: [...STARTER_PENS],
    isGuest,
    division: cleanDivision(division, "Dhaka"),
    friends: [],
    stats: { ...EMPTY_STATS },
    createdAt: now,
    lastActiveAt: now,
  };
}

function addLedger(
  tx: ReturnType<Deno.Kv["atomic"]>,
  userId: string,
  kind: string,
  amount: number,
  balanceAfter: number,
  referenceId: string,
): void {
  const id = crypto.randomUUID();
  tx.set(["coin_ledger", userId, Date.now(), id], {
    id,
    userId,
    kind,
    amount,
    balanceAfter,
    referenceId,
    createdAt: Date.now(),
  });
}

export function computeCupTier(trophies: number): TrophyCupTier {
  if (trophies >= 5000) return "grandmaster";
  if (trophies >= 2500) return "diamond";
  if (trophies >= 1200) return "gold";
  if (trophies >= 500) return "silver";
  return "bronze";
}

/** Public DTOs deliberately exclude email, provider IDs, tokens and friend IDs. */
export function toPublicProfile(profile: UserProfile): UserProfile {
  return {
    id: profile.id,
    tag: profile.tag,
    username: profile.username,
    avatar: profile.avatar,
    coins: profile.coins,
    trophyPoints: profile.trophyPoints,
    cupTier: profile.cupTier,
    region: profile.region,
    flagEmoji: profile.flagEmoji,
    clubId: profile.clubId ?? null,
    clubName: profile.clubName ?? null,
    clubTag: profile.clubTag ?? null,
    clubRole: profile.clubRole ?? null,
    equippedPen: profile.equippedPen,
    unlockedPens: [],
    isGuest: profile.isGuest,
    division: profile.division,
    friends: [],
    stats: { ...profile.stats },
    createdAt: profile.createdAt,
    lastActiveAt: profile.lastActiveAt,
  };
}

export async function getUserProfile(
  userId: string,
): Promise<UserProfile | null> {
  const direct = await kv.get<UserProfile>(["users", userId]);
  if (direct.value) return direct.value;
  const alias = await kv.get<string>(["account_aliases", userId]);
  if (!alias.value) return null;
  const target = await kv.get<UserProfile>(["users", alias.value]);
  return target.value;
}

export async function getUserByTag(tag: string): Promise<UserProfile | null> {
  const idRes = await kv.get<string>(["tags", tag.toUpperCase()]);
  if (!idRes.value) return null;
  return getUserProfile(idRes.value);
}

async function allocateTag(): Promise<string> {
  for (let attempt = 0; attempt < 20; attempt++) {
    const tag = generateTag();
    const existing = await kv.get(["tags", tag]);
    if (!existing.value) return tag;
  }
  throw new HttpError(
    503,
    "TAG_EXHAUSTED",
    "Could not allocate a player tag. Please retry.",
  );
}

/** Internal account factory. Callers must create the UID and session server-side. */
export async function ensureUser(
  userId: string,
  isGuest: boolean,
  name?: string,
  avatar?: string,
  division?: BangladeshiDivision,
  region?: string,
  flagEmoji?: string,
): Promise<UserProfile> {
  const existing = await kv.get<UserProfile>(["users", userId]);
  if (existing.value) {
    const updated = { ...existing.value, lastActiveAt: Date.now() };
    await kv.atomic().check(existing).set(["users", userId], updated).commit();
    return updated;
  }

  for (let attempt = 0; attempt < 5; attempt++) {
    const current = await kv.get<UserProfile>(["users", userId]);
    if (current.value) return current.value;
    const tag = await allocateTag();
    const tagEntry = await kv.get<string>(["tags", tag]);
    const profile = newProfile(
      userId,
      isGuest,
      name,
      avatar,
      division,
      region,
      flagEmoji,
      tag,
    );
    const tx = kv.atomic()
      .check(current)
      .check(tagEntry)
      .set(["users", userId], profile)
      .set(["tags", tag], userId)
      .set(["wallets", userId], profile.coins);
    addLedger(
      tx,
      userId,
      "starter_grant",
      profile.coins,
      profile.coins,
      userId,
    );
    const result = await tx.commit();
    if (result.ok) return profile;
  }
  throw new HttpError(
    409,
    "ACCOUNT_CREATE_CONFLICT",
    "Account creation conflicted. Please retry.",
  );
}

function safeGooglePhoto(value: string): string {
  if (!value) return "";
  try {
    const url = new URL(value);
    if (
      url.protocol === "https:" &&
      (url.hostname === "lh3.googleusercontent.com" ||
        url.hostname.endsWith(".googleusercontent.com"))
    ) {
      return url.toString();
    }
  } catch { /* Ignore an invalid provider photo and use a bundled avatar. */ }
  return "";
}

export interface GoogleIdentityInput {
  uid: string;
  name: string;
  email: string;
  picture: string;
}

/**
 * Links a verified Google identity. A guest can be merged only once; currency
 * uses max() on existing accounts so repeatedly creating guests cannot mint coins.
 */
export async function linkGoogleAccount(
  guestId: string | null,
  identity: GoogleIdentityInput,
): Promise<UserProfile> {
  const googleUid = `firebase_${identity.uid}`;
  const providerName = cleanUsername(identity.name, "Kolom Player");
  const providerPhoto = safeGooglePhoto(identity.picture);

  for (let attempt = 0; attempt < 5; attempt++) {
    const googleRes = await kv.get<UserProfile>(["users", googleUid]);
    const guestRes = guestId
      ? await kv.get<UserProfile>(["users", guestId])
      : null;

    if (googleRes.value && guestId && !guestRes?.value) {
      // This guest was already merged. Returning the target is idempotent.
      const alias = await kv.get<string>(["account_aliases", guestId]);
      if (alias.value === googleUid) return googleRes.value;
    }

    if (!googleRes.value) {
      const guest = guestRes?.value ?? null;
      const tag = guest?.tag ?? await allocateTag();
      const profile = guest
        ? {
          ...guest,
          id: googleUid,
          username: providerName,
          email: identity.email,
          avatar: providerPhoto || guest.avatar,
          googlePhotoUrl: providerPhoto || undefined,
          isGuest: false,
          googleId: identity.uid,
          coins: guest.coins + 45,
          lastActiveAt: Date.now(),
        }
        : {
          ...newProfile(
            googleUid,
            false,
            providerName,
            "avatar_shuvo",
            "Dhaka",
            "BD",
            "🇧🇩",
            tag,
          ),
          email: identity.email,
          avatar: providerPhoto || "avatar_shuvo",
          googlePhotoUrl: providerPhoto || undefined,
          googleId: identity.uid,
        };
      const tagEntry = await kv.get<string>(["tags", tag]);
      const tx = kv.atomic()
        .check(googleRes)
        .check(tagEntry)
        .set(["users", googleUid], profile)
        .set(["tags", tag], googleUid)
        .set(["google_to_uid", identity.uid], googleUid)
        .set(["wallets", googleUid], profile.coins);
      if (guestRes) tx.check(guestRes);
      if (guest && guestId) {
        tx.delete(["users", guestId])
          .delete(["wallets", guestId])
          .set(["account_aliases", guestId], googleUid);
        addLedger(
          tx,
          googleUid,
          "account_link_bonus",
          45,
          profile.coins,
          guestId,
        );
      } else {
        addLedger(
          tx,
          googleUid,
          "starter_grant",
          profile.coins,
          profile.coins,
          googleUid,
        );
      }
      const committed = await tx.commit();
      if (committed.ok) return profile;
      continue;
    }

    const target = googleRes.value;
    const guest = guestRes?.value ?? null;
    if (!guest || !guestId) return target;

    const updated: UserProfile = {
      ...target,
      username: providerName || target.username,
      email: identity.email || target.email,
      googlePhotoUrl: providerPhoto || target.googlePhotoUrl,
      googleId: identity.uid,
      isGuest: false,
      coins: Math.max(target.coins, guest.coins),
      trophyPoints: Math.max(target.trophyPoints, guest.trophyPoints),
      unlockedPens: [
        ...new Set([...target.unlockedPens, ...guest.unlockedPens]),
      ],
      friends: [...new Set([...target.friends, ...guest.friends])].filter((
        id,
      ) => id !== target.id && id !== guestId),
      stats: {
        totalMatches: target.stats.totalMatches + guest.stats.totalMatches,
        wins: target.stats.wins + guest.stats.wins,
        losses: target.stats.losses + guest.stats.losses,
        winStreak: Math.max(target.stats.winStreak, guest.stats.winStreak),
        highestStreak: Math.max(
          target.stats.highestStreak,
          guest.stats.highestStreak,
        ),
      },
      lastActiveAt: Date.now(),
    };
    updated.cupTier = computeCupTier(updated.trophyPoints);
    const tx = kv.atomic()
      .check(googleRes)
      .check(guestRes!)
      .set(["users", googleUid], updated)
      .set(["wallets", googleUid], updated.coins)
      .set(["google_to_uid", identity.uid], googleUid)
      .set(["account_aliases", guestId], googleUid)
      .delete(["users", guestId])
      .delete(["wallets", guestId]);
    const committed = await tx.commit();
    if (committed.ok) return updated;
  }
  throw new HttpError(
    409,
    "ACCOUNT_LINK_CONFLICT",
    "Account linking conflicted. Please retry.",
  );
}

export async function atomicEscrowLock(
  p1Id: string,
  p2Id: string,
  stake: number,
  roomId: string,
): Promise<boolean> {
  if (!Number.isSafeInteger(stake) || stake <= 0 || p1Id === p2Id) return false;
  const participantCount = 2;

  for (let attempt = 0; attempt < 5; attempt++) {
    const p1Res = await kv.get<UserProfile>(["users", p1Id]);
    const p2Res = await kv.get<UserProfile>(["users", p2Id]);
    if (!p1Res.value || p1Res.value.coins < stake) return false;
    if (!p2Res.value || p2Res.value.coins < stake) return false;

    const p1Updated = { ...p1Res.value, coins: p1Res.value.coins - stake };
    const escrow: EscrowRecord = {
      roomId,
      stake,
      pot: stake * participantCount,
      participantCount,
      ranked: participantCount === 2,
      settled: false,
    };
    const tx = kv.atomic()
      .check(p1Res)
      .set(["users", p1Id], p1Updated)
      .set(["wallets", p1Id], p1Updated.coins)
      .set(["match_escrow", roomId], escrow);
    addLedger(tx, p1Id, "match_entry", -stake, p1Updated.coins, roomId);
    if (p2Res.value) {
      const p2Updated = { ...p2Res.value, coins: p2Res.value.coins - stake };
      tx.check(p2Res).set(["users", p2Id], p2Updated).set(
        ["wallets", p2Id],
        p2Updated.coins,
      );
      addLedger(tx, p2Id, "match_entry", -stake, p2Updated.coins, roomId);
    }
    const result = await tx.commit();
    if (result.ok) return true;
  }
  return false;
}

function settlementSide(
  profile: UserProfile,
  payout: number,
  trophyDelta: number,
): SettlementSide {
  return {
    newBalance: profile.coins,
    payout,
    trophyDelta,
    newTrophies: profile.trophyPoints,
    cupTier: profile.cupTier,
    profile,
  };
}

/** Idempotently settles escrow and both player profiles in one KV transaction. */
export async function settleMatchWinner(
  roomId: string,
  winnerId: string,
  _pot: number,
  loserId?: string,
): Promise<MatchSettlement> {
  const escrowKey = ["match_escrow", roomId];

  for (let attempt = 0; attempt < 5; attempt++) {
    const escrowRes = await kv.get<EscrowRecord>(escrowKey);
    if (!escrowRes.value) {
      throw new HttpError(
        404,
        "ESCROW_NOT_FOUND",
        "Match escrow was not found.",
      );
    }
    const escrow = escrowRes.value;
    const winnerRes = await kv.get<UserProfile>(["users", winnerId]);
    const loserRes = loserId
      ? await kv.get<UserProfile>(["users", loserId])
      : null;

    if (escrow.settled) {
      return {
        winner: winnerRes?.value ? settlementSide(winnerRes.value, 0, 0) : null,
        loser: loserRes?.value ? settlementSide(loserRes.value, 0, 0) : null,
      };
    }

    const payout = escrow.ranked ? Math.floor(escrow.pot * 0.95) : escrow.pot;
    const winner = winnerRes?.value
      ? { ...winnerRes.value, stats: { ...winnerRes.value.stats } }
      : null;
    const loser = loserRes?.value
      ? { ...loserRes.value, stats: { ...loserRes.value.stats } }
      : null;
    const tx = kv.atomic().check(escrowRes).set(escrowKey, {
      ...escrow,
      settled: true,
    });

    if (winner) {
      winner.coins += payout;
      if (escrow.ranked) {
        winner.trophyPoints += 25;
        winner.cupTier = computeCupTier(winner.trophyPoints);
        winner.stats.totalMatches++;
        winner.stats.wins++;
        winner.stats.winStreak++;
        winner.stats.highestStreak = Math.max(
          winner.stats.highestStreak,
          winner.stats.winStreak,
        );
      }
      tx.check(winnerRes!).set(["users", winnerId], winner).set([
        "wallets",
        winnerId,
      ], winner.coins);
      addLedger(tx, winnerId, "match_payout", payout, winner.coins, roomId);
    }
    if (loser && loserId) {
      if (escrow.ranked) {
        loser.trophyPoints = Math.max(0, loser.trophyPoints - 15);
        loser.cupTier = computeCupTier(loser.trophyPoints);
        loser.stats.totalMatches++;
        loser.stats.losses++;
        loser.stats.winStreak = 0;
      }
      tx.check(loserRes!).set(["users", loserId], loser).set([
        "wallets",
        loserId,
      ], loser.coins);
    }

    const winnerTrophyDelta = winner && winnerRes?.value
      ? winner.trophyPoints - winnerRes.value.trophyPoints
      : 0;
    const loserTrophyDelta = loser && loserRes?.value
      ? loser.trophyPoints - loserRes.value.trophyPoints
      : 0;

    // Club rankings are derived from member ratings. Update them in the same
    // transaction as settlement so a club never displays stale trophies.
    if (escrow.ranked) {
      const clubDeltas = new Map<string, number>();
      if (winner?.clubId && winnerTrophyDelta !== 0) {
        clubDeltas.set(
          winner.clubId,
          (clubDeltas.get(winner.clubId) ?? 0) + winnerTrophyDelta,
        );
      }
      if (loser?.clubId && loserTrophyDelta !== 0) {
        clubDeltas.set(
          loser.clubId,
          (clubDeltas.get(loser.clubId) ?? 0) + loserTrophyDelta,
        );
      }
      for (const [clubId, delta] of clubDeltas) {
        const clubRes = await kv.get<Club>(["clubs", clubId]);
        if (clubRes.value) {
          tx.check(clubRes).set(["clubs", clubId], {
            ...clubRes.value,
            totalTrophies: Math.max(0, clubRes.value.totalTrophies + delta),
          });
        }
      }
    }

    const committed = await tx.commit();
    if (committed.ok) {
      leaderboardCache.clear();
      return {
        winner: winner
          ? settlementSide(winner, payout, winnerTrophyDelta)
          : null,
        loser: loser ? settlementSide(loser, 0, loserTrophyDelta) : null,
      };
    }
  }
  throw new HttpError(
    409,
    "SETTLEMENT_CONFLICT",
    "Match settlement conflicted. Please retry.",
  );
}

export async function purchasePen(
  userId: string,
  rawPenId: unknown,
): Promise<UserProfile> {
  const penId = cleanPenId(rawPenId);
  const pen = PEN_CATALOG[penId];
  for (let attempt = 0; attempt < 5; attempt++) {
    const result = await kv.get<UserProfile>(["users", userId]);
    if (!result.value) {
      throw new HttpError(404, "USER_NOT_FOUND", "Player not found.");
    }
    const profile = result.value;
    if (profile.unlockedPens.includes(penId)) {
      return equipPen(userId, penId);
    }
    if (playerLevel(profile.stats.wins) < pen.minLevel) {
      throw new HttpError(
        409,
        "LEVEL_REQUIRED",
        `Reach level ${pen.minLevel} to unlock this pen.`,
      );
    }
    if (profile.coins < pen.unlockPrice) {
      throw new HttpError(
        409,
        "INSUFFICIENT_COINS",
        "Not enough coins for this pen.",
      );
    }
    const updated: UserProfile = {
      ...profile,
      coins: profile.coins - pen.unlockPrice,
      equippedPen: penId,
      unlockedPens: [...profile.unlockedPens, penId],
      lastActiveAt: Date.now(),
    };
    const tx = kv.atomic().check(result)
      .set(["users", userId], updated)
      .set(["wallets", userId], updated.coins);
    addLedger(
      tx,
      userId,
      "pen_purchase",
      -pen.unlockPrice,
      updated.coins,
      penId,
    );
    const committed = await tx.commit();
    if (committed.ok) return updated;
  }
  throw new HttpError(
    409,
    "PURCHASE_CONFLICT",
    "Purchase conflicted. Please retry.",
  );
}

export async function equipPen(
  userId: string,
  rawPenId: unknown,
): Promise<UserProfile> {
  const penId = cleanPenId(rawPenId);
  const result = await kv.get<UserProfile>(["users", userId]);
  if (!result.value) {
    throw new HttpError(404, "USER_NOT_FOUND", "Player not found.");
  }
  if (!result.value.unlockedPens.includes(penId)) {
    throw new HttpError(
      409,
      "PEN_LOCKED",
      "Unlock this pen before equipping it.",
    );
  }
  const updated = {
    ...result.value,
    equippedPen: penId,
    lastActiveAt: Date.now(),
  };
  const committed = await kv.atomic().check(result).set(
    ["users", userId],
    updated,
  ).commit();
  if (!committed.ok) {
    throw new HttpError(
      409,
      "PROFILE_CONFLICT",
      "Profile changed. Please retry.",
    );
  }
  return updated;
}

export async function claimDailyReward(userId: string): Promise<{
  profile: UserProfile;
  reward: number;
  nextClaimAt: number;
}> {
  for (let attempt = 0; attempt < 5; attempt++) {
    const result = await kv.get<UserProfile>(["users", userId]);
    if (!result.value) {
      throw new HttpError(404, "USER_NOT_FOUND", "Player not found.");
    }
    const profile = result.value;
    const now = Date.now();
    const nextClaimAt = (profile.lastDailyRewardAt ?? 0) +
      DAILY_REWARD_COOLDOWN_MS;
    if (now < nextClaimAt) return { profile, reward: 0, nextClaimAt };
    const updated = {
      ...profile,
      coins: profile.coins + DAILY_REWARD_COINS,
      lastDailyRewardAt: now,
      lastActiveAt: now,
    };
    const tx = kv.atomic().check(result)
      .set(["users", userId], updated)
      .set(["wallets", userId], updated.coins);
    addLedger(
      tx,
      userId,
      "daily_reward",
      DAILY_REWARD_COINS,
      updated.coins,
      now.toString(),
    );
    const committed = await tx.commit();
    if (committed.ok) {
      return {
        profile: updated,
        reward: DAILY_REWARD_COINS,
        nextClaimAt: now + DAILY_REWARD_COOLDOWN_MS,
      };
    }
  }
  throw new HttpError(
    409,
    "REWARD_CONFLICT",
    "Reward claim conflicted. Please retry.",
  );
}

export async function addFriendByTagOrId(
  userId: string,
  targetQuery: string,
): Promise<UserProfile | null> {
  const query = optionalText(targetQuery, "", 128);
  if (!query) {
    throw new HttpError(400, "INVALID_INPUT", "Enter a player tag or ID.");
  }
  const target = await getUserByTag(query) ?? await getUserProfile(query);
  if (!target || target.id === userId) return null;

  for (let attempt = 0; attempt < 5; attempt++) {
    const userRes = await kv.get<UserProfile>(["users", userId]);
    const targetRes = await kv.get<UserProfile>(["users", target.id]);
    if (!userRes.value || !targetRes.value) return null;
    const user = {
      ...userRes.value,
      friends: [...new Set([...userRes.value.friends, target.id])],
    };
    const friend = {
      ...targetRes.value,
      friends: [...new Set([...targetRes.value.friends, userId])],
    };
    const committed = await kv.atomic().check(userRes).check(targetRes)
      .set(["users", userId], user).set(["users", target.id], friend).commit();
    if (committed.ok) return friend;
  }
  throw new HttpError(
    409,
    "FRIEND_CONFLICT",
    "Friend update conflicted. Please retry.",
  );
}

export async function removeFriend(
  userId: string,
  friendId: string,
): Promise<boolean> {
  const userRes = await kv.get<UserProfile>(["users", userId]);
  const friendRes = await kv.get<UserProfile>(["users", friendId]);
  if (!userRes.value) return false;
  const user = {
    ...userRes.value,
    friends: userRes.value.friends.filter((id) => id !== friendId),
  };
  const tx = kv.atomic().check(userRes).set(["users", userId], user);
  if (friendRes.value) {
    const friend = {
      ...friendRes.value,
      friends: friendRes.value.friends.filter((id) => id !== userId),
    };
    tx.check(friendRes).set(["users", friendId], friend);
  }
  return (await tx.commit()).ok;
}

export async function getFriendsList(userId: string): Promise<UserProfile[]> {
  const user = await getUserProfile(userId);
  if (!user) return [];
  const profiles = await Promise.all(
    user.friends.map((id) => getUserProfile(id)),
  );
  return profiles.filter((profile): profile is UserProfile => profile !== null)
    .map(toPublicProfile);
}

export const CLUB_CREATION_FEE = 20000;
const CLUB_MEMBER_LIMIT = 50;

export async function createClub(
  leaderId: string,
  name: string,
  tag: string,
  description: string,
  badgeIcon: string,
  region = "BD",
  flagEmoji = "🇧🇩",
): Promise<{ club: Club; profile: UserProfile }> {
  const clubName = cleanUsername(name);
  const cleanTag = tag.replace(/[\[\]\s]/g, "").toUpperCase();
  if (!/^[A-Z0-9]{3,4}$/.test(cleanTag)) {
    throw new HttpError(
      400,
      "INVALID_CLUB_TAG",
      "Club tag must contain 3-4 letters or numbers.",
    );
  }
  const formattedTag = `[${cleanTag}]`;
  const motto = optionalText(description, "", 240);
  const badge = optionalText(badgeIcon, "🛡️", 16);

  for (let attempt = 0; attempt < 5; attempt++) {
    const userRes = await kv.get<UserProfile>(["users", leaderId]);
    if (!userRes.value) {
      throw new HttpError(404, "USER_NOT_FOUND", "Player not found.");
    }
    const user = userRes.value;
    if (user.clubId) {
      throw new HttpError(
        409,
        "ALREADY_IN_CLUB",
        "Leave your current club first.",
      );
    }
    if (user.coins < CLUB_CREATION_FEE) {
      throw new HttpError(
        409,
        "INSUFFICIENT_COINS",
        `Founding a club costs ${CLUB_CREATION_FEE} coins.`,
      );
    }
    const tagRes = await kv.get<string>(["club_tags", formattedTag]);
    if (tagRes.value) {
      throw new HttpError(
        409,
        "CLUB_TAG_TAKEN",
        "That club tag is already in use.",
      );
    }
    const clubId = crypto.randomUUID();
    const club: Club = {
      id: clubId,
      name: clubName,
      tag: formattedTag,
      badgeIcon: badge,
      description: motto,
      leaderId,
      leaderName: user.username,
      membersCount: 1,
      totalTrophies: user.trophyPoints,
      region: cleanRegion(region, "BD"),
      flagEmoji: cleanFlag(flagEmoji, "🇧🇩"),
      createdAt: Date.now(),
    };
    const updated: UserProfile = {
      ...user,
      coins: user.coins - CLUB_CREATION_FEE,
      clubId,
      clubName,
      clubTag: formattedTag,
      clubRole: "leader",
    };
    const tx = kv.atomic().check(userRes).check(tagRes)
      .set(["users", leaderId], updated)
      .set(["wallets", leaderId], updated.coins)
      .set(["clubs", clubId], club)
      .set(["club_tags", formattedTag], clubId)
      .set(["club_members", clubId, leaderId], Date.now());
    addLedger(
      tx,
      leaderId,
      "club_creation",
      -CLUB_CREATION_FEE,
      updated.coins,
      clubId,
    );
    const committed = await tx.commit();
    if (committed.ok) return { club, profile: updated };
  }
  throw new HttpError(
    409,
    "CLUB_CONFLICT",
    "Club creation conflicted. Please retry.",
  );
}

export async function joinClub(
  userId: string,
  clubId: string,
): Promise<{ club: Club; profile: UserProfile }> {
  for (let attempt = 0; attempt < 5; attempt++) {
    const clubRes = await kv.get<Club>(["clubs", clubId]);
    const userRes = await kv.get<UserProfile>(["users", userId]);
    if (!clubRes.value) {
      throw new HttpError(404, "CLUB_NOT_FOUND", "Club not found.");
    }
    if (!userRes.value) {
      throw new HttpError(404, "USER_NOT_FOUND", "Player not found.");
    }
    if (userRes.value.clubId) {
      throw new HttpError(
        409,
        "ALREADY_IN_CLUB",
        "Leave your current club first.",
      );
    }
    if (clubRes.value.membersCount >= CLUB_MEMBER_LIMIT) {
      throw new HttpError(
        409,
        "CLUB_FULL",
        "This club has reached its member limit.",
      );
    }
    const club = {
      ...clubRes.value,
      membersCount: clubRes.value.membersCount + 1,
      totalTrophies: clubRes.value.totalTrophies + userRes.value.trophyPoints,
    };
    const profile: UserProfile = {
      ...userRes.value,
      clubId,
      clubName: club.name,
      clubTag: club.tag,
      clubRole: "member",
    };
    const committed = await kv.atomic().check(clubRes).check(userRes)
      .set(["clubs", clubId], club)
      .set(["users", userId], profile)
      .set(["club_members", clubId, userId], Date.now())
      .commit();
    if (committed.ok) return { club, profile };
  }
  throw new HttpError(
    409,
    "CLUB_CONFLICT",
    "Club join conflicted. Please retry.",
  );
}

export async function leaveClub(userId: string): Promise<UserProfile> {
  for (let attempt = 0; attempt < 5; attempt++) {
    const userRes = await kv.get<UserProfile>(["users", userId]);
    if (!userRes.value?.clubId) {
      throw new HttpError(409, "NOT_IN_CLUB", "You are not in a club.");
    }
    const clubId = userRes.value.clubId;
    const clubRes = await kv.get<Club>(["clubs", clubId]);
    if (!clubRes.value) {
      const repaired = {
        ...userRes.value,
        clubId: null,
        clubName: null,
        clubTag: null,
        clubRole: null,
      };
      await kv.atomic().check(userRes).set(["users", userId], repaired)
        .commit();
      return repaired;
    }
    const club = clubRes.value;
    const profile: UserProfile = {
      ...userRes.value,
      clubId: null,
      clubName: null,
      clubTag: null,
      clubRole: null,
    };
    const tx = kv.atomic().check(userRes).check(clubRes)
      .set(["users", userId], profile)
      .delete(["club_members", clubId, userId]);

    if (club.membersCount <= 1) {
      tx.delete(["clubs", clubId]).delete(["club_tags", club.tag]);
    } else {
      const updatedClub = {
        ...club,
        membersCount: club.membersCount - 1,
        totalTrophies: Math.max(
          0,
          club.totalTrophies - userRes.value.trophyPoints,
        ),
      };
      if (club.leaderId === userId) {
        const members: { id: string; joinedAt: number }[] = [];
        for await (
          const entry of kv.list<number>({ prefix: ["club_members", clubId] })
        ) {
          const id = String(entry.key[entry.key.length - 1]);
          if (id !== userId) {
            members.push({
              id,
              joinedAt: typeof entry.value === "number" ? entry.value : 0,
            });
          }
        }
        members.sort((a, b) => a.joinedAt - b.joinedAt);
        const successorId = members[0]?.id;
        if (!successorId) {
          throw new HttpError(
            409,
            "CLUB_CONFLICT",
            "Club membership changed. Please retry.",
          );
        }
        const successorRes = await kv.get<UserProfile>(["users", successorId]);
        if (!successorRes.value) {
          throw new HttpError(
            409,
            "CLUB_CONFLICT",
            "Club membership changed. Please retry.",
          );
        }
        updatedClub.leaderId = successorId;
        updatedClub.leaderName = successorRes.value.username;
        tx.check(successorRes).set(["users", successorId], {
          ...successorRes.value,
          clubRole: "leader",
        });
      }
      tx.set(["clubs", clubId], updatedClub);
    }
    const committed = await tx.commit();
    if (committed.ok) return profile;
  }
  throw new HttpError(
    409,
    "CLUB_CONFLICT",
    "Club update conflicted. Please retry.",
  );
}

export async function getClubsList(): Promise<Club[]> {
  const clubs: Club[] = [];
  for await (
    const entry of kv.list<Club>({ prefix: ["clubs"] }, { limit: 200 })
  ) {
    clubs.push(entry.value);
  }
  clubs.sort((a, b) => b.totalTrophies - a.totalTrophies);
  return clubs.slice(0, 100);
}

export async function getLeaderboardData(
  filter: "global" | "division" | "friends" | "trophies",
  division?: BangladeshiDivision,
  userId?: string,
): Promise<UserProfile[]> {
  const cacheKey = `${filter}_${division ?? "all"}_${userId ?? "none"}`;
  const cached = leaderboardCache.get(cacheKey);
  if (cached && cached.expiresAt > Date.now()) return cached.data;

  const users: UserProfile[] = [];
  for await (const entry of kv.list<UserProfile>({ prefix: ["users"] })) {
    users.push(entry.value);
  }
  let filtered = users;
  if (filter === "division" && division) {
    filtered = users.filter((u) => u.division === division);
  }
  if (filter === "friends") {
    if (!userId) return [];
    const user = users.find((u) => u.id === userId);
    const friendSet = new Set(user?.friends ?? []);
    friendSet.add(userId);
    filtered = users.filter((u) => friendSet.has(u.id));
  }
  filtered.sort((a, b) =>
    b.trophyPoints - a.trophyPoints || b.stats.wins - a.stats.wins ||
    a.createdAt - b.createdAt
  );
  const result = filtered.slice(0, 50).map(toPublicProfile);
  leaderboardCache.set(cacheKey, {
    data: result,
    expiresAt: Date.now() + 30000,
  });
  return result;
}

export interface SafeProfileUpdates {
  username?: string;
  avatar?: string;
  region?: string;
  flagEmoji?: string;
  division?: string;
}

export async function updateUserProfile(
  userId: string,
  updates: SafeProfileUpdates,
): Promise<UserProfile | null> {
  const result = await kv.get<UserProfile>(["users", userId]);
  if (!result.value) return null;
  const current = result.value;
  if (
    updates.avatar && updates.avatar.startsWith("https://") &&
    updates.avatar !== current.googlePhotoUrl
  ) {
    throw new HttpError(
      400,
      "INVALID_AVATAR",
      "Only your verified Google photo can be used as a remote avatar.",
    );
  }
  const updated: UserProfile = {
    ...current,
    username: updates.username === undefined
      ? current.username
      : cleanUsername(updates.username),
    avatar: updates.avatar === undefined
      ? current.avatar
      : updates.avatar === current.googlePhotoUrl
      ? updates.avatar
      : cleanAvatar(updates.avatar),
    region: updates.region === undefined
      ? current.region
      : cleanRegion(updates.region),
    flagEmoji: updates.flagEmoji === undefined
      ? current.flagEmoji
      : cleanFlag(updates.flagEmoji),
    division: updates.division === undefined
      ? current.division
      : cleanDivision(updates.division),
    lastActiveAt: Date.now(),
  };
  const committed = await kv.atomic().check(result).set(
    ["users", userId],
    updated,
  ).commit();
  if (!committed.ok) {
    throw new HttpError(
      409,
      "PROFILE_CONFLICT",
      "Profile changed. Please retry.",
    );
  }
  leaderboardCache.clear();
  return updated;
}

export async function databaseHealthCheck(): Promise<boolean> {
  try {
    await kv.get(["health", "probe"]);
    return true;
  } catch {
    return false;
  }
}
