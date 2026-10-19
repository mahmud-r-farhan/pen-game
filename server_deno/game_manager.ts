// server_deno/game_manager.ts
import { getArenaById } from "./arena_config.ts";
import { atomicEscrowLock, settleMatchWinner } from "./db.ts";
import {
  createInitialMatchState,
  PEN_H,
  planBotShot,
  simulateTurn,
  SimShot,
} from "./physics_sim.ts";
import { MatchRoom, PlayerSession, PublicPlayer } from "./types.ts";

const GHOST_BOT_NAMES = [
  "Tanvir_Pabna",
  "Sabbir_Dhaka",
  "Nafi_RUET",
  "Sumon_Chittagong",
  "Ayesha_DMC",
  "Rifat_Sylhet",
  "Farhan_BUET",
  "Mahmud_Bogura",
  "Sakib_Rajshahi",
  "Tasmia_JU",
  "Hasan_Khulna",
  "Anik_Barishal",
];

const BOT_PENS = [
  "hiSchoolClassic",
  "econoStriker",
  "oceanGelPro",
  "hectorMetalTank",
  "doubleCapMod",
];

export class GameManager {
  private activeRooms = new Map<string, MatchRoom>();
  private waitingQueues = new Map<string, PlayerSession[]>(); // roomTypeId -> waiting players queue
  private roomCodes = new Map<string, { roomTypeId: string; host: PlayerSession }>();
  private activeChallenges = new Map<string, { from: PlayerSession; targetUserId: string; roomTypeId: string }>();
  private userSessions = new Map<string, PlayerSession>();
  private roomTimers = new Map<string, number | ReturnType<typeof setInterval>>(); // roomId -> setInterval handle
  private recentMatches = new Map<string, { roomTypeId: string; opponentSession: PlayerSession | "GHOST_BOT"; userSession: PlayerSession }>();
  private activeRematchRequests = new Map<string, string>(); // requesterId -> targetUserId

  getRoom(roomId: string): MatchRoom | undefined {
    return this.activeRooms.get(roomId);
  }

  registerSession(session: PlayerSession) {
    this.userSessions.set(session.userId, session);
  }

  removeSession(userId: string) {
    const session = this.userSessions.get(userId);
    if (!session) return;

    // Remove from waiting queue if any
    for (const [tier, queuedList] of this.waitingQueues.entries()) {
      const remaining = queuedList.filter((q) => q.userId !== userId);
      if (remaining.length > 0) {
        this.waitingQueues.set(tier, remaining);
      } else {
        this.waitingQueues.delete(tier);
      }
    }

    // Remove hosted room codes
    for (const [code, entry] of this.roomCodes.entries()) {
      if (entry.host.userId === userId) {
        this.roomCodes.delete(code);
      }
    }

    // If in an active match, handle forfeit
    if (session.roomId) {
      this.handlePlayerDisconnect(session);
    }

    this.userSessions.delete(userId);
  }

  getSession(userId: string): PlayerSession | undefined {
    return this.userSessions.get(userId);
  }

