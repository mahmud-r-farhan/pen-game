// server_deno/server.ts
/// <reference path="./deno.d.ts" />
import { ARENA_ROOMS } from "./arena_config.ts";
import {
  AuthError,
  bearerToken,
  consumeWebSocketTicket,
  createSession,
  createWebSocketTicket,
  getSession,
  revokeSession,
  verifyFirebaseGoogleIdToken,
} from "./auth.ts";
import { PEN_CATALOG } from "./catalog.ts";
import {
  addFriendByTagOrId,
  claimDailyReward,
  createClub,
  databaseHealthCheck,
  ensureUser,
  equipPen,
  getClubsList,
  getFriendsList,
  getLeaderboardData,
  getUserProfile,
  joinClub,
  leaveClub,
  linkGoogleAccount,
  purchasePen,
  removeFriend,
  toPublicProfile,
  updateUserProfile,
} from "./db.ts";
import { GameManager } from "./game_manager.ts";
import { PlayerSession, UserProfile, WsClientAction } from "./types.ts";
import {
  asObject,
  cleanArenaId,
  cleanDivision,
  cleanFlag,
  cleanRegion,
  cleanRoomCode,
  cleanUsername,
  HttpError,
  optionalText,
} from "./validation.ts";

const gameManager = new GameManager();
const PORT = Number(Deno.env.get("PORT") ?? 8080);
const WEB_ROOT = Deno.env.get("WEB_ROOT") ??
  new URL("../client_flutter/build/web", import.meta.url);
const ALLOWED_ORIGINS = (Deno.env.get("ALLOWED_ORIGINS") ?? "*")
  .split(",").map((origin) => origin.trim()).filter(Boolean);
const MAX_JSON_BYTES = 32 * 1024;

function corsHeaders(request: Request): Record<string, string> {
  const origin = request.headers.get("origin");
  const allowedOrigin = ALLOWED_ORIGINS.includes("*")
    ? "*"
    : origin && ALLOWED_ORIGINS.includes(origin)
    ? origin
    : "null";
  return {
    "Access-Control-Allow-Origin": allowedOrigin,
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
    "Access-Control-Max-Age": "86400",
    "Vary": "Origin",
  };
}

function securityHeaders(
  request: Request,
  json = true,
): Record<string, string> {
  return {
    ...corsHeaders(request),
    ...(json ? { "Content-Type": "application/json; charset=utf-8" } : {}),
    "X-Content-Type-Options": "nosniff",
    "Referrer-Policy": "strict-origin-when-cross-origin",
    "X-Frame-Options": "DENY",
    "Permissions-Policy": "camera=(), microphone=(), geolocation=()",
  };
}

function json(request: Request, data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: securityHeaders(request),
  });
}

function errorResponse(request: Request, error: unknown): Response {
  if (error instanceof AuthError) {
    return json(request, {
      error: {
        code: error.status === 503
          ? "IDENTITY_UNAVAILABLE"
          : "INVALID_ID_TOKEN",
        message: error.message,
      },
    }, error.status);
  }
  if (error instanceof HttpError) {
    return json(request, {
      error: { code: error.code, message: error.message },
    }, error.status);
  }
  if (error instanceof SyntaxError) {
    return json(request, {
      error: { code: "INVALID_JSON", message: "Malformed JSON request." },
    }, 400);
  }
  console.error("Unhandled request error:", error);
  return json(request, {
    error: {
      code: "INTERNAL_ERROR",
      message: "The server could not complete this request.",
    },
  }, 500);
}

async function readJson(request: Request): Promise<Record<string, unknown>> {
  const length = Number(request.headers.get("content-length") ?? 0);
  if (length > MAX_JSON_BYTES) {
    throw new HttpError(413, "PAYLOAD_TOO_LARGE", "Request body is too large.");
  }
  const text = await request.text();
  if (new TextEncoder().encode(text).length > MAX_JSON_BYTES) {
    throw new HttpError(413, "PAYLOAD_TOO_LARGE", "Request body is too large.");
  }
  return asObject(JSON.parse(text));
}

async function authenticatedProfile(
  request: Request,
  optional = false,
): Promise<
  {
    profile: UserProfile;
    token: string;
  } | null
