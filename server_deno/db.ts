// server_deno/db.ts
/// <reference path="./deno.d.ts" />
import { BangladeshiDivision, Club, TrophyCupTier, UserProfile } from "./types.ts";

const kv = await Deno.openKv();

// High-speed In-Memory Leaderboard Cache (30s TTL)
interface CacheEntry<T> {
  data: T;
  expiresAt: number;
}
const leaderboardCache = new Map<string, CacheEntry<UserProfile[]>>();

function generateTag(): string {
  const digits = Math.floor(1000 + Math.random() * 9000);
  return `#KLM-${digits}`;
}

export function computeCupTier(trophies: number): TrophyCupTier {
  if (trophies >= 5000) return "grandmaster";
  if (trophies >= 2500) return "diamond";
  if (trophies >= 1200) return "gold";
  if (trophies >= 500) return "silver";
  return "bronze";
}

export async function getUserProfile(userId: string): Promise<UserProfile | null> {
  const res = await kv.get<UserProfile>(["users", userId]);
  return res.value;
}

export async function getUserByTag(tag: string): Promise<UserProfile | null> {
  const idRes = await kv.get<string>(["tags", tag.toUpperCase()]);
  if (!idRes.value) return null;
  return getUserProfile(idRes.value);
}

export async function ensureUser(
  userId: string,
  isGuest: boolean,
  name?: string,
  avatar?: string,
  division?: BangladeshiDivision,
  region?: string,
  flagEmoji?: string,
): Promise<UserProfile> {
  const existing = await getUserProfile(userId);
  if (existing) {
    existing.lastActiveAt = Date.now();
    if (region && !existing.region) existing.region = region;
    if (flagEmoji && !existing.flagEmoji) existing.flagEmoji = flagEmoji;
    await kv.set(["users", userId], existing);
    return existing;
  }

  const tag = generateTag();
  // Default guest account gets 75 coins only, authenticated gets 120 coins
  const initialCoins = isGuest ? 75 : 120;
  const initialTrophies = 100;

  const profile: UserProfile = {
    id: userId,
    tag,
    username: name ?? (isGuest ? `Guest_${tag.replace("#KLM-", "")}` : "Kolom Warrior"),
    avatar: avatar ?? "avatar_student_boy",
    coins: initialCoins,
    trophyPoints: initialTrophies,
    cupTier: computeCupTier(initialTrophies),
    region: region ?? "BD",
    flagEmoji: flagEmoji ?? "🇧🇩",
    clubId: null,
    clubName: null,
    clubRole: null,
    equippedPen: "hiSchoolClassic",
    unlockedPens: ["hiSchoolClassic", "econoStriker"],
    isGuest,
    division: division ?? "Dhaka",
    friends: [],
    stats: {
      totalMatches: 0,
      wins: 0,
      losses: 0,
      winStreak: 0,
      highestStreak: 0,
    },
    createdAt: Date.now(),
    lastActiveAt: Date.now(),
  };

  await kv.atomic()
    .set(["users", userId], profile)
    .set(["tags", tag.toUpperCase()], userId)
    .set(["wallets", userId], profile.coins)
    .commit();

  return profile;
}

/**
 * Merges a temporary Guest account into an authenticated Google / Facebook account.
 * Guarantees that coins earned, unlocked pens, and trophies are combined atomically.
 */
