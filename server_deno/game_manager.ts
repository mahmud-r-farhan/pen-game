// server_deno/game_manager.ts
import { getArenaById } from "./arena_config.ts";
import { PEN_CATALOG } from "./catalog.ts";
import {
  atomicEscrowLock,
  getUserProfile,
  MatchSettlement,
  settleMatchWinner,
  SettlementSide,
} from "./db.ts";
import {
  ACOUL,
  AVISC,
  clamp,
  COUL,
  createInitialMatchState,
  PEN_M,
  REST,
  SimPenPhysics,
  SimShot,
  simulateTurn,
  VISC,
} from "./physics_sim.ts";
import {
  ArenaRoomConfig,
  MatchRoom,
  PlayerSession,
  PublicPlayer,
  UserProfile,
} from "./types.ts";
import { cleanPenId, finiteNumber, HttpError } from "./validation.ts";

const TURN_SECONDS = 30;
const RECONNECT_GRACE_MS = 15000;
const PRIVATE_CODE_TTL_MS = 10 * 60 * 1000;
const CHALLENGE_TTL_MS = 60 * 1000;
const SIM_UNITS_PER_METER = 50;

function loadoutPhysics(
  penId: string,
  arena: ArenaRoomConfig,
): SimPenPhysics {
  const pen = PEN_CATALOG[penId];
  const h = pen.length * SIM_UNITS_PER_METER / 2;
  const r = pen.radius * SIM_UNITS_PER_METER;
  const referenceH = 5.3 * SIM_UNITS_PER_METER / 2;
  const referenceR = 0.16 * SIM_UNITS_PER_METER;
  const areaRatio = h * r / (referenceH * referenceR);
  const m = PEN_M * pen.density / 0.85 * areaRatio;
  const i = (2 * (h + r)) ** 2 / 12 * 1.6 * m;
  const linearDamping = pen.linearDamping * arena.friction / 2.3;
  const angularDamping = pen.angularDamping * arena.angularDamping / 2.0;
  const linearRatio = linearDamping / (2.2 * 2.6 / 2.3);
  const angularRatio = angularDamping / (1.6 * 2.2 / 2.0);
  return {
    h,
    r,
    m,
    i,
    visc: VISC * linearRatio,
    coul: COUL * linearRatio,
    avisc: AVISC * angularRatio,
    acoul: ACOUL * angularRatio,
    rest: clamp(
      REST * pen.restitution / 0.65 * arena.bounce / 0.60,
      0.05,
      0.95,
    ),
  };
}

const QUICK_CHATS: Record<string, { textBn: string; textEn: string }> = {
  hit: { textBn: "কী শট ছিল রে ভাই!", textEn: "What a wicked shot!" },
  shock: { textBn: "পড়ে গেল রে টেবিল থেকে!", textEn: "It fell off the bench!" },
  quiet: { textBn: "স্যার আসছেন, আস্তে!", textEn: "Teacher is looking!" },
  nocap: { textBn: "ক্যাপ খুলে মারিস না!", textEn: "No cap flick allowed!" },
  fire: { textBn: "সাবাশ টাইগার আগুন!", textEn: "Absolute clutch fire!" },
  facepalm: {
    textBn: "ধুররর! অল্পের জন্য মিস!",
    textEn: "Ugh, missed by a hair!",
  },
  king: { textBn: "ক্লাসরুমের বস আমি!", textEn: "King of the classroom!" },
  rematch: { textBn: "আরেক ম্যাচ হয়ে যাক?", textEn: "One more rematch?" },
};

interface RecentMatch {
  roomTypeId: string;
  opponentId: string;
}

interface RematchRequest {
  requesterId: string;
  targetId: string;
  roomTypeId: string;
  expiresAt: number;
}

export class GameManager {
  private activeRooms = new Map<string, MatchRoom>();
  private waitingQueues = new Map<string, PlayerSession[]>();
  private roomCodes = new Map<
    string,
    { roomTypeId: string; host: PlayerSession; expiresAt: number }
  >();
  private activeChallenges = new Map<string, {
    from: PlayerSession;
    targetUserId: string;
    roomTypeId: string;
    expiresAt: number;
  }>();
  private userSessions = new Map<string, PlayerSession>();
  private roomTimers = new Map<string, ReturnType<typeof setInterval>>();
  private disconnectTimers = new Map<string, ReturnType<typeof setTimeout>>();
  private recentMatches = new Map<string, RecentMatch>();
  private activeRematchRequests = new Map<string, RematchRequest>();