> {
  const token = bearerToken(request);
  if (!token) {
    if (optional) return null;
    throw new HttpError(401, "AUTH_REQUIRED", "Sign in to continue.");
  }
  const session = await getSession(token);
  if (!session) {
    throw new HttpError(
      401,
      "SESSION_EXPIRED",
      "Your session expired. Sign in again.",
    );
  }
  const profile = await getUserProfile(session.userId);
  if (!profile) {
    throw new HttpError(
      401,
      "ACCOUNT_NOT_FOUND",
      "This account is no longer available.",
    );
  }
  return { profile, token };
}

async function createAuthResponse(profile: UserProfile): Promise<{
  profile: UserProfile;
  sessionToken: string;
  expiresAt: number;
}> {
  const session = await createSession(profile.id);
  return { profile, sessionToken: session.token, expiresAt: session.expiresAt };
}

async function handleWebSocket(request: Request, url: URL): Promise<Response> {
  if (request.headers.get("upgrade")?.toLowerCase() !== "websocket") {
    throw new HttpError(
      400,
      "WEBSOCKET_REQUIRED",
      "Expected a WebSocket upgrade.",
    );
  }
  const ticket = url.searchParams.get("ticket") ?? "";
  const userId = await consumeWebSocketTicket(ticket);
  if (!userId) {
    throw new HttpError(
      401,
      "INVALID_WS_TICKET",
      "WebSocket authorization expired. Reconnect.",
    );
  }
  const profile = await getUserProfile(userId);
  if (!profile) {
    throw new HttpError(
      401,
      "ACCOUNT_NOT_FOUND",
      "This account is no longer available.",
    );
  }

  const { socket, response } = Deno.upgradeWebSocket(request);
  const session: PlayerSession = {
    userId: profile.id,
    username: profile.username,
    tag: profile.tag,
    avatar: profile.avatar,
    stake: 0,
    roomTypeId: "primary_school",
    penModel: profile.equippedPen,
    socket,
    trophyPoints: profile.trophyPoints,
    authenticatedAt: Date.now(),
  };
  let authenticated = false;
  const messageTimes: number[] = [];

  socket.onopen = () => {
    authenticated = true;
    socket.send(JSON.stringify({ type: "AUTH_SUCCESS", profile }));
    socket.send(JSON.stringify({
      type: "WALLET_SYNC",
      coins: profile.coins,
      trophyPoints: profile.trophyPoints,
    }));
    gameManager.registerSession(session);
  };

  socket.onmessage = async (event: MessageEvent) => {
    if (
      !authenticated || typeof event.data !== "string" ||
      event.data.length > 16384 || !gameManager.isCurrentSession(session)
    ) return;
    const now = Date.now();
    while (messageTimes.length && messageTimes[0] < now - 10000) {
      messageTimes.shift();
    }
    messageTimes.push(now);
    if (messageTimes.length > 180) {
      socket.send(
        JSON.stringify({
          type: "ERROR",
          code: "RATE_LIMITED",
          message: "Too many actions. Slow down.",
        }),
      );
      return;
    }

    try {
      const action = asObject(
        JSON.parse(event.data),
      ) as unknown as WsClientAction;
      switch (action.type) {
        case "QUEUE_JOIN":
          await gameManager.joinQueue(
            session,
            cleanArenaId(action.roomTypeId),
            action.penModel,
          );
          break;
        case "QUEUE_LEAVE":
          gameManager.leaveQueue(session);
          break;
        case "ROOM_CODE_CREATE":
          await gameManager.createRoomCode(
            session,
            cleanArenaId(action.roomTypeId),
            action.penModel,
          );
          break;
        case "ROOM_CODE_JOIN":
          await gameManager.joinRoomCode(
            session,
            cleanRoomCode(action.roomCode),
            action.penModel,
          );
          break;
        case "ROOM_CODE_CANCEL":
          gameManager.cancelRoomCode(session);
          break;
        case "FRIEND_CHALLENGE_SEND":
          await gameManager.sendFriendChallenge(
            session,
            optionalText(action.targetUserId, "", 160),
            cleanArenaId(action.roomTypeId),
            action.penModel,
          );
          break;
        case "FRIEND_CHALLENGE_RESPOND":
          await gameManager.respondFriendChallenge(
            session,
            optionalText(action.challengeId, "", 64),
            action.accept === true,
            action.penModel,
          );
          break;
        case "FLICK_SUBMIT":
          gameManager.handleFlick(
            session,
            action.impulseX,
            action.impulseY,
            action.strikeOffset,
          );
          break;
        case "SHOT_SUBMIT":
          gameManager.handleShotSubmit(
            session,
            action.ang,
            action.power,
            action.rx ?? 0,
            action.ry ?? 0,
          );
          break;
        case "PASS_TURN":
          gameManager.handlePassTurn(session);
          break;
        case "AIMING_UPDATE":
          gameManager.handleAimingUpdate(
            session,
            action.isAiming === true,
            action.pullX,
            action.pullY,
            action.strikeOffset,
          );
          break;
        case "EMOJI_CHAT":
          gameManager.handleEmojiChat(
            session,
            action.emojiId,
            action.textBn,
            action.textEn,
          );
          break;
        case "SURRENDER":
          await gameManager.handleSurrender(session);
          break;
        case "REMATCH_REQUEST":
          await gameManager.handleRematchRequest(session);
          break;
        case "REMATCH_RESPOND":
          await gameManager.handleRematchResponse(
            session,
            action.accept === true,
          );
          break;
        default:
          socket.send(
            JSON.stringify({
              type: "ERROR",
              code: "UNKNOWN_ACTION",
              message: "Unsupported game action.",
            }),
          );
      }
    } catch (error) {
      const code = error instanceof HttpError ? error.code : "ACTION_FAILED";
      const message = error instanceof Error
        ? error.message
        : "The game action failed.";
      if (!(error instanceof HttpError)) {
        console.error("Socket action error:", error);
      }
      if (socket.readyState === WebSocket.OPEN) {
        socket.send(JSON.stringify({ type: "ERROR", code, message }));
      }
    }
  };

  socket.onclose = () => gameManager.removeSession(session);
  socket.onerror = () => gameManager.removeSession(session);
  return response;
}