export async function mergeGuestIntoGoogleAccount(
  guestId: string,
  googleUid: string,
  googleName: string,
  googleEmail: string,
  googleAvatar: string,
  provider: "google" | "facebook" = "google",
): Promise<UserProfile> {
  const guestRes = await kv.get<UserProfile>(["users", guestId]);
  const googleRes = await kv.get<UserProfile>(["users", googleUid]);

  const guest = guestRes.value;

  if (!googleRes.value) {
    // Google account does not exist yet: Upgrade guest profile directly into Google account
    const newProfile: UserProfile = guest
      ? {
          ...guest,
          id: googleUid,
          username: googleName.trim().length > 0 ? googleName : guest.username,
          email: googleEmail,
          avatar: googleAvatar.trim().length > 0 ? googleAvatar : guest.avatar,
          isGuest: false,
          coins: Math.max(120, guest.coins + 45), // Google bonus upgrade
          googleId: provider === "google" ? googleUid : undefined,
          facebookId: provider === "facebook" ? googleUid : undefined,
          lastActiveAt: Date.now(),
        }
      : {
          id: googleUid,
          tag: generateTag(),
          username: googleName,
          email: googleEmail,
          avatar: googleAvatar,
          coins: 120,
          trophyPoints: 100,
          cupTier: "bronze",
          region: "BD",
          flagEmoji: "🇧🇩",
          clubId: null,
          clubName: null,
          clubRole: null,
          equippedPen: "hiSchoolClassic",
          unlockedPens: ["hiSchoolClassic", "econoStriker"],
          isGuest: false,
          googleId: provider === "google" ? googleUid : undefined,
          facebookId: provider === "facebook" ? googleUid : undefined,
          division: "Dhaka",
          friends: [],
          stats: { totalMatches: 0, wins: 0, losses: 0, winStreak: 0, highestStreak: 0 },
          createdAt: Date.now(),
          lastActiveAt: Date.now(),
        };

    const atomicTx = kv.atomic()
      .set(["users", googleUid], newProfile)
      .set(["tags", newProfile.tag.toUpperCase()], googleUid)
      .set(["wallets", googleUid], newProfile.coins);

    if (provider === "google") {
      atomicTx.set(["google_to_uid", googleUid], googleUid);
    } else {
      atomicTx.set(["fb_users", googleUid], googleUid);
    }

    if (guest) {
      atomicTx.delete(["users", guestId]);
      atomicTx.delete(["wallets", guestId]);
      atomicTx.delete(["tags", guest.tag.toUpperCase()]);
    }

    await atomicTx.commit();
    return newProfile;
  }

  // Google account already existed: Merge guest assets into the Google account!
  const googleProfile = googleRes.value;
  if (guest) {
    const combinedCoins = (googleProfile.coins || 0) + (guest.coins || 0);
    const combinedTrophies = Math.max(googleProfile.trophyPoints || 100, (guest.trophyPoints || 100));
    const combinedPens = Array.from(new Set([...googleProfile.unlockedPens, ...guest.unlockedPens]));
    const combinedFriends = Array.from(new Set([...googleProfile.friends, ...guest.friends]));

    googleProfile.coins = combinedCoins;
    googleProfile.trophyPoints = combinedTrophies;
    googleProfile.cupTier = computeCupTier(combinedTrophies);
    googleProfile.unlockedPens = combinedPens;
    googleProfile.friends = combinedFriends;
    googleProfile.stats.totalMatches += guest.stats.totalMatches;
    googleProfile.stats.wins += guest.stats.wins;
    googleProfile.stats.losses += guest.stats.losses;
    googleProfile.stats.winStreak = Math.max(googleProfile.stats.winStreak, guest.stats.winStreak);
    googleProfile.stats.highestStreak = Math.max(googleProfile.stats.highestStreak, guest.stats.highestStreak);
    googleProfile.lastActiveAt = Date.now();

    await kv.atomic()
      .check(googleRes)
      .set(["users", googleUid], googleProfile)
      .set(["wallets", googleUid], combinedCoins)
      .delete(["users", guestId])
      .delete(["wallets", guestId])
      .delete(["tags", guest.tag.toUpperCase()])
      .commit();

    return googleProfile;
  }

  return googleProfile;
}

/**
 * Atomic coin escrow lock:
 * Deducts stake from players and registers match escrow.
 */