  /**
   * Quick Match Queue (Skill-Based 1v1 Matching with 4.5s Ghost Bot Fallback)
   */
  async joinQueue(session: PlayerSession, roomTypeId: string) {
    const arena = getArenaById(roomTypeId);
    session.roomTypeId = roomTypeId;
    session.stake = arena.entryCoins;

    const currentQueue = (this.waitingQueues.get(roomTypeId) || []).filter(
      (p) => p.userId !== session.userId && p.socket.readyState === WebSocket.OPEN,
    );

    // Skill-based matchmaking: Find opponent with closest trophy rating
    if (currentQueue.length > 0) {
      const myTrophies = session.trophyPoints || 100;
      let bestIndex = 0;
      let minDiff = Infinity;

      for (let i = 0; i < currentQueue.length; i++) {
        const diff = Math.abs((currentQueue[i].trophyPoints || 100) - myTrophies);
        if (diff < minDiff) {
          minDiff = diff;
          bestIndex = i;
        }
      }

      const [matchedOpponent] = currentQueue.splice(bestIndex, 1);
      this.waitingQueues.set(roomTypeId, currentQueue);

      await this.startMatch(matchedOpponent, session, roomTypeId);
    } else {
      const queueList = this.waitingQueues.get(roomTypeId) || [];
      queueList.push(session);
      this.waitingQueues.set(roomTypeId, queueList);

      session.socket.send(
        JSON.stringify({
          type: "QUEUE_WAITING",
          roomTypeId,
          estimatedSec: 4.5,
        }),
      );

      // 4.5s Seamless Ghost Bot fallback if no real human matches in time!
      setTimeout(async () => {
        const activeList = this.waitingQueues.get(roomTypeId) || [];
        const index = activeList.findIndex((p) => p.userId === session.userId);
        if (index !== -1) {
          activeList.splice(index, 1);
          if (activeList.length === 0) {
            this.waitingQueues.delete(roomTypeId);
          } else {
            this.waitingQueues.set(roomTypeId, activeList);
          }
          await this.startGhostBotMatch(session, roomTypeId);
        }
      }, 4500);
    }
  }

  leaveQueue(session: PlayerSession) {
    for (const [tier, queuedList] of this.waitingQueues.entries()) {
      const remaining = queuedList.filter((p) => p.userId !== session.userId);
      if (remaining.length > 0) {
        this.waitingQueues.set(tier, remaining);
      } else {
        this.waitingQueues.delete(tier);
      }
    }
  }

  /**
   * 6-Digit Private Room Codes
   */
  createRoomCode(session: PlayerSession, roomTypeId: string) {
    const arena = getArenaById(roomTypeId);
    session.roomTypeId = roomTypeId;
    session.stake = arena.entryCoins;

    const code = Math.floor(100000 + Math.random() * 900000).toString();
    this.roomCodes.set(code, { roomTypeId, host: session });

    session.socket.send(
      JSON.stringify({
        type: "ROOM_CODE_CREATED",
        roomCode: code,
      }),
    );
  }

  async joinRoomCode(session: PlayerSession, roomCode: string) {
    const entry = this.roomCodes.get(roomCode);
    if (!entry) {
      session.socket.send(
        JSON.stringify({
          type: "ERROR",
          message: "Invalid or expired 6-digit match code.",
        }),
      );
      return;
    }

    if (entry.host.userId === session.userId) {
      session.socket.send(
        JSON.stringify({
          type: "ERROR",
          message: "Cannot join your own room code.",
        }),
      );
      return;
    }

    this.roomCodes.delete(roomCode);
    await this.startMatch(entry.host, session, entry.roomTypeId);
  }

  /**
   * Direct Friend Challenge
   */
  sendFriendChallenge(session: PlayerSession, targetUserId: string, roomTypeId: string) {
    const target = this.userSessions.get(targetUserId);
    if (!target || target.socket.readyState !== WebSocket.OPEN) {
      session.socket.send(
        JSON.stringify({
          type: "ERROR",
          message: "Friend is currently offline.",
        }),
      );
      return;
    }

    const arena = getArenaById(roomTypeId);
    session.roomTypeId = roomTypeId;
    session.stake = arena.entryCoins;

    const challengeId = crypto.randomUUID().slice(0, 8);
    this.activeChallenges.set(challengeId, {
      from: session,
      targetUserId,
      roomTypeId,
    });

    target.socket.send(
      JSON.stringify({
        type: "FRIEND_CHALLENGE_RECEIVED",
        challengeId,
        fromUser: {
          id: session.userId,
          username: session.username,
          tag: session.tag,
          avatar: session.avatar,
          penModel: session.penModel,
        },
        roomTypeId,
        stake: arena.entryCoins,
      }),
    );
  }