  private send(session: PlayerSession | null, packet: unknown): void {
    if (!session || session.socket.readyState !== WebSocket.OPEN) return;
    try {
      session.socket.send(JSON.stringify(packet));
    } catch (error) {
      console.error("WebSocket send failed:", error);
    }
  }

  private broadcast(room: MatchRoom, packet: unknown): void {
    this.send(room.p1, packet);
    this.send(room.p2, packet);
  }

  private error(session: PlayerSession, code: string, message: string): void {
    this.send(session, { type: "ERROR", code, message });
  }

  private publicPlayer(
    session: PlayerSession,
    profile?: UserProfile | null,
  ): PublicPlayer {
    return {
      id: session.userId,
      username: profile?.username ?? session.username,
      tag: profile?.tag ?? session.tag,
      avatar: profile?.avatar ?? session.avatar,
      penModel: session.penModel,
      trophyPoints: profile?.trophyPoints ?? session.trophyPoints ?? 100,
      cupTier: profile?.cupTier ?? "bronze",
      flagEmoji: profile?.flagEmoji ?? "🌐",
      clubTag: profile?.clubTag ?? undefined,
    };
  }

  private matchStartPacket(
    room: MatchRoom,
    profiles?: [UserProfile | null, UserProfile | null],
  ): unknown {
    return {
      type: "MATCH_START",
      roomId: room.roomId,
      roomTypeId: room.roomTypeId,
      pot: room.pot,
      firstTurn: room.currentTurnUserId,
      p1: this.publicPlayer(room.p1, profiles?.[0]),
      p2: this.publicPlayer(room.p2!, profiles?.[1]),
      initialState: room.simState,
      inputLocked: room.inputLocked,
      isBot: false,
    };
  }

  registerSession(session: PlayerSession): void {
    const previous = this.userSessions.get(session.userId);
    this.userSessions.set(session.userId, session);
    const pendingDisconnect = this.disconnectTimers.get(session.userId);
    if (pendingDisconnect) clearTimeout(pendingDisconnect);
    this.disconnectTimers.delete(session.userId);

    if (previous && previous !== session) {
      const roomId = previous.roomId;
      const room = roomId ? this.activeRooms.get(roomId) : undefined;
      if (room) {
        session.roomId = roomId;
        session.roomTypeId = room.roomTypeId;
        session.penModel = previous.penModel;
        if (room.p1.userId === session.userId) room.p1 = session;
        if (room.p2?.userId === session.userId) room.p2 = session;
        if (room.status === "PLAYING") {
          void Promise.all([
            getUserProfile(room.p1.userId),
            getUserProfile(room.p2!.userId),
          ]).then((profiles) => {
            this.send(
              session,
              this.matchStartPacket(room, [profiles[0], profiles[1]]),
            );
            this.send(session, {
              type: "TURN_TIMER_TICK",
              roomId: room.roomId,
              secondsLeft: room.turnTimerSeconds,
              activeUserId: room.currentTurnUserId,
            });
          }).catch((error) => {
            console.error("Reconnect state synchronization failed:", error);
            this.error(
              session,
              "RECONNECT_SYNC_FAILED",
              "Could not restore the live match. Reconnect again.",
            );
          });
        }
      }
      if (previous.socket.readyState === WebSocket.OPEN) {
        previous.socket.close(4000, "Reconnected elsewhere");
      }
    }
  }

  isCurrentSession(session: PlayerSession): boolean {
    return this.userSessions.get(session.userId) === session &&
      session.socket.readyState === WebSocket.OPEN;
  }

  removeSession(session: PlayerSession): void {
    // A stale socket must never disconnect a newer connection for the same UID.
    if (this.userSessions.get(session.userId) !== session) return;
    this.leaveQueue(session);
    for (const [code, entry] of this.roomCodes) {
      if (entry.host === session) this.roomCodes.delete(code);
    }

    const room = session.roomId
      ? this.activeRooms.get(session.roomId)
      : undefined;
    if (!room || room.status !== "PLAYING") {
      this.userSessions.delete(session.userId);
      return;
    }
    if (this.disconnectTimers.has(session.userId)) return;
    const timer = setTimeout(() => {
      this.disconnectTimers.delete(session.userId);
      const current = this.userSessions.get(session.userId);
      if (current !== session || current.socket.readyState === WebSocket.OPEN) {
        return;
      }
      this.userSessions.delete(session.userId);
      const active = session.roomId
        ? this.activeRooms.get(session.roomId)
        : undefined;
      if (active && active.status === "PLAYING") {
        void this.handlePlayerDisconnect(session);
      }
    }, RECONNECT_GRACE_MS);
    this.disconnectTimers.set(session.userId, timer);
  }