function contentType(path: string): string {
  if (path.endsWith(".html")) return "text/html; charset=utf-8";
  if (path.endsWith(".js")) return "application/javascript; charset=utf-8";
  if (path.endsWith(".json")) return "application/json; charset=utf-8";
  if (path.endsWith(".css")) return "text/css; charset=utf-8";
  if (path.endsWith(".wasm")) return "application/wasm";
  if (path.endsWith(".png")) return "image/png";
  if (path.endsWith(".webp")) return "image/webp";
  if (path.endsWith(".svg")) return "image/svg+xml";
  if (path.endsWith(".wav")) return "audio/wav";
  if (path.endsWith(".woff2")) return "font/woff2";
  return "application/octet-stream";
}

async function serveStatic(
  request: Request,
  pathname: string,
): Promise<Response> {
  if (request.method !== "GET" && request.method !== "HEAD") {
    throw new HttpError(405, "METHOD_NOT_ALLOWED", "Method not allowed.");
  }
  let decoded: string;
  try {
    decoded = decodeURIComponent(pathname);
  } catch {
    throw new HttpError(400, "INVALID_PATH", "Invalid path.");
  }
  if (decoded.includes("\0") || decoded.split("/").includes("..")) {
    throw new HttpError(400, "INVALID_PATH", "Invalid path.");
  }

  const root = await Deno.realPath(WEB_ROOT).catch(() => null);
  if (!root) {
    throw new HttpError(
      404,
      "WEB_BUILD_NOT_FOUND",
      "Flutter web build is not available.",
    );
  }
  const relative = decoded === "/" ? "index.html" : decoded.replace(/^\/+/, "");
  let filePath = `${root}/${relative}`;
  let resolved = await Deno.realPath(filePath).catch(() => null);
  const isWithin = (p: string | null) => {
    if (!p) return false;
    const nP = p.replaceAll("\\", "/");
    const nR = root.replaceAll("\\", "/");
    return nP === nR || nP.startsWith(`${nR}/`);
  };
  if (!isWithin(resolved)) {
    // SPA fallback applies only to extensionless application routes.
    if (relative.includes(".")) {
      throw new HttpError(404, "NOT_FOUND", "File not found.");
    }
    filePath = `${root}/index.html`;
    resolved = await Deno.realPath(filePath).catch(() => null);
  }
  if (!isWithin(resolved) || !resolved) {
    throw new HttpError(404, "NOT_FOUND", "File not found.");
  }
  const file = request.method === "HEAD"
    ? new Uint8Array()
    : await Deno.readFile(resolved);
  return new Response(file, {
    headers: {
      ...securityHeaders(request, false),
      "Content-Type": contentType(resolved),
      "Cache-Control": resolved.endsWith("index.html")
        ? "no-cache"
        : "public, max-age=3600",
    },
  });
}