export async function atomicEscrowLock(
  p1Id: string,
  p2Id: string | null,
  stake: number,
  roomId: string,
): Promise<boolean> {
  if (stake <= 0) return true;

  const p1Res = await kv.get<UserProfile>(["users", p1Id]);
  if (!p1Res.value || p1Res.value.coins < stake) return false;

  let p2Res: Deno.KvEntryMaybe<UserProfile> | null = null;
  if (p2Id && p2Id !== "GHOST_BOT") {
    p2Res = await kv.get<UserProfile>(["users", p2Id]);
    if (!p2Res.value || p2Res.value.coins < stake) return false;
  }

  const p1Updated = { ...p1Res.value, coins: p1Res.value.coins - stake };
  const tx = kv.atomic()
    .check(p1Res)
    .set(["users", p1Id], p1Updated)
    .set(["wallets", p1Id], p1Updated.coins)
    .set(["match_escrow", roomId], {
      roomId,
      stake,
      pot: stake * 2,
      settled: false,
    });

  if (p2Res && p2Res.value && p2Id) {
    const p2Updated = { ...p2Res.value, coins: p2Res.value.coins - stake };
    tx.check(p2Res)
      .set(["users", p2Id], p2Updated)
      .set(["wallets", p2Id], p2Updated.coins);
  }

  const commitRes = await tx.commit();
  return commitRes.ok;
}

/**
 * Match settlement with 10% platform coin sink + Trophy rating updates
 */
export async function settleMatchWinner(
  roomId: string,
  winnerId: string,
  pot: number,
  loserId?: string,
): Promise<{ newBalance: number; payout: number; trophyDelta: number; newTrophies: number; cupTier: TrophyCupTier }> {
  const escrowKey = ["match_escrow", roomId];
  const escrowRes = await kv.get<{ roomId: string; settled: boolean; pot: number }>(escrowKey);

  if (escrowRes.value?.settled) {
    const user = await getUserProfile(winnerId);
    return {
      newBalance: user?.coins ?? 0,
      payout: 0,
      trophyDelta: 0,
      newTrophies: user?.trophyPoints ?? 100,
      cupTier: user?.cupTier ?? "bronze",
    };
  }

  // Clear leaderboard cache on match settlement
  leaderboardCache.clear();

  const payout = Math.floor(pot * 0.95); // 5% platform fee on winning prize

  if (winnerId !== "GHOST_BOT") {
    const winnerRes = await kv.get<UserProfile>(["users", winnerId]);
    if (winnerRes.value) {
      const winner = winnerRes.value;
      const updatedCoins = winner.coins + payout;
      winner.coins = updatedCoins;
      // Trophy gain: +25 RP on victory
      const updatedTrophies = (winner.trophyPoints || 100) + 25;
      winner.trophyPoints = updatedTrophies;
      winner.cupTier = computeCupTier(updatedTrophies);
      winner.stats.totalMatches += 1;
      winner.stats.wins += 1;
      winner.stats.winStreak += 1;
      winner.stats.highestStreak = Math.max(winner.stats.highestStreak, winner.stats.winStreak);

      const tx = kv.atomic()
        .set(["users", winnerId], winner)
        .set(["wallets", winnerId], updatedCoins)
        .set(escrowKey, { roomId, settled: true, pot })
        .commit();

      await tx;

      if (loserId && loserId !== "GHOST_BOT") {
        const loserRes = await kv.get<UserProfile>(["users", loserId]);
        if (loserRes.value) {
          const loser = loserRes.value;
          loser.stats.totalMatches += 1;
          loser.stats.losses += 1;
          loser.stats.winStreak = 0;
          // Trophy loss: -15 RP on defeat
          const loserTrophies = Math.max(0, (loser.trophyPoints || 100) - 15);
          loser.trophyPoints = loserTrophies;
          loser.cupTier = computeCupTier(loserTrophies);
          await kv.set(["users", loserId], loser);
        }
      }

      return {
        newBalance: updatedCoins,
        payout,
        trophyDelta: 25,
        newTrophies: updatedTrophies,
        cupTier: winner.cupTier,
      };
    }
  }

  // If Ghost Bot won against human loser:
  if (loserId && loserId !== "GHOST_BOT") {
    const loserRes = await kv.get<UserProfile>(["users", loserId]);
    if (loserRes.value) {
      const loser = loserRes.value;
      loser.stats.totalMatches += 1;
      loser.stats.losses += 1;
      loser.stats.winStreak = 0;
      const loserTrophies = Math.max(0, (loser.trophyPoints || 100) - 15);
      loser.trophyPoints = loserTrophies;
      loser.cupTier = computeCupTier(loserTrophies);
      await kv.set(["users", loserId], loser);
    }
  }

  await kv.set(escrowKey, { roomId, settled: true, pot });
  return { newBalance: 0, payout: 0, trophyDelta: 0, newTrophies: 100, cupTier: "bronze" };
}