  private async applyLoadout(
    session: PlayerSession,
    rawPenId: unknown,
  ): Promise<UserProfile> {
    const profile = await getUserProfile(session.userId);
    if (!profile) {
      throw new HttpError(
        401,
        "ACCOUNT_NOT_FOUND",
        "Player account was not found.",
      );
    }
    const penId = cleanPenId(rawPenId);
    if (!profile.unlockedPens.includes(penId)) {
      throw new HttpError(
        409,
        "PEN_LOCKED",
        "The selected pen is not unlocked.",
      );
    }
    session.username = profile.username;
    session.tag = profile.tag;
    session.avatar = profile.avatar;
    session.trophyPoints = profile.trophyPoints;
    session.penModel = penId;
    return profile;
  }

  private assertAvailable(session: PlayerSession): void {
    if (session.matchPending) {
      throw new HttpError(
        409,
        "MATCH_STARTING",
        "Your next match is already being created.",
      );
    }
    const room = session.roomId
      ? this.activeRooms.get(session.roomId)
      : undefined;
    if (room && room.status === "PLAYING") {
      throw new HttpError(
        409,
        "MATCH_ACTIVE",
        "Finish your active match before joining another.",
      );
    }
  }

  async joinQueue(
    session: PlayerSession,
    roomTypeId: string,
    penModel: string,
  ): Promise<void> {
    this.assertAvailable(session);
    await this.applyLoadout(session, penModel);
    this.assertAvailable(session);
    this.leaveQueue(session);
    const arena = getArenaById(roomTypeId);
    session.roomTypeId = roomTypeId;
    session.stake = arena.entryCoins;

    const queue = (this.waitingQueues.get(roomTypeId) ?? [])
      .filter((player) =>
        player !== session && player.socket.readyState === WebSocket.OPEN
      );
    if (queue.length > 0) {
      const myTrophies = session.trophyPoints ?? 100;
      let bestIndex = 0;
      for (let i = 1; i < queue.length; i++) {
        if (
          Math.abs((queue[i].trophyPoints ?? 100) - myTrophies) <
            Math.abs((queue[bestIndex].trophyPoints ?? 100) - myTrophies)
        ) bestIndex = i;
      }
      const [opponent] = queue.splice(bestIndex, 1);
      this.waitingQueues.set(roomTypeId, queue);
      await this.startMatch(opponent, session, roomTypeId);
      return;
    }

    this.waitingQueues.set(roomTypeId, [session]);
    this.send(session, {
      type: "QUEUE_WAITING",
      roomTypeId,
      estimatedSec: null,
    });
  }

  leaveQueue(session: PlayerSession): void {
    for (const [tier, queue] of this.waitingQueues) {
      const remaining = queue.filter((player) =>
        player !== session && player.userId !== session.userId
      );
      if (remaining.length) this.waitingQueues.set(tier, remaining);
      else this.waitingQueues.delete(tier);
    }
  }

  async createRoomCode(
    session: PlayerSession,
    roomTypeId: string,
    penModel: string,
  ): Promise<void> {
    this.assertAvailable(session);
    await this.applyLoadout(session, penModel);
    this.assertAvailable(session);
    const arena = getArenaById(roomTypeId);
    session.roomTypeId = roomTypeId;
    session.stake = arena.entryCoins;
    for (const [code, entry] of this.roomCodes) {
      if (
        entry.host.userId === session.userId || entry.expiresAt < Date.now()
      ) this.roomCodes.delete(code);
    }
    let code = "";
    do {
      code = (crypto.getRandomValues(new Uint32Array(1))[0] % 900000 + 100000)
        .toString();
    } while (this.roomCodes.has(code));
    this.roomCodes.set(code, {
      roomTypeId,
      host: session,
      expiresAt: Date.now() + PRIVATE_CODE_TTL_MS,
    });
    this.send(session, {
      type: "ROOM_CODE_CREATED",
      roomCode: code,
      expiresIn: PRIVATE_CODE_TTL_MS / 1000,
    });
  }

  cancelRoomCode(session: PlayerSession): void {
    for (const [code, entry] of this.roomCodes) {
      if (entry.host === session) this.roomCodes.delete(code);
    }
  }

