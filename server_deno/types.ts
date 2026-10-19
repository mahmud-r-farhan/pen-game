// server_deno/types.ts

export type BangladeshiDivision =
  | "Dhaka"
  | "Chattogram"
  | "Rajshahi"
  | "Khulna"
  | "Sylhet"
  | "Barishal"
  | "Rangpur"
  | "Mymensingh";

export type TrophyCupTier = "bronze" | "silver" | "gold" | "diamond" | "grandmaster";

export interface UserStats {
  totalMatches: number;
  wins: number;
  losses: number;
  winStreak: number;
  highestStreak: number;
}

export interface UserProfile {
  id: string; // Internal UID (UUID or Firebase UID)
  tag: string; // Display Tag e.g. #KLM-8492
  username: string;
  email?: string;
  avatar: string; // Avatar ID / asset path
  coins: number; // Virtual in-game currency (Guest: 75, Google: 120)
  trophyPoints: number; // Skill Rating Points (RP) - Separate from coins!
  cupTier: TrophyCupTier; // Achievement Cup
  region: string; // e.g. "BD", "IN", "PK", "US", "GLOBAL"
  flagEmoji: string; // e.g. "🇧🇩", "🇮🇳", "🇵🇰", "🇺🇸", "🌐"
  clubId?: string | null;
  clubName?: string | null;
  clubRole?: "leader" | "officer" | "member" | null;
  equippedPen: string;
  unlockedPens: string[];
  isGuest: boolean;
  googleId?: string;
  facebookId?: string;
  googlePhotoUrl?: string;
  division: BangladeshiDivision;
  friends: string[]; // List of user IDs
  stats: UserStats;
  createdAt: number;
  lastActiveAt: number;
}

export interface Club {
  id: string;
  name: string;
  tag: string; // e.g. [WAR]
  badgeIcon: string;
  description: string;
  leaderId: string;
  leaderName: string;
  membersCount: number;
  totalTrophies: number;
  region: string;
  flagEmoji: string;
  createdAt: number;
}

export interface ArenaRoomConfig {
  id: string;
  name: string;
  nameBn: string; // Bengali name
  category: "school" | "college" | "university";
  subCategory?: string; // e.g. "Polytechnic", "Medical", "National University", "Cadet"
  entryCoins: number;
  potCoins: number;
  payoutCoins: number; // 90% payout, 10% platform sink
  description: string;
  descriptionBn: string;
  tableColorStart: string;
  tableColorEnd: string;
  tableTexture: "wood_scratched" | "varnished_teak" | "drafting_green" | "stainless_steel" | "exam_mahogany" | "military_cherry" | "executive_glass";
  friction: number; // Linear damping factor
  angularDamping: number; // Spin damping factor
  bounce: number; // Table edge bounce
}

export interface PlayerSession {
  userId: string;
  username: string;
  tag: string;
  avatar: string;
  stake: number;
  roomTypeId: string;
  penModel: string;
  socket: WebSocket;
  roomId?: string;
  trophyPoints?: number;
}

import { HitEvent, KeyframeSample, SimState } from "./physics_sim.ts";

export interface MatchRoom {
  roomId: string;
  roomTypeId: string;
  stake: number;
  pot: number;
  p1: PlayerSession;
  p2: PlayerSession | null; // null if Ghost Bot
  isGhostBotMatch: boolean;
  botName?: string;
  botPen?: string;
  currentTurnUserId: string;
  turnNumber: number;
  turnTimerSeconds: number;
  consecutiveTimeouts: { [userId: string]: number };
  status: "WAITING" | "PLAYING" | "SETTLED";
  createdAt: number;
  simState?: SimState;
  scores?: [number, number];
}

// WebSocket Packets
export type WsClientAction =
  | { type: "AUTH"; userId: string; username?: string; avatar?: string; division?: BangladeshiDivision; region?: string; flagEmoji?: string }
  | { type: "QUEUE_JOIN"; roomTypeId: string; penModel: string }
  | { type: "QUEUE_LEAVE" }
  | { type: "ROOM_CODE_CREATE"; roomTypeId: string; penModel: string }
  | { type: "ROOM_CODE_JOIN"; roomCode: string; penModel: string }
  | { type: "FRIEND_CHALLENGE_SEND"; targetUserId: string; roomTypeId: string; penModel: string }
  | { type: "FRIEND_CHALLENGE_RESPOND"; challengeId: string; accept: boolean; penModel?: string }
  | { type: "FLICK_SUBMIT"; impulseX: number; impulseY: number; strikeOffset: number }
  | { type: "SHOT_SUBMIT"; ang: number; power: number; rx?: number; ry?: number }
  | { type: "AIMING_UPDATE"; isAiming: boolean; pullX: number; pullY: number; strikeOffset: number }
  | { type: "PASS_TURN" }
  | { type: "EMOJI_CHAT"; emojiId: string; textBn: string; textEn?: string }
  | { type: "MATCH_KNOCKOUT"; winnerId: string; reason?: string }
  | { type: "SURRENDER" }
  | { type: "REMATCH_REQUEST" }
  | { type: "REMATCH_RESPOND"; accept: boolean };

export type WsServerEvent =
  | { type: "AUTH_SUCCESS"; profile: UserProfile }
  | { type: "WALLET_SYNC"; coins: number; trophyPoints: number }
  | { type: "QUEUE_WAITING"; roomTypeId: string; estimatedSec: number }
  | { type: "MATCH_START"; roomId: string; roomTypeId: string; pot: number; firstTurn: string; p1: PublicPlayer; p2: PublicPlayer }
  | { type: "AIMING_SYNC"; actorId: string; isAiming: boolean; pullX: number; pullY: number; strikeOffset: number }
  | { type: "FLICK_EXECUTE"; actorId: string; impulseX: number; impulseY: number; strikeOffset: number; nextTurn: string }
  | { type: "SHOT_RESULT"; actorId: string; frames: KeyframeSample[]; events: HitEvent[]; fell: number; winner: number; nextTurn: string; scores?: [number, number] }
  | { type: "TURN_TIMER_TICK"; secondsLeft: number; activeUserId: string }
  | { type: "TURN_TIMEOUT"; timedOutUserId: string; nextTurnUserId: string }
  | { type: "EMOJI_BROADCAST"; senderId: string; emojiId: string; textBn: string; textEn?: string }
  | { type: "REMATCH_OFFER"; requesterId: string; requesterName: string; roomTypeId: string }
  | { type: "REMATCH_DECLINED"; reason: string }
  | { type: "MATCH_OVER"; winnerId: string; payout: number; newBalance: number; trophyDelta: number; newTrophies: number; cupTier: TrophyCupTier }
  | { type: "ROOM_CODE_CREATED"; roomCode: string }
  | { type: "FRIEND_CHALLENGE_RECEIVED"; challengeId: string; fromUser: PublicPlayer; roomTypeId: string; stake: number }
  | { type: "ERROR"; message: string };

export interface PublicPlayer {
  id: string;
  username: string;
  tag: string;
  avatar: string;
  penModel: string;
  trophyPoints?: number;
  cupTier?: TrophyCupTier;
  flagEmoji?: string;
  clubTag?: string;
}