/**
 * Friend Operations
 */
export async function addFriendByTagOrId(userId: string, targetQuery: string): Promise<UserProfile | null> {
  let target = await getUserByTag(targetQuery);
  if (!target) {
    target = await getUserProfile(targetQuery);
  }
  if (!target || target.id === userId) return null;

  const user = await getUserProfile(userId);
  if (!user) return null;

  if (!user.friends.includes(target.id)) {
    user.friends.push(target.id);
    await kv.set(["users", userId], user);
  }

  if (!target.friends.includes(user.id)) {
    target.friends.push(user.id);
    await kv.set(["users", target.id], target);
  }

  return target;
}

export async function removeFriend(userId: string, friendId: string): Promise<boolean> {
  const user = await getUserProfile(userId);
  if (!user) return false;

  user.friends = user.friends.filter((id) => id !== friendId);
  await kv.set(["users", userId], user);

  const friend = await getUserProfile(friendId);
  if (friend) {
    friend.friends = friend.friends.filter((id) => id !== userId);
    await kv.set(["users", friendId], friend);
  }
  return true;
}

export async function getFriendsList(userId: string): Promise<UserProfile[]> {
  const user = await getUserProfile(userId);
  if (!user || user.friends.length === 0) return [];

  const friendProfiles: UserProfile[] = [];
  for (const fId of user.friends) {
    const profile = await getUserProfile(fId);
    if (profile) friendProfiles.push(profile);
  }
  return friendProfiles;
}

export async function linkFacebookFriends(
  userId: string,
  facebookId: string,
  facebookFriendIds: string[],
): Promise<UserProfile[]> {
  const user = await getUserProfile(userId);
  if (!user) return [];

  user.facebookId = facebookId;
  await kv.set(["users", userId], user);
  await kv.set(["fb_users", facebookId], userId);

  const matchedFriends: UserProfile[] = [];
  for (const fbId of facebookFriendIds) {
    const linkedUserId = await kv.get<string>(["fb_users", fbId]);
    if (linkedUserId.value) {
      const friendProfile = await getUserProfile(linkedUserId.value);
      if (friendProfile) {
        matchedFriends.push(friendProfile);
        if (!user.friends.includes(friendProfile.id)) {
          user.friends.push(friendProfile.id);
        }
      }
    }
  }

  await kv.set(["users", userId], user);
  return matchedFriends;
}

/**
 * Club / Guild System
 */
export const CLUB_CREATION_FEE = 20000;