  async joinRoomCode(
    session: PlayerSession,
    roomCode: string,
    penModel: string,
  ): Promise<void> {
    this.assertAvailable(session);
    await this.applyLoadout(session, penModel);
    this.assertAvailable(session);
    const entry = this.roomCodes.get(roomCode);
    if (
      !entry || entry.expiresAt < Date.now() ||
      entry.host.socket.readyState !== WebSocket.OPEN
    ) {
      this.roomCodes.delete(roomCode);
      throw new HttpError(
        404,
        "ROOM_NOT_FOUND",
        "That room code is invalid or expired.",
      );
    }
    if (entry.host.userId === session.userId) {
      throw new HttpError(409, "OWN_ROOM", "You cannot join your own room.");
    }
    this.roomCodes.delete(roomCode);
    await this.startMatch(entry.host, session, entry.roomTypeId);
  }

  async sendFriendChallenge(
    session: PlayerSession,
    targetUserId: string,
    roomTypeId: string,
    penModel: string,
  ): Promise<void> {
    this.assertAvailable(session);
    const profile = await this.applyLoadout(session, penModel);
    this.assertAvailable(session);
    if (!profile.friends.includes(targetUserId)) {
      throw new HttpError(
        403,
        "NOT_FRIENDS",
        "Challenges are available only between friends.",
      );
    }
    const target = this.userSessions.get(targetUserId);
    if (!target || target.socket.readyState !== WebSocket.OPEN) {
      throw new HttpError(
        409,
        "FRIEND_OFFLINE",
        "Your friend is currently offline.",
      );
    }
    this.assertAvailable(target);
    const arena = getArenaById(roomTypeId);
    session.roomTypeId = roomTypeId;
    session.stake = arena.entryCoins;
    for (const [id, challenge] of this.activeChallenges) {
      if (challenge.expiresAt < Date.now()) this.activeChallenges.delete(id);
    }
    const challengeId = crypto.randomUUID();
    this.activeChallenges.set(challengeId, {
      from: session,
      targetUserId,
      roomTypeId,
      expiresAt: Date.now() + CHALLENGE_TTL_MS,
    });
    this.send(target, {
      type: "FRIEND_CHALLENGE_RECEIVED",
      challengeId,
      fromUser: this.publicPlayer(session, profile),
      roomTypeId,
      stake: arena.entryCoins,
    });
    this.send(session, { type: "CHALLENGE_SENT", targetUserId, challengeId });
  }

  async respondFriendChallenge(
    session: PlayerSession,
    challengeId: string,
    accept: boolean,
    penModel?: string,
  ): Promise<void> {
    const challenge = this.activeChallenges.get(challengeId);
    if (
      !challenge || challenge.expiresAt < Date.now() ||
      challenge.targetUserId !== session.userId
    ) {
      this.activeChallenges.delete(challengeId);
      throw new HttpError(
        404,
        "CHALLENGE_EXPIRED",
        "That challenge is no longer available.",
      );
    }
    this.activeChallenges.delete(challengeId);
    if (!accept) {
      this.send(challenge.from, {
        type: "CHALLENGE_DECLINED",
        message: `${session.username} declined the challenge.`,
      });
      return;
    }
    this.assertAvailable(session);
    const accepterProfile = await this.applyLoadout(
      session,
      penModel ?? session.penModel,
    );
    this.assertAvailable(session);
    const challengerProfile = await getUserProfile(challenge.from.userId);
    if (
      !challengerProfile?.friends.includes(session.userId) ||
      !accepterProfile.friends.includes(challenge.from.userId)
    ) {
      throw new HttpError(
        403,
        "NOT_FRIENDS",
        "This challenge is no longer valid because the friendship changed.",
      );
    }
    if (challenge.from.socket.readyState !== WebSocket.OPEN) {
      throw new HttpError(
        409,
        "FRIEND_OFFLINE",
        "The challenger is no longer online.",
      );
    }
    await this.startMatch(challenge.from, session, challenge.roomTypeId);
  }