  async respondFriendChallenge(session: PlayerSession, challengeId: string, accept: boolean) {
    const challenge = this.activeChallenges.get(challengeId);
    if (!challenge) return;
    this.activeChallenges.delete(challengeId);

    if (!accept) {
      challenge.from.socket.send(
        JSON.stringify({
          type: "ERROR",
          message: `${session.username} declined the challenge.`,
        }),
      );
      return;
    }

    await this.startMatch(challenge.from, session, challenge.roomTypeId);
  }

  /**
   * Starts a Live 1v1 Human Match
   */
  private async startMatch(p1: PlayerSession, p2: PlayerSession, roomTypeId: string) {
    const arena = getArenaById(roomTypeId);
    const roomId = crypto.randomUUID();

    const escrowOk = await atomicEscrowLock(p1.userId, p2.userId, arena.entryCoins, roomId);
    if (!escrowOk) {
      const err = JSON.stringify({ type: "ERROR", message: "One of the players has insufficient coins." });
      p1.socket.send(err);
      p2.socket.send(err);
      return;
    }

    p1.roomId = roomId;
    p2.roomId = roomId;

    const firstTurn = Math.random() > 0.5 ? p1.userId : p2.userId;

    const room: MatchRoom = {
      roomId,
      roomTypeId,
      stake: arena.entryCoins,
      pot: arena.potCoins,
      p1,
      p2,
      isGhostBotMatch: false,
      currentTurnUserId: firstTurn,
      turnNumber: 1,
      turnTimerSeconds: 30,
      consecutiveTimeouts: { [p1.userId]: 0, [p2.userId]: 0 },
      status: "PLAYING",
      createdAt: Date.now(),
      simState: createInitialMatchState(),
      scores: [0, 0],
    };
    this.activeRooms.set(roomId, room);

    const publicP1: PublicPlayer = {
      id: p1.userId,
      username: p1.username,
      tag: p1.tag,
      avatar: p1.avatar,
      penModel: p1.penModel,
    };
    const publicP2: PublicPlayer = {
      id: p2.userId,
      username: p2.username,
      tag: p2.tag,
      avatar: p2.avatar,
      penModel: p2.penModel,
    };

    const startPacket = JSON.stringify({
      type: "MATCH_START",
      roomId,
      roomTypeId,
      pot: room.pot,
      firstTurn: room.currentTurnUserId,
      p1: publicP1,
      p2: publicP2,
    });

    p1.socket.send(startPacket);
    p2.socket.send(startPacket);

    this.startTurnTimer(room);
  }

  /**
   * Starts an authoritative Ghost Bot Match
   */
  private async startGhostBotMatch(p1: PlayerSession, roomTypeId: string) {
    const arena = getArenaById(roomTypeId);
    const roomId = crypto.randomUUID();

    const escrowOk = await atomicEscrowLock(p1.userId, null, arena.entryCoins, roomId);
    if (!escrowOk) {
      p1.socket.send(JSON.stringify({ type: "ERROR", message: "Insufficient coins for this arena room." }));
      return;
    }

    p1.roomId = roomId;
    const botName = GHOST_BOT_NAMES[Math.floor(Math.random() * GHOST_BOT_NAMES.length)];
    const botPen = BOT_PENS[Math.floor(Math.random() * BOT_PENS.length)];
    const botId = `BOT_${crypto.randomUUID().slice(0, 8)}`;

    const room: MatchRoom = {
      roomId,
      roomTypeId,
      stake: arena.entryCoins,
      pot: arena.potCoins,
      p1,
      p2: null,
      isGhostBotMatch: true,
      botName,
      botPen,
      currentTurnUserId: p1.userId, // Give human the first turn
      turnNumber: 1,
      turnTimerSeconds: 30,
      consecutiveTimeouts: { [p1.userId]: 0 },
      status: "PLAYING",
      createdAt: Date.now(),
      simState: createInitialMatchState(),
      scores: [0, 0],
    };
    this.activeRooms.set(roomId, room);

    const publicP1: PublicPlayer = {
      id: p1.userId,
      username: p1.username,
      tag: p1.tag,
      avatar: p1.avatar,
      penModel: p1.penModel,
    };
    const publicBot: PublicPlayer = {
      id: botId,
      username: botName,
      tag: "#BOT",
      avatar: "avatar_pro_bangla",
      penModel: botPen,
    };

    p1.socket.send(
      JSON.stringify({
        type: "MATCH_START",
        roomId,
        roomTypeId,
        pot: room.pot,
        firstTurn: p1.userId,
        p1: publicP1,
        p2: publicBot,
      }),
    );

    this.startTurnTimer(room);
  }