Deno.serve({ port: PORT, hostname: "0.0.0.0" }, async (request: Request) => {
  const url = new URL(request.url);
  if (request.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: securityHeaders(request, false),
    });
  }

  try {
    if (url.pathname === "/ws") return await handleWebSocket(request, url);

    if (url.pathname === "/health" && request.method === "GET") {
      const database = await databaseHealthCheck();
      return json(request, {
        status: database ? "ok" : "degraded",
        database: database ? "ok" : "unavailable",
        version: "1.0.0",
        timestamp: new Date().toISOString(),
      }, database ? 200 : 503);
    }
    if (url.pathname === "/arenas" && request.method === "GET") {
      return json(request, Object.values(ARENA_ROOMS));
    }
    if (url.pathname === "/api/shop/catalog" && request.method === "GET") {
      return json(request, Object.values(PEN_CATALOG));
    }

    if (url.pathname === "/api/auth/guest" && request.method === "POST") {
      const body = await readJson(request);
      const profile = await ensureUser(
        `guest_${crypto.randomUUID()}`,
        true,
        cleanUsername(
          body.username,
          `Guest_${crypto.randomUUID().slice(0, 6)}`,
        ),
        optionalText(body.avatar, "avatar_shuvo", 96),
        cleanDivision(body.division, "Dhaka"),
        cleanRegion(body.region, "BD"),
        cleanFlag(body.flagEmoji, "🇧🇩"),
      );
      return json(request, await createAuthResponse(profile), 201);
    }
    if (url.pathname === "/api/auth/session" && request.method === "GET") {
      const auth = await authenticatedProfile(request);
      return json(request, { profile: auth!.profile });
    }
    if (url.pathname === "/api/auth/google" && request.method === "POST") {
      const body = await readJson(request);
      if (typeof body.idToken !== "string") {
        throw new HttpError(
          400,
          "ID_TOKEN_REQUIRED",
          "Firebase ID token is required.",
        );
      }
      const identity = await verifyFirebaseGoogleIdToken(body.idToken);
      const current = await authenticatedProfile(request, true);
      const guestId = current?.profile.isGuest ? current.profile.id : null;
      const profile = await linkGoogleAccount(guestId, identity);
      if (current && guestId) await revokeSession(current.token);
      return json(request, await createAuthResponse(profile));
    }
    if (url.pathname === "/api/auth/ws-ticket" && request.method === "POST") {
      const auth = await authenticatedProfile(request);
      return json(request, {
        ticket: await createWebSocketTicket(auth!.profile.id),
        expiresIn: 60,
      });
    }
    if (url.pathname === "/api/auth/logout" && request.method === "POST") {
      const auth = await authenticatedProfile(request);
      await revokeSession(auth!.token);
      return json(request, { success: true });
    }

    if (url.pathname === "/api/user/profile" && request.method === "GET") {
      const auth = await authenticatedProfile(request);
      return json(request, { profile: auth!.profile });
    }
    if (
      url.pathname === "/api/user/update-profile" && request.method === "POST"
    ) {
      const auth = await authenticatedProfile(request);
      const body = await readJson(request);
      const updated = await updateUserProfile(auth!.profile.id, {
        username: body.username === undefined
          ? undefined
          : cleanUsername(body.username),
        avatar: body.avatar === undefined
          ? undefined
          : optionalText(body.avatar, "avatar_shuvo", 512),
        region: body.region === undefined
          ? undefined
          : cleanRegion(body.region),
        flagEmoji: body.flagEmoji === undefined
          ? undefined
          : cleanFlag(body.flagEmoji),
        division: body.division === undefined
          ? undefined
          : cleanDivision(body.division),
      });
      return json(request, { success: true, profile: updated });
    }
    if (url.pathname === "/api/shop/purchase" && request.method === "POST") {
      const auth = await authenticatedProfile(request);
      const body = await readJson(request);
      return json(request, {
        success: true,
        profile: await purchasePen(auth!.profile.id, body.penId),
      });
    }
    if (url.pathname === "/api/shop/equip" && request.method === "POST") {
      const auth = await authenticatedProfile(request);
      const body = await readJson(request);
      return json(request, {
        success: true,
        profile: await equipPen(auth!.profile.id, body.penId),
      });
    }
    if (url.pathname === "/api/rewards/daily" && request.method === "POST") {
      const auth = await authenticatedProfile(request);
      return json(request, await claimDailyReward(auth!.profile.id));
    }

    if (url.pathname === "/api/leaderboard" && request.method === "GET") {
      const rawFilter = url.searchParams.get("filter");
      const filter = rawFilter === "division" || rawFilter === "friends" ||
          rawFilter === "trophies"
        ? rawFilter
        : "global";
      const auth = await authenticatedProfile(request, filter === "friends");
      const division = url.searchParams.get("division") ?? undefined;
      const data = await getLeaderboardData(
        filter,
        division ? cleanDivision(division) : undefined,
        auth?.profile.id,
      );
      return json(request, data);
    }
    if (url.pathname === "/api/clubs" && request.method === "GET") {
      return json(request, await getClubsList());
    }
    if (url.pathname === "/api/clubs/create" && request.method === "POST") {
      const auth = await authenticatedProfile(request);
      const body = await readJson(request);
      const result = await createClub(
        auth!.profile.id,
        cleanUsername(body.name),
        optionalText(body.tag, "", 12),
        optionalText(body.description, "", 240),
        optionalText(body.badgeIcon, "🛡️", 16),
        cleanRegion(body.region, "BD"),
        cleanFlag(body.flagEmoji, "🇧🇩"),
      );
      return json(request, { success: true, ...result }, 201);
    }
    if (url.pathname === "/api/clubs/join" && request.method === "POST") {
      const auth = await authenticatedProfile(request);
      const body = await readJson(request);
      const result = await joinClub(
        auth!.profile.id,
        optionalText(body.clubId, "", 64),
      );
      return json(request, { success: true, ...result });
    }
    if (url.pathname === "/api/clubs/leave" && request.method === "POST") {
      const auth = await authenticatedProfile(request);
      return json(request, {
        success: true,
        profile: await leaveClub(auth!.profile.id),
      });
    }

    if (url.pathname === "/api/friends" && request.method === "GET") {
      const auth = await authenticatedProfile(request);
      return json(request, await getFriendsList(auth!.profile.id));
    }
    if (url.pathname === "/api/friends/add" && request.method === "POST") {
      const auth = await authenticatedProfile(request);
      const body = await readJson(request);
      const added = await addFriendByTagOrId(
        auth!.profile.id,
        optionalText(body.query, "", 128),
      );
      if (!added) {
        throw new HttpError(
          404,
          "PLAYER_NOT_FOUND",
          "Player tag was not found or belongs to you.",
        );
      }
      return json(request, { success: true, friend: toPublicProfile(added) });
    }
    if (url.pathname === "/api/friends/remove" && request.method === "POST") {
      const auth = await authenticatedProfile(request);
      const body = await readJson(request);
      const ok = await removeFriend(
        auth!.profile.id,
        optionalText(body.friendId, "", 160),
      );
      if (!ok) {
        throw new HttpError(404, "PLAYER_NOT_FOUND", "Friend was not found.");
      }
      return json(request, { success: true });
    }

    if (url.pathname.startsWith("/api/")) {
      throw new HttpError(404, "ENDPOINT_NOT_FOUND", "API endpoint not found.");
    }
    return await serveStatic(request, url.pathname);
  } catch (error) {
    return errorResponse(request, error);
  }
});

console.log(`Kolom Fight server listening on 0.0.0.0:${PORT}`);