  private async startMatch(
    p1: PlayerSession,
    p2: PlayerSession,
    roomTypeId: string,
  ): Promise<void> {
    if (p1.userId === p2.userId) {
      throw new HttpError(
        409,
        "INVALID_MATCH",
        "A player cannot challenge themselves.",
      );
    }
    const arena = getArenaById(roomTypeId);
    const roomId = crypto.randomUUID();
    this.assertAvailable(p1);
    this.assertAvailable(p2);
    if (!this.isCurrentSession(p1) || !this.isCurrentSession(p2)) {
      throw new HttpError(
        409,
        "OPPONENT_OFFLINE",
        "Both players must have an active live connection.",
      );
    }

    // Reservation is synchronous and therefore closes the cross-client race
    // before any KV read or escrow transaction can yield to another action.
    p1.matchPending = true;
    p2.matchPending = true;
    try {
      const profiles = await Promise.all([
        getUserProfile(p1.userId),
        getUserProfile(p2.userId),
      ]);
      if (!profiles[0] || !profiles[1]) {
        throw new HttpError(
          401,
          "ACCOUNT_NOT_FOUND",
          "A player account is no longer available.",
        );
      }
      if (
        !profiles[0].unlockedPens.includes(p1.penModel) ||
        !profiles[1].unlockedPens.includes(p2.penModel)
      ) {
        throw new HttpError(
          409,
          "PEN_LOCKED",
          "A selected pen is no longer available.",
        );
      }
      const initialState = createInitialMatchState(
        loadoutPhysics(p1.penModel, arena),
        loadoutPhysics(p2.penModel, arena),
      );
      if (
        !await atomicEscrowLock(p1.userId, p2.userId, arena.entryCoins, roomId)
      ) {
        this.error(
          p1,
          "INSUFFICIENT_COINS",
          "A player does not have enough coins for this arena.",
        );
        this.error(
          p2,
          "INSUFFICIENT_COINS",
          "A player does not have enough coins for this arena.",
        );
        return;
      }

      this.leaveQueue(p1);
      this.leaveQueue(p2);
      for (const [code, entry] of this.roomCodes) {
        if (
          entry.host.userId === p1.userId || entry.host.userId === p2.userId
        ) {
          this.roomCodes.delete(code);
        }
      }
      for (const [id, challenge] of this.activeChallenges) {
        if (
          challenge.from.userId === p1.userId ||
          challenge.from.userId === p2.userId ||
          challenge.targetUserId === p1.userId ||
          challenge.targetUserId === p2.userId
        ) this.activeChallenges.delete(id);
      }

      p1.roomId = roomId;
      p2.roomId = roomId;
      p1.roomTypeId = roomTypeId;
      p2.roomTypeId = roomTypeId;
      const firstTurn = crypto.getRandomValues(new Uint32Array(1))[0] % 2 === 0
        ? p1.userId
        : p2.userId;
      const room: MatchRoom = {
        roomId,
        roomTypeId,
        stake: arena.entryCoins,
        pot: arena.potCoins,
        p1,
        p2,
        currentTurnUserId: firstTurn,
        turnNumber: 1,
        turnTimerSeconds: TURN_SECONDS,
        consecutiveTimeouts: { [p1.userId]: 0, [p2.userId]: 0 },
        status: "PLAYING",
        inputLocked: false,
        createdAt: Date.now(),
        simState: initialState,
        scores: [0, 0],
      };
      this.activeRooms.set(roomId, room);
      this.broadcast(
        room,
        this.matchStartPacket(room, [profiles[0], profiles[1]]),
      );
      this.startTurnTimer(room);
    } finally {
      p1.matchPending = false;
      p2.matchPending = false;
    }
  }

  private startTurnTimer(room: MatchRoom): void {
    this.clearTurnTimer(room.roomId);
    if (room.status !== "PLAYING" || room.inputLocked) return;
    room.turnTimerSeconds = TURN_SECONDS;
    this.broadcast(room, {
      type: "TURN_TIMER_TICK",
      roomId: room.roomId,
      secondsLeft: TURN_SECONDS,
      activeUserId: room.currentTurnUserId,
    });
    const timer = setInterval(() => {
      if (
        this.activeRooms.get(room.roomId) !== room ||
        room.status !== "PLAYING" || room.inputLocked
      ) {
        this.clearTurnTimer(room.roomId);
        return;
      }
      room.turnTimerSeconds--;
      // Tick every second so both clients stay aligned with the authoritative
      // clock even after packet loss or a background-tab timer drift.
      this.broadcast(room, {
        type: "TURN_TIMER_TICK",
        roomId: room.roomId,
        secondsLeft: Math.max(0, room.turnTimerSeconds),
        activeUserId: room.currentTurnUserId,
      });
      if (room.turnTimerSeconds <= 0) this.handleTurnTimeout(room);
    }, 1000);
    this.roomTimers.set(room.roomId, timer);
  }