  /**
   * Authoritative 30-Second Turn Countdown Timer
   */
  private startTurnTimer(room: MatchRoom) {
    this.clearTurnTimer(room.roomId);
    room.turnTimerSeconds = 30;

    const timerId = setInterval(() => {
      if (!this.activeRooms.has(room.roomId) || room.status !== "PLAYING") {
        this.clearTurnTimer(room.roomId);
        return;
      }

      room.turnTimerSeconds -= 1;

      // Broadcast timer ticks at critical thresholds (30, 25, 20, 15, 10, 5, 4, 3, 2, 1)
      if (room.turnTimerSeconds % 5 === 0 || room.turnTimerSeconds <= 5) {
        const tickPacket = JSON.stringify({
          type: "TURN_TIMER_TICK",
          secondsLeft: Math.max(0, room.turnTimerSeconds),
          activeUserId: room.currentTurnUserId,
        });
        room.p1.socket.send(tickPacket);
        room.p2?.socket.send(tickPacket);
      }

      // Turn timeout reached (30s elapsed with no flick action)
      if (room.turnTimerSeconds <= 0) {
        this.handleTurnTimeout(room);
      }
    }, 1000);

    this.roomTimers.set(room.roomId, timerId);
  }

  private clearTurnTimer(roomId: string) {
    const existing = this.roomTimers.get(roomId);
    if (existing) {
      clearInterval(existing);
      this.roomTimers.delete(roomId);
    }
  }

  /**
   * Handles 30s timeout: passes turn or forfeits match if consecutive timeouts
   */
  private handleTurnTimeout(room: MatchRoom) {
    const timedOutId = room.currentTurnUserId;
    room.consecutiveTimeouts[timedOutId] = (room.consecutiveTimeouts[timedOutId] || 0) + 1;

    // Two consecutive timeouts results in an automatic surrender/forfeit
    if (room.consecutiveTimeouts[timedOutId] >= 2) {
      const winnerId = timedOutId === room.p1.userId
        ? (room.p2?.userId ?? "GHOST_BOT")
        : room.p1.userId;
      this.handleKnockout(room.p1, winnerId);
      return;
    }

    let nextTurnId: string;
    if (room.isGhostBotMatch) {
      nextTurnId = timedOutId === room.p1.userId ? "GHOST_BOT" : room.p1.userId;
    } else if (room.p2) {
      nextTurnId = timedOutId === room.p1.userId ? room.p2.userId : room.p1.userId;
    } else {
      nextTurnId = timedOutId;
    }

    room.currentTurnUserId = nextTurnId;
    room.turnNumber += 1;

    const timeoutPacket = JSON.stringify({
      type: "TURN_TIMEOUT",
      timedOutUserId: timedOutId,
      nextTurnUserId: nextTurnId,
    });
    room.p1.socket.send(timeoutPacket);
    room.p2?.socket.send(timeoutPacket);

    this.startTurnTimer(room);

    if (room.isGhostBotMatch && nextTurnId === "GHOST_BOT") {
      this.scheduleGhostBotTurn(room);
    }
  }