export async function createClub(
  leaderId: string,
  name: string,
  tag: string,
  description: string,
  badgeIcon: string,
  region = "BD",
  flagEmoji = "🇧🇩",
): Promise<Club | null> {
  const user = await getUserProfile(leaderId);
  if (!user) return null;

  // Rule: Cannot create a club if already joined or in a club
  if (user.clubId) {
    return null;
  }

  // Rule: Creating club requires 20,000 coins
  if (user.coins < CLUB_CREATION_FEE) {
    return null;
  }

  const clubId = crypto.randomUUID().slice(0, 8);
  const formattedTag = tag.startsWith("[") ? tag : `[${tag.toUpperCase()}]`;

  const club: Club = {
    id: clubId,
    name,
    tag: formattedTag,
    badgeIcon,
    description,
    leaderId,
    leaderName: user.username,
    membersCount: 1,
    totalTrophies: user.trophyPoints ?? 100,
    region,
    flagEmoji,
    createdAt: Date.now(),
  };

  user.coins -= CLUB_CREATION_FEE;
  user.clubId = clubId;
  user.clubName = name;
  user.clubRole = "leader";

  const tx = kv.atomic()
    .set(["users", leaderId], user)
    .set(["wallets", leaderId], user.coins)
    .set(["clubs", clubId], club)
    .set(["club_members", clubId, leaderId], true);

  const res = await tx.commit();
  if (!res.ok) return null;

  return club;
}

export async function joinClub(userId: string, clubId: string): Promise<Club | null> {
  const clubRes = await kv.get<Club>(["clubs", clubId]);
  if (!clubRes.value) return null;

  const club = clubRes.value;
  const user = await getUserProfile(userId);
  if (!user) return null;

  club.membersCount += 1;
  club.totalTrophies += user.trophyPoints || 100;

  user.clubId = clubId;
  user.clubName = club.name;
  user.clubRole = "member";

  await kv.set(["clubs", clubId], club);
  await kv.set(["users", userId], user);
  await kv.set(["club_members", clubId, userId], true);
  return club;
}

export async function getClubsList(): Promise<Club[]> {
  const iter = kv.list<Club>({ prefix: ["clubs"] });
  const clubs: Club[] = [];
  for await (const entry of iter) {
    clubs.push(entry.value);
  }
  clubs.sort((a, b) => b.totalTrophies - a.totalTrophies);
  return clubs;
}

/**
 * High-Speed Cached Leaderboards (<2ms response)
 */
export async function getLeaderboardData(
  filter: "global" | "division" | "friends" | "trophies",
  division?: BangladeshiDivision,
  userId?: string,
): Promise<UserProfile[]> {
  const cacheKey = `${filter}_${division ?? "all"}_${userId ?? "none"}`;
  const cached = leaderboardCache.get(cacheKey);
  const now = Date.now();

  if (cached && cached.expiresAt > now) {
    return cached.data;
  }

  const usersIterator = kv.list<UserProfile>({ prefix: ["users"] });
  const allUsers: UserProfile[] = [];

  for await (const entry of usersIterator) {
    allUsers.push(entry.value);
  }

  let filtered = allUsers;

  if (filter === "division" && division) {
    filtered = allUsers.filter((u) => u.division === division);
  } else if (filter === "friends" && userId) {
    const user = allUsers.find((u) => u.id === userId);
    const friendSet = new Set(user?.friends ?? []);
    friendSet.add(userId);
    filtered = allUsers.filter((u) => friendSet.has(u.id));
  }

  // Sort by Trophy Points (primary skill ranking) and then Wins / Coins
  filtered.sort((a, b) => {
    const tB = b.trophyPoints || 0;
    const tA = a.trophyPoints || 0;
    if (tB !== tA) return tB - tA;
    if (b.stats.wins !== a.stats.wins) return b.stats.wins - a.stats.wins;
    return b.coins - a.coins;
  });

  const topUsers = filtered.slice(0, 50);

  // Cache for 30 seconds
  leaderboardCache.set(cacheKey, {
    data: topUsers,
    expiresAt: now + 30000,
  });

  return topUsers;
}

export async function updateUserProfile(
  userId: string,
  updates: Partial<UserProfile>,
): Promise<UserProfile | null> {
  const existing = await getUserProfile(userId);
  if (!existing) return null;
  const updated: UserProfile = {
    ...existing,
    ...updates,
    lastActiveAt: Date.now(),
  };
  await kv.set(["users", userId], updated);
  return updated;
}