  private clearTurnTimer(roomId: string): void {
    const timer = this.roomTimers.get(roomId);
    if (timer) clearInterval(timer);
    this.roomTimers.delete(roomId);
  }

  private handleTurnTimeout(room: MatchRoom): void {
    const timedOutId = room.currentTurnUserId;
    room.consecutiveTimeouts[timedOutId] =
      (room.consecutiveTimeouts[timedOutId] ?? 0) + 1;
    if (room.consecutiveTimeouts[timedOutId] >= 2) {
      const winnerId = timedOutId === room.p1.userId
        ? room.p2!.userId
        : room.p1.userId;
      void this.settleRoom(room, winnerId);
      return;
    }
    this.passTurn(room, "timeout");
  }

  handlePassTurn(session: PlayerSession): void {
    const room = this.requireRoom(session);
    if (room.inputLocked || room.currentTurnUserId !== session.userId) {
      throw new HttpError(409, "NOT_YOUR_TURN", "You cannot pass right now.");
    }
    room.consecutiveTimeouts[session.userId] = 0;
    this.passTurn(room, "pass");
  }

  private passTurn(room: MatchRoom, reason: "timeout" | "pass"): void {
    if (room.status !== "PLAYING" || room.inputLocked) return;
    const previous = room.currentTurnUserId;
    room.currentTurnUserId = previous === room.p1.userId
      ? room.p2!.userId
      : room.p1.userId;
    room.turnNumber++;
    this.broadcast(room, {
      type: "TURN_TIMEOUT",
      roomId: room.roomId,
      timedOutUserId: previous,
      nextTurnUserId: room.currentTurnUserId,
      reason,
    });
    this.startTurnTimer(room);
  }

  handleFlick(
    session: PlayerSession,
    impulseX: number,
    impulseY: number,
    strikeOffset: number,
  ): void {
    finiteNumber(impulseX, -44, 44);
    finiteNumber(impulseY, -44, 44);
    finiteNumber(strikeOffset, -0.85, 0.85);
    const magnitude = Math.hypot(impulseX, impulseY);
    if (magnitude < 0.5 || magnitude > 44.01) {
      throw new HttpError(
        400,
        "INVALID_SHOT",
        "Shot power is outside the allowed range.",
      );
    }
    // Each client sees its own pen on the left. Player two's local world is
    // rotated 180°, so normalize its drag vector into the authoritative frame.
    const room = this.requireRoom(session);
    const side = session.userId === room.p1.userId ? 0 : 1;
    const direction = side === 0 ? 1 : -1;
    this.handleShotSubmit(
      session,
      Math.atan2(impulseY * direction, impulseX * direction),
      Math.min(1, magnitude / 44),
      strikeOffset * room.simState!.pens[side].h,
      0,
    );
  }

  handleShotSubmit(
    session: PlayerSession,
    ang: number,
    power: number,
    rx = 0,
    ry = 0,
  ): void {
    const room = this.requireRoom(session);
    if (room.inputLocked || room.currentTurnUserId !== session.userId) {
      throw new HttpError(
        409,
        "NOT_YOUR_TURN",
        "Wait for your turn and the current shot to finish.",
      );
    }
    finiteNumber(ang, -Math.PI * 4, Math.PI * 4);
    finiteNumber(power, 0.05, 1);
    if (!room.simState || room.simState.ended) {
      throw new HttpError(409, "MATCH_ENDED", "This match has ended.");
    }
    const side = session.userId === room.p1.userId ? 0 : 1;
    const activePen = room.simState.pens[side];
    finiteNumber(rx, -activePen.h * 0.85, activePen.h * 0.85);
    finiteNumber(ry, -activePen.r, activePen.r);

    room.consecutiveTimeouts[session.userId] = 0;
    room.inputLocked = true;
    this.clearTurnTimer(room.roomId);
    const shot: SimShot = { ang, power, rx, ry };
    const result = simulateTurn(room.simState, side, shot);
    room.simState = result.finalState;
    const nextTurn = session.userId === room.p1.userId
      ? room.p2!.userId
      : room.p1.userId;
    room.currentTurnUserId = nextTurn;
    room.turnNumber++;

    // A double knockout is a loss for the striker, keeping every match decisive.
    const winnerSide = result.winner >= 0
      ? result.winner
      : result.fell === 2
      ? 1 - side
      : -1;
    this.broadcast(room, {
      type: "SHOT_RESULT",
      roomId: room.roomId,
      actorId: session.userId,
      frames: result.frames,
      events: result.events,
      fell: result.fell,
      winner: winnerSide,
      nextTurn,
      scores: room.scores,
      duration: result.duration,
    });

    setTimeout(() => {
      if (
        this.activeRooms.get(room.roomId) !== room || room.status !== "PLAYING"
      ) return;
      if (winnerSide >= 0) {
        const winnerId = winnerSide === 0 ? room.p1.userId : room.p2!.userId;
        void this.settleRoom(room, winnerId);
      } else {
        room.inputLocked = false;
        this.startTurnTimer(room);
      }
    }, Math.max(200, Math.ceil(result.duration * 1000) + 120));
  }