  /**
   * Turn Flick Execution
   */
  handleFlick(
    session: PlayerSession,
    impulseX: number,
    impulseY: number,
    strikeOffset: number,
  ) {
    const ang = Math.atan2(impulseY, impulseX);
    const power = Math.min(1.0, Math.hypot(impulseX, impulseY) / 44.0);
    const rx = strikeOffset * PEN_H;
    this.handleShotSubmit(session, ang, power, rx, 0);
  }

  /**
   * Server-authoritative shot execution & 60Hz keyframe simulation
   */
  handleShotSubmit(
    session: PlayerSession,
    ang: number,
    power: number,
    rx = 0,
    ry = 0,
  ) {
    if (!session.roomId) return;
    const room = this.activeRooms.get(session.roomId);
    if (!room || room.status !== "PLAYING") return;
    if (room.currentTurnUserId !== session.userId) return;

    room.consecutiveTimeouts[session.userId] = 0;

    if (!Number.isFinite(ang) || !Number.isFinite(power)) return;
    const clampedPower = Math.max(0.05, Math.min(1.0, power));
    const side = session.userId === room.p1.userId ? 0 : 1;

    if (!room.simState) {
      room.simState = createInitialMatchState();
    }

    const shot: SimShot = { ang, power: clampedPower, rx, ry };
    const simResult = simulateTurn(room.simState, side, shot);
    room.simState = simResult.finalState;

    let nextTurnId: string;
    if (room.isGhostBotMatch) {
      nextTurnId = "GHOST_BOT";
    } else if (room.p2) {
      nextTurnId = session.userId === room.p1.userId ? room.p2.userId : room.p1.userId;
    } else {
      nextTurnId = session.userId;
    }

    room.currentTurnUserId = nextTurnId;
    room.turnNumber += 1;

    // 1. Broadcast authoritative SHOT_RESULT
    const shotResultPacket = JSON.stringify({
      type: "SHOT_RESULT",
      actorId: session.userId,
      frames: simResult.frames,
      events: simResult.events,
      fell: simResult.fell,
      winner: simResult.winner,
      nextTurn: nextTurnId,
      scores: room.scores,
    });
    room.p1.socket.send(shotResultPacket);
    room.p2?.socket.send(shotResultPacket);

    // 2. Also send FLICK_EXECUTE for backward-compatibility
    const impulseMag = clampedPower * 44.0;
    const impulseX = Math.cos(ang) * impulseMag;
    const impulseY = Math.sin(ang) * impulseMag;
    const strikeOffset = Math.max(-0.85, Math.min(0.85, rx / PEN_H));

    const flickPacket = JSON.stringify({
      type: "FLICK_EXECUTE",
      actorId: session.userId,
      impulseX,
      impulseY,
      strikeOffset,
      nextTurn: nextTurnId,
    });
    room.p1.socket.send(flickPacket);
    room.p2?.socket.send(flickPacket);

    this.startTurnTimer(room);

    if (simResult.winner >= 0) {
      const winnerId = simResult.winner === 0 ? room.p1.userId : (room.p2?.userId ?? "GHOST_BOT");
      this.handleKnockout(session, winnerId);
      return;
    }

    if (room.isGhostBotMatch && nextTurnId === "GHOST_BOT") {
      this.scheduleGhostBotTurn(room);
    }
  }

  /**
   * Real-time slingshot aim broadcast
   */
  handleAimingUpdate(
    session: PlayerSession,
    isAiming: boolean,
    pullX: number,
    pullY: number,
    strikeOffset: number,
  ) {
    if (!session.roomId) return;
    const room = this.activeRooms.get(session.roomId);
    if (!room || room.status !== "PLAYING") return;

    const payload = JSON.stringify({
      type: "AIMING_SYNC",
      actorId: session.userId,
      isAiming,
      pullX,
      pullY,
      strikeOffset,
    });

    if (session.userId === room.p1.userId) {
      room.p2?.socket.send(payload);
    } else {
      room.p1.socket.send(payload);
    }
  }

