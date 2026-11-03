// server_deno/types.ts
import { HitEvent, KeyframeSample, SimState } from "./physics_sim.ts";

// International players can select a city as well as a Bangladeshi division.
export type BangladeshiDivision = string;
export type TrophyCupTier =
  | "bronze"
  | "silver"
  | "gold"
  | "diamond"
  | "grandmaster";

export interface UserStats {
  totalMatches: number;
  wins: number;
  losses: number;
  winStreak: number;
  highestStreak: number;
}

export interface UserProfile {
  id: string;
  tag: string;
  username: string;
  email?: string;
  avatar: string;
  coins: number;
  trophyPoints: number;
  cupTier: TrophyCupTier;
  region: string;
  flagEmoji: string;
  clubId?: string | null;
  clubName?: string | null;
  clubTag?: string | null;
  clubRole?: "leader" | "officer" | "member" | null;
  equippedPen: string;
  unlockedPens: string[];
  isGuest: boolean;
  googleId?: string;
  googlePhotoUrl?: string;
  division: BangladeshiDivision;
  friends: string[];
  stats: UserStats;
  createdAt: number;
  lastActiveAt: number;
  lastDailyRewardAt?: number;
}

export interface Club {
  id: string;
  name: string;
  tag: string;
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
  nameBn: string;
  category: "school" | "college" | "university";
  subCategory?: string;
  entryCoins: number;
  potCoins: number;
  payoutCoins: number;
  description: string;
  descriptionBn: string;
  tableColorStart: string;
  tableColorEnd: string;
  tableTexture:
    | "wood_scratched"
    | "varnished_teak"
    | "drafting_green"
    | "stainless_steel"
    | "exam_mahogany"
    | "military_cherry"
    | "executive_glass";
  friction: number;
  angularDamping: number;
  bounce: number;
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
  /** Synchronous reservation held across asynchronous match creation. */
  matchPending?: boolean;
  trophyPoints?: number;
  authenticatedAt: number;
}

export interface MatchRoom {
  roomId: string;
  roomTypeId: string;
  stake: number;
  pot: number;
  p1: PlayerSession;
  p2: PlayerSession | null;
  currentTurnUserId: string;
  turnNumber: number;
  turnTimerSeconds: number;
  consecutiveTimeouts: { [userId: string]: number };
  status: "WAITING" | "PLAYING" | "SETTLED";
  inputLocked: boolean;
  createdAt: number;
  simState?: SimState;
  scores?: [number, number];
}

export type WsClientAction =
  | { type: "QUEUE_JOIN"; roomTypeId: string; penModel: string }
  | { type: "QUEUE_LEAVE" }
  | { type: "ROOM_CODE_CREATE"; roomTypeId: string; penModel: string }
  | { type: "ROOM_CODE_JOIN"; roomCode: string; penModel: string }
  | { type: "ROOM_CODE_CANCEL" }
  | {
    type: "FRIEND_CHALLENGE_SEND";
    targetUserId: string;
    roomTypeId: string;
    penModel: string;
  }
  | {
    type: "FRIEND_CHALLENGE_RESPOND";
    challengeId: string;
    accept: boolean;
    penModel?: string;
  }
  | {
    type: "FLICK_SUBMIT";
    impulseX: number;
    impulseY: number;
    strikeOffset: number;
  }
  | {
    type: "SHOT_SUBMIT";
    ang: number;
    power: number;
    rx?: number;
    ry?: number;
  }
  | {
    type: "AIMING_UPDATE";
    isAiming: boolean;
    pullX: number;
    pullY: number;
    strikeOffset: number;
  }
  | { type: "PASS_TURN" }
  | { type: "EMOJI_CHAT"; emojiId: string; textBn: string; textEn?: string }
  | { type: "SURRENDER" }
  | { type: "REMATCH_REQUEST" }
  | { type: "REMATCH_RESPOND"; accept: boolean };

export type WsServerEvent =
  | { type: "AUTH_SUCCESS"; profile: UserProfile }
  | { type: "WALLET_SYNC"; coins: number; trophyPoints: number }
  | { type: "QUEUE_WAITING"; roomTypeId: string; estimatedSec: number | null }
  | {
    type: "MATCH_START";
    roomId: string;
    roomTypeId: string;
    pot: number;
    firstTurn: string;
    p1: PublicPlayer;
    p2: PublicPlayer;
    initialState: SimState;
    inputLocked: boolean;
    isBot: boolean;
  }
  | {
    type: "AIMING_SYNC";
    roomId: string;
    actorId: string;
    isAiming: boolean;
    pullX: number;
    pullY: number;
    strikeOffset: number;
  }
  | {
    type: "SHOT_RESULT";
    roomId: string;
    actorId: string;
    frames: KeyframeSample[];
    events: HitEvent[];
    fell: number;
    winner: number;
    nextTurn: string;
    scores?: [number, number];
    duration: number;
  }
  | {
    type: "TURN_TIMER_TICK";
    roomId: string;
    secondsLeft: number;
    activeUserId: string;
  }
  | {
    type: "TURN_TIMEOUT";
    roomId: string;
    timedOutUserId: string;
    nextTurnUserId: string;
    reason: "timeout" | "pass";
  }
  | {
    type: "EMOJI_BROADCAST";
    roomId: string;
    senderId: string;
    emojiId: string;
    textBn: string;
    textEn?: string;
  }
  | {
    type: "REMATCH_OFFER";
    requesterId: string;
    requesterName: string;
    roomTypeId: string;
  }
  | { type: "REMATCH_DECLINED"; reason: string }
  | {
    type: "MATCH_OVER";
    roomId: string;
    winnerId: string;
    payout: number;
    newBalance: number;
    trophyDelta: number;
    newTrophies: number;
    cupTier: TrophyCupTier;
    profile: UserProfile;
  }
  | { type: "ROOM_CODE_CREATED"; roomCode: string }
  | {
    type: "FRIEND_CHALLENGE_RECEIVED";
    challengeId: string;
    fromUser: PublicPlayer;
    roomTypeId: string;
    stake: number;
  }
  | { type: "ERROR"; code: string; message: string };

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