  handleAimingUpdate(
    session: PlayerSession,
    isAiming: boolean,
    pullX: number,
    pullY: number,
    strikeOffset: number,
  ): void {
    const room = this.requireRoom(session);
    if (room.inputLocked || room.currentTurnUserId !== session.userId) return;
    finiteNumber(pullX, -30, 30);
    finiteNumber(pullY, -30, 30);
    finiteNumber(strikeOffset, -0.85, 0.85);
    const packet = {
      type: "AIMING_SYNC",
      roomId: room.roomId,
      actorId: session.userId,
      isAiming,
      pullX,
      pullY,
      strikeOffset,
    };
    this.send(session.userId === room.p1.userId ? room.p2 : room.p1, packet);
  }

  handleEmojiChat(
    session: PlayerSession,
    emojiId: string,
    _textBn: string,
    _textEn?: string,
  ): void {
    const room = this.requireRoom(session);
    const chat = QUICK_CHATS[emojiId];
    if (!chat) {
      throw new HttpError(
        400,
        "INVALID_QUICK_CHAT",
        "Choose a supported quick chat.",
      );
    }
    this.broadcast(room, {
      type: "EMOJI_BROADCAST",
      roomId: room.roomId,
      senderId: session.userId,
      emojiId,
      ...chat,
    });
  }

  private requireRoom(session: PlayerSession): MatchRoom {
    const room = session.roomId
      ? this.activeRooms.get(session.roomId)
      : undefined;
    if (!room || room.status !== "PLAYING") {
      throw new HttpError(
        409,
        "MATCH_NOT_ACTIVE",
        "No active match was found.",
      );
    }
    if (
      room.p1.userId !== session.userId && room.p2?.userId !== session.userId
    ) {
      throw new HttpError(
        403,
        "NOT_IN_MATCH",
        "You are not a player in this match.",
      );
    }
    return room;
  }

  private matchOverPacket(
    roomId: string,
    winnerId: string,
    ownId: string,
    side: SettlementSide | null,
    profile: UserProfile,
  ): unknown {
    const won = winnerId === ownId;
    return {
      type: "MATCH_OVER",
      roomId,
      winnerId,
      payout: won ? side?.payout ?? 0 : 0,
      newBalance: profile.coins,
      trophyDelta: side?.trophyDelta ?? 0,
      newTrophies: profile.trophyPoints,
      cupTier: profile.cupTier,
      profile,
    };
  }

  private async persistSettlement(
    room: MatchRoom,
    winnerId: string,
    loserId: string,
    result?: MatchSettlement,
    retryAttempt = 0,
  ): Promise<void> {
    try {
      // A committed result is retained across profile-read retries. If the KV
      // transaction itself failed, settleMatchWinner is safe to call again.
      result ??= await settleMatchWinner(
        room.roomId,
        winnerId,
        room.pot,
        loserId,
      );
      const p1Profile = await getUserProfile(room.p1.userId);
      const p2Profile = await getUserProfile(room.p2!.userId);
      if (!p1Profile || !p2Profile) {
        throw new Error(
          "A match participant profile is temporarily unavailable.",
        );
      }
      const p1Side = winnerId === room.p1.userId ? result.winner : result.loser;
      const p2Side = winnerId === room.p2!.userId
        ? result.winner
        : result.loser;
      this.send(
        room.p1,
        this.matchOverPacket(
          room.roomId,
          winnerId,
          room.p1.userId,
          p1Side,
          p1Profile,
        ),
      );
      this.send(
        room.p2,
        this.matchOverPacket(
          room.roomId,
          winnerId,
          room.p2!.userId,
          p2Side,
          p2Profile,
        ),
      );
    } catch (error) {
      console.error("Match settlement failed; retry scheduled:", error);
      if (retryAttempt === 0) {
        this.broadcast(room, {
          type: "ERROR",
          code: "SETTLEMENT_PENDING",
          message:
            "Settlement is temporarily unavailable and will retry automatically.",
        });
      }
      const delayMs = Math.min(30000, 1000 * 2 ** Math.min(retryAttempt, 5));
      setTimeout(() => {
        if (
          this.activeRooms.get(room.roomId) === room &&
          room.status === "SETTLED"
        ) {
          void this.persistSettlement(
            room,
            winnerId,
            loserId,
            result,
            retryAttempt + 1,
          );
        }
      }, delayMs);
      return;
    }

    this.recentMatches.set(room.p1.userId, {
      roomTypeId: room.roomTypeId,
      opponentId: room.p2!.userId,
    });
    this.recentMatches.set(room.p2!.userId, {
      roomTypeId: room.roomTypeId,
      opponentId: room.p1.userId,
    });
    room.p1.roomId = undefined;
    room.p2!.roomId = undefined;
    this.activeRooms.delete(room.roomId);
  }