  /**
   * Broadcast authentic classroom emoji/voice bubbles
   */
  handleEmojiChat(session: PlayerSession, emojiId: string, textBn: string, textEn?: string) {
    if (!session.roomId) return;
    const room = this.activeRooms.get(session.roomId);
    if (!room) return;

    const chatPayload = JSON.stringify({
      type: "EMOJI_BROADCAST",
      senderId: session.userId,
      emojiId,
      textBn,
      textEn: textEn ?? textBn,
    });

    room.p1.socket.send(chatPayload);
    room.p2?.socket.send(chatPayload);
  }

  /**
   * Match Knockout Settlement (Updates Coins + Trophy Rating Points)
   */
  async handleKnockout(session: PlayerSession, winnerId: string) {
    if (!session.roomId) return;
    const room = this.activeRooms.get(session.roomId);
    if (!room || room.status === "SETTLED") return;

    this.clearTurnTimer(room.roomId);
    room.status = "SETTLED";
    const loserId = winnerId === room.p1.userId
      ? (room.p2?.userId ?? "GHOST_BOT")
      : room.p1.userId;

    const settlement = await settleMatchWinner(room.roomId, winnerId, room.pot, loserId);

    const matchOverPayload = JSON.stringify({
      type: "MATCH_OVER",
      winnerId,
      payout: settlement.payout,
      newBalance: settlement.newBalance,
      trophyDelta: settlement.trophyDelta,
      newTrophies: settlement.newTrophies,
      cupTier: settlement.cupTier,
    });

    room.p1.socket.send(matchOverPayload);
    room.p2?.socket.send(matchOverPayload);

    // Record recent match for Rematch ("Play Again") flow
    if (room.p2) {
      this.recentMatches.set(room.p1.userId, {
        roomTypeId: room.roomTypeId,
        opponentSession: room.p2,
        userSession: room.p1,
      });
      this.recentMatches.set(room.p2.userId, {
        roomTypeId: room.roomTypeId,
        opponentSession: room.p1,
        userSession: room.p2,
      });
    } else if (room.isGhostBotMatch) {
      this.recentMatches.set(room.p1.userId, {
        roomTypeId: room.roomTypeId,
        opponentSession: "GHOST_BOT",
        userSession: room.p1,
      });
    }

    this.activeRooms.delete(room.roomId);
  }

  /**
   * Handle Rematch ("Play Again") Request
   */
  async handleRematchRequest(session: PlayerSession) {
    const recent = this.recentMatches.get(session.userId);
    if (!recent) {
      session.socket.send(JSON.stringify({ type: "ERROR", message: "No recent match found for rematch." }));
      return;
    }

    if (recent.opponentSession === "GHOST_BOT") {
      // Practice or ghost bot: immediately start new match
      await this.startGhostBotMatch(session, recent.roomTypeId);
      return;
    }

    const opponent = recent.opponentSession;
    if (opponent.socket.readyState !== WebSocket.OPEN) {
      session.socket.send(JSON.stringify({ type: "REMATCH_DECLINED", reason: "Opponent has left the game." }));
      return;
    }

    // Register active rematch offer
    this.activeRematchRequests.set(session.userId, opponent.userId);

    // Send rematch offer to opponent
    opponent.socket.send(JSON.stringify({
      type: "REMATCH_OFFER",
      requesterId: session.userId,
      requesterName: session.username,
      roomTypeId: recent.roomTypeId,
    }));
  }

  /**
   * Handle Rematch Response (Accept / Decline)
   */
  async handleRematchResponse(session: PlayerSession, accept: boolean) {
    // Find requester who challenged this session
    let requesterId: string | undefined;
    for (const [reqId, targetId] of this.activeRematchRequests.entries()) {
      if (targetId === session.userId) {
        requesterId = reqId;
        break;
      }
    }

    if (!requesterId) return;
    this.activeRematchRequests.delete(requesterId);

    const requesterSession = this.userSessions.get(requesterId);
    if (!requesterSession || requesterSession.socket.readyState !== WebSocket.OPEN) {
      session.socket.send(JSON.stringify({ type: "ERROR", message: "Opponent is no longer available." }));
      return;
    }

    if (!accept) {
      requesterSession.socket.send(JSON.stringify({
        type: "REMATCH_DECLINED",
        reason: `${session.username} declined the rematch.`,
      }));
      return;
    }

    // Both accepted: Start fresh 1v1 match!
    const recent = this.recentMatches.get(session.userId);
    const roomTypeId = recent?.roomTypeId ?? "primary_school";
    await this.startMatch(requesterSession, session, roomTypeId);
  }

