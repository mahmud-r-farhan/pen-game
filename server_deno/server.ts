// server_deno/server.ts
/// <reference path="./deno.d.ts" />
import { ARENA_ROOMS } from "./arena_config.ts";
import {
  addFriendByTagOrId,
  createClub,
  ensureUser,
  getClubsList,
  getFriendsList,
  getLeaderboardData,
  getUserProfile,
  joinClub,
  linkFacebookFriends,
  mergeGuestIntoGoogleAccount,
  removeFriend,
  updateUserProfile,
} from "./db.ts";
import { GameManager } from "./game_manager.ts";
import { BangladeshiDivision, PlayerSession, WsClientAction } from "./types.ts";

const gameManager = new GameManager();
const PORT = Number(Deno.env.get("PORT") ?? 8080);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

Deno.serve({ port: PORT }, async (req: Request) => {
  const url = new URL(req.url);

  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  // 1. WebSocket Handler: /ws
  if (url.pathname === "/ws") {
    if (req.headers.get("upgrade") !== "websocket") {
      return new Response("Expected WebSocket Upgrade header", { status: 400 });
    }

    const { socket, response } = Deno.upgradeWebSocket(req);

    const userId = url.searchParams.get("uid") ?? crypto.randomUUID();
    const isGuest = url.searchParams.get("isGuest") === "true";
    const username = url.searchParams.get("name") ?? (isGuest ? "Guest Player" : "Kolom Warrior");
    const avatar = url.searchParams.get("avatar") ?? "avatar_student_boy";
    const penModel = url.searchParams.get("pen") ?? "hiSchoolClassic";
    const division = (url.searchParams.get("division") as BangladeshiDivision) ?? "Dhaka";
    const region = url.searchParams.get("region") ?? "BD";
    const flagEmoji = url.searchParams.get("flag") ?? "🇧🇩";

    const session: PlayerSession = {
      userId,
      username,
      tag: "#KLM-INIT",
      avatar,
      stake: 50,
      roomTypeId: "primary_school",
      penModel,
      socket,
    };

    socket.onopen = async () => {
      const profile = await ensureUser(userId, isGuest, username, avatar, division, region, flagEmoji);
      session.tag = profile.tag;
      session.username = profile.username;
      session.avatar = profile.avatar;
      session.penModel = profile.equippedPen;
      session.trophyPoints = profile.trophyPoints;

      gameManager.registerSession(session);

      socket.send(JSON.stringify({ type: "AUTH_SUCCESS", profile }));
      socket.send(JSON.stringify({ type: "WALLET_SYNC", coins: profile.coins, trophyPoints: profile.trophyPoints }));
    };

    socket.onmessage = async (event: MessageEvent) => {
      try {
        const action = JSON.parse(event.data) as WsClientAction;

        switch (action.type) {
          case "AUTH": {
            const profile = await ensureUser(
              action.userId,
              false,
              action.username,
              action.avatar,
              action.division,
              action.region,
              action.flagEmoji,
            );
            session.userId = profile.id;
            session.tag = profile.tag;
            session.username = profile.username;
            session.avatar = profile.avatar;
            session.penModel = profile.equippedPen;
            session.trophyPoints = profile.trophyPoints;
            socket.send(JSON.stringify({ type: "AUTH_SUCCESS", profile }));
            break;
          }

          case "QUEUE_JOIN":
            session.penModel = action.penModel;
            await gameManager.joinQueue(session, action.roomTypeId);
            break;

          case "QUEUE_LEAVE":
            gameManager.leaveQueue(session);
            break;

          case "ROOM_CODE_CREATE":
            session.penModel = action.penModel;
            gameManager.createRoomCode(session, action.roomTypeId);
            break;

          case "ROOM_CODE_JOIN":
            session.penModel = action.penModel;
            await gameManager.joinRoomCode(session, action.roomCode);
            break;

          case "FRIEND_CHALLENGE_SEND":
            session.penModel = action.penModel;
            gameManager.sendFriendChallenge(session, action.targetUserId, action.roomTypeId);
            break;

          case "FRIEND_CHALLENGE_RESPOND":
            if (action.penModel) session.penModel = action.penModel;
            await gameManager.respondFriendChallenge(session, action.challengeId, action.accept);
            break;

          case "FLICK_SUBMIT":
            gameManager.handleFlick(session, action.impulseX, action.impulseY, action.strikeOffset);
            break;

          case "SHOT_SUBMIT":
            gameManager.handleShotSubmit(session, action.ang, action.power, action.rx ?? 0, action.ry ?? 0);
            break;

          case "AIMING_UPDATE":
            gameManager.handleAimingUpdate(
              session,
              action.isAiming,
              action.pullX,
              action.pullY,
              action.strikeOffset,
            );
            break;

          case "EMOJI_CHAT":
            gameManager.handleEmojiChat(session, action.emojiId, action.textBn, action.textEn);
            break;

          case "MATCH_KNOCKOUT":
            await gameManager.handleKnockout(session, action.winnerId);
            break;

          case "SURRENDER":
            await gameManager.handleSurrender(session);
            break;

          case "REMATCH_REQUEST":
            await gameManager.handleRematchRequest(session);
            break;

          case "REMATCH_RESPOND":
            await gameManager.handleRematchResponse(session, !!action.accept);
            break;
        }
      } catch (err) {
        console.error("Socket message error:", err);
      }
    };

    socket.onclose = () => {
      gameManager.removeSession(session.userId);
    };

    socket.onerror = (e: Event | ErrorEvent) => {
      console.error("Socket error:", e);
      gameManager.removeSession(session.userId);
    };

    return response;
  }

  // 2. REST Endpoints
  const headers = { ...corsHeaders, "Content-Type": "application/json" };

  if (url.pathname === "/health") {
    return new Response(
      JSON.stringify({
        status: "ONLINE",
        game: "Kolom Fight (কলম খেলা)",
        version: "0.0.1",
        timestamp: Date.now(),
      }),
      { headers },
    );
  }

  if (url.pathname === "/arenas") {
    return new Response(JSON.stringify(Object.values(ARENA_ROOMS)), { headers });
  }

  if (url.pathname === "/api/auth/ensure" && req.method === "POST") {
    const body = await req.json();
    const profile = await ensureUser(
      body.userId,
      body.isGuest ?? true,
      body.username,
      body.avatar,
      body.division,
      body.region,
      body.flagEmoji,
    );
    return new Response(JSON.stringify(profile), { headers });
  }

  // Account Link & Guest Merge Endpoint (Google + Facebook)
  if (url.pathname === "/api/auth/merge" && req.method === "POST") {
    const body = await req.json();
    const { guestId, googleUid, googleName, googleEmail, googleAvatar, provider } = body;
    if (!guestId || !googleUid) {
      return new Response(JSON.stringify({ error: "Missing guestId or uid" }), {
        status: 400,
        headers,
      });
    }

    const mergedProfile = await mergeGuestIntoGoogleAccount(
      guestId,
      googleUid,
      googleName ?? "Authenticated Warrior",
      googleEmail ?? "",
      googleAvatar ?? "",
      provider ?? "google",
    );

    return new Response(JSON.stringify({ success: true, profile: mergedProfile }), { headers });
  }

  if (url.pathname === "/api/leaderboard") {
    const rawFilter = url.searchParams.get("filter");
    const filter = (rawFilter === "division" || rawFilter === "friends" || rawFilter === "trophies") ? rawFilter : "global";
    const division = (url.searchParams.get("division") as BangladeshiDivision) || undefined;
    const userId = url.searchParams.get("userId") ?? undefined;
    const data = await getLeaderboardData(filter, division, userId);
    return new Response(JSON.stringify(data), { headers });
  }

  if (url.pathname === "/api/clubs") {
    const clubs = await getClubsList();
    return new Response(JSON.stringify(clubs), { headers });
  }

  if (url.pathname === "/api/clubs/create" && req.method === "POST") {
    const body = await req.json();
    const club = await createClub(
      body.leaderId,
      body.name,
      body.tag,
      body.description,
      body.badgeIcon ?? "badge_dragon",
      body.region ?? "BD",
      body.flagEmoji ?? "🇧🇩",
    );
    return new Response(JSON.stringify({ success: true, club }), { headers });
  }

  if (url.pathname === "/api/clubs/join" && req.method === "POST") {
    const body = await req.json();
    const club = await joinClub(body.userId, body.clubId);
    if (!club) {
      return new Response(JSON.stringify({ error: "Club not found" }), { status: 404, headers });
    }
    return new Response(JSON.stringify({ success: true, club }), { headers });
  }

  if (url.pathname === "/api/friends") {
    const userId = url.searchParams.get("userId");
    if (!userId) return new Response(JSON.stringify([]), { headers });
    const friends = await getFriendsList(userId);
    return new Response(JSON.stringify(friends), { headers });
  }

  if (url.pathname === "/api/friends/add" && req.method === "POST") {
    const body = await req.json();
    const added = await addFriendByTagOrId(body.userId, body.query);
    if (!added) {
      return new Response(JSON.stringify({ error: "User or tag not found" }), {
        status: 404,
        headers,
      });
    }
    return new Response(JSON.stringify({ success: true, friend: added }), { headers });
  }

  if (url.pathname === "/api/friends/remove" && req.method === "POST") {
    const body = await req.json();
    const ok = await removeFriend(body.userId, body.friendId);
    return new Response(JSON.stringify({ success: ok }), { headers });
  }

  if (url.pathname === "/api/friends/facebook-sync" && req.method === "POST") {
    const body = await req.json();
    const matched = await linkFacebookFriends(
      body.userId,
      body.facebookId,
      body.facebookFriendIds ?? [],
    );
    return new Response(JSON.stringify({ success: true, matchedFriends: matched }), { headers });
  }

  if (url.pathname === "/api/user/profile") {
    const userId = url.searchParams.get("userId");
    if (!userId) return new Response(JSON.stringify({ error: "Missing userId" }), { status: 400, headers });
    const profile = await getUserProfile(userId);
    return new Response(JSON.stringify(profile ?? { error: "Not found" }), { headers });
  }

  if (url.pathname === "/api/user/update-profile" && req.method === "POST") {
    const body = await req.json();
    const { userId, ...updates } = body;
    if (!userId) {
      return new Response(JSON.stringify({ error: "Missing userId" }), { status: 400, headers });
    }
    const updated = await updateUserProfile(userId, updates);
    if (!updated) {
      return new Response(JSON.stringify({ error: "User not found" }), { status: 404, headers });
    }
    return new Response(JSON.stringify({ success: true, profile: updated }), { headers });
  }

  // 3. Static Web Client File Serving (Flutter Web App)
  try {
    const webDir = "../client_flutter/build/web";
    const filePath = url.pathname === "/" ? `${webDir}/index.html` : `${webDir}${url.pathname}`;
    const file = await Deno.readFile(filePath);

    let contentType = "application/octet-stream";
    if (filePath.endsWith(".html")) contentType = "text/html; charset=utf-8";
    else if (filePath.endsWith(".js")) contentType = "application/javascript; charset=utf-8";
    else if (filePath.endsWith(".json")) contentType = "application/json; charset=utf-8";
    else if (filePath.endsWith(".css")) contentType = "text/css; charset=utf-8";
    else if (filePath.endsWith(".wasm")) contentType = "application/wasm";
    else if (filePath.endsWith(".png")) contentType = "image/png";
    else if (filePath.endsWith(".webp")) contentType = "image/webp";
    else if (filePath.endsWith(".svg")) contentType = "image/svg+xml";
    else if (filePath.endsWith(".wav")) contentType = "audio/wav";

    return new Response(file, {
      headers: {
        ...corsHeaders,
        "Content-Type": contentType,
      },
    });
  } catch (_) {
    try {
      const fallback = await Deno.readFile("../client_flutter/build/web/index.html");
      return new Response(fallback, {
        headers: { ...corsHeaders, "Content-Type": "text/html; charset=utf-8" },
      });
    } catch (_err) {
      // index.html does not exist on disk
    }
  }

  return new Response("Not Found", { status: 404, headers });
});

console.log(`🚀 Kolom Fight Deno Server running on http://localhost:${PORT}`);