  private async settleRoom(room: MatchRoom, winnerId: string): Promise<void> {
    if (room.status === "SETTLED") return;
    room.status = "SETTLED";
    room.inputLocked = true;
    this.clearTurnTimer(room.roomId);
    const loserId = winnerId === room.p1.userId
      ? room.p2!.userId
      : room.p1.userId;
    await this.persistSettlement(room, winnerId, loserId);
  }

  async handleSurrender(session: PlayerSession): Promise<void> {
    const room = this.requireRoom(session);
    const winnerId = session.userId === room.p1.userId
      ? room.p2!.userId
      : room.p1.userId;
    await this.settleRoom(room, winnerId);
  }

  handleRematchRequest(session: PlayerSession): void {
    this.assertAvailable(session);
    const recent = this.recentMatches.get(session.userId);
    if (!recent) {
      throw new HttpError(
        404,
        "NO_RECENT_MATCH",
        "No recent opponent is available for a rematch.",
      );
    }
    const opponent = this.userSessions.get(recent.opponentId);
    if (!opponent || opponent.socket.readyState !== WebSocket.OPEN) {
      this.send(session, {
        type: "REMATCH_DECLINED",
        reason: "Your opponent has left the game.",
      });
      return;
    }
    this.assertAvailable(opponent);
    for (const [key, request] of this.activeRematchRequests) {
      if (request.expiresAt < Date.now()) {
        this.activeRematchRequests.delete(key);
      }
    }
    const key = `${session.userId}:${opponent.userId}`;
    this.activeRematchRequests.set(key, {
      requesterId: session.userId,
      targetId: opponent.userId,
      roomTypeId: recent.roomTypeId,
      expiresAt: Date.now() + CHALLENGE_TTL_MS,
    });
    this.send(opponent, {
      type: "REMATCH_OFFER",
      requesterId: session.userId,
      requesterName: session.username,
      roomTypeId: recent.roomTypeId,
    });
  }

  async handleRematchResponse(
    session: PlayerSession,
    accept: boolean,
  ): Promise<void> {
    const entry = [...this.activeRematchRequests.values()].find((request) =>
      request.targetId === session.userId && request.expiresAt >= Date.now()
    );
    if (!entry) {
      throw new HttpError(
        404,
        "REMATCH_EXPIRED",
        "That rematch offer expired.",
      );
    }
    this.activeRematchRequests.delete(`${entry.requesterId}:${entry.targetId}`);
    const requester = this.userSessions.get(entry.requesterId);
    if (!requester || requester.socket.readyState !== WebSocket.OPEN) {
      throw new HttpError(
        409,
        "OPPONENT_OFFLINE",
        "Your opponent is no longer online.",
      );
    }
    if (!accept) {
      this.send(requester, {
        type: "REMATCH_DECLINED",
        reason: `${session.username} declined the rematch.`,
      });
      return;
    }
    this.assertAvailable(session);
    this.assertAvailable(requester);
    const p1Profile = await this.applyLoadout(requester, requester.penModel);
    await this.applyLoadout(session, session.penModel);
    requester.trophyPoints = p1Profile.trophyPoints;
    await this.startMatch(requester, session, entry.roomTypeId);
  }

  private async handlePlayerDisconnect(session: PlayerSession): Promise<void> {
    const room = session.roomId
      ? this.activeRooms.get(session.roomId)
      : undefined;
    if (!room || room.status !== "PLAYING") return;
    const winnerId = session.userId === room.p1.userId
      ? room.p2!.userId
      : room.p1.userId;
    await this.settleRoom(room, winnerId);
  }
}