  /**
   * Safe Surrender / In-Game Exit (Opponent auto-wins 95% pot)
   */
  async handleSurrender(session: PlayerSession) {
    if (!session.roomId) return;
    const room = this.activeRooms.get(session.roomId);
    if (!room || room.status === "SETTLED") return;

    this.clearTurnTimer(room.roomId);
    const winnerId = session.userId === room.p1.userId
      ? (room.p2?.userId ?? "GHOST_BOT")
      : room.p1.userId;

    await this.handleKnockout(session, winnerId);
  }

  /**
   * Simulated Ghost Bot Turn with realistic delay & Monte Carlo physics shot
   */
  private scheduleGhostBotTurn(room: MatchRoom) {
    setTimeout(() => {
      if (!this.activeRooms.has(room.roomId) || room.status !== "PLAYING") return;

      if (!room.simState) {
        room.simState = createInitialMatchState();
      }

      // Intelligent Bot AI using Monte Carlo simulation
      const botShot = planBotShot(room.simState, 1);

      room.p1.socket.send(
        JSON.stringify({
          type: "AIMING_SYNC",
          actorId: "GHOST_BOT",
          isAiming: true,
          pullX: -Math.cos(botShot.ang) * (botShot.power * 4.0),
          pullY: -Math.sin(botShot.ang) * (botShot.power * 4.0),
          strikeOffset: botShot.rx / PEN_H,
        }),
      );

      setTimeout(() => {
        if (!this.activeRooms.has(room.roomId) || room.status !== "PLAYING") return;

        const simResult = simulateTurn(room.simState!, 1, botShot);
        room.simState = simResult.finalState;
        room.currentTurnUserId = room.p1.userId;
        room.turnNumber += 1;

        // Authoritative SHOT_RESULT
        const botShotPacket = JSON.stringify({
          type: "SHOT_RESULT",
          actorId: "GHOST_BOT",
          frames: simResult.frames,
          events: simResult.events,
          fell: simResult.fell,
          winner: simResult.winner,
          nextTurn: room.p1.userId,
          scores: room.scores,
        });
        room.p1.socket.send(botShotPacket);

        // Backward-compatible FLICK_EXECUTE
        const impulseMag = botShot.power * 44.0;
        const impulseX = Math.cos(botShot.ang) * impulseMag;
        const impulseY = Math.sin(botShot.ang) * impulseMag;

        room.p1.socket.send(
          JSON.stringify({
            type: "FLICK_EXECUTE",
            actorId: "GHOST_BOT",
            impulseX,
            impulseY,
            strikeOffset: botShot.rx / PEN_H,
            nextTurn: room.p1.userId,
          }),
        );

        this.startTurnTimer(room);

        if (simResult.winner >= 0) {
          const winnerId = simResult.winner === 0 ? room.p1.userId : "GHOST_BOT";
          this.handleKnockout(room.p1, winnerId);
        }
      }, 800);
    }, 1100);
  }

  handlePlayerDisconnect(session: PlayerSession) {
    if (!session.roomId) return;
    const room = this.activeRooms.get(session.roomId);
    if (!room || room.status === "SETTLED") return;

    this.clearTurnTimer(room.roomId);
    const winnerId = session.userId === room.p1.userId
      ? (room.p2?.userId ?? "GHOST_BOT")
      : room.p1.userId;

    this.handleKnockout(session, winnerId);
  }
}
