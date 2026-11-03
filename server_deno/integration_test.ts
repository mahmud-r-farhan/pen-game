// server_deno/integration_test.ts
// deno-lint-ignore-file no-explicit-any -- Live protocol checks intentionally consume heterogeneous JSON packets.
// Run against an isolated local server: deno run -A integration_test.ts
/// <reference path="./deno.d.ts" />

const base = Deno.env.get("TEST_BASE_URL") ?? "http://127.0.0.1:8080";

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(`Integration assertion failed: ${message}`);
}

async function request(
  method: string,
  path: string,
  options: { token?: string; body?: unknown } = {},
): Promise<{ status: number; data: any }> {
  const response = await fetch(`${base}${path}`, {
    method,
    headers: {
      Accept: "application/json",
      ...(options.body !== undefined
        ? { "Content-Type": "application/json" }
        : {}),
      ...(options.token ? { Authorization: `Bearer ${options.token}` } : {}),
    },
    body: options.body === undefined ? undefined : JSON.stringify(options.body),
  });
  const data = await response.json();
  return { status: response.status, data };
}

class TestSocket {
  private socket: WebSocket;
  private inbox: any[] = [];
  private waiters = new Map<
    string,
    { resolve: (packet: any) => void; reject: (error: Error) => void }
  >();

  private constructor(socket: WebSocket) {
    this.socket = socket;
    socket.onmessage = (event) => {
      const packet = JSON.parse(event.data);
      const waiter = this.waiters.get(packet.type);
      if (waiter) {
        this.waiters.delete(packet.type);
        waiter.resolve(packet);
      } else {
        this.inbox.push(packet);
      }
    };
  }

  static async connect(token: string): Promise<TestSocket> {
    const ticketResponse = await request("POST", "/api/auth/ws-ticket", {
      token,
      body: {},
    });
    assert(
      ticketResponse.status === 200,
      `WS ticket status ${ticketResponse.status}`,
    );
    const url = new URL(base);
    url.protocol = url.protocol === "https:" ? "wss:" : "ws:";
    url.pathname = "/ws";
    url.search = `?ticket=${encodeURIComponent(ticketResponse.data.ticket)}`;
    const socket = new WebSocket(url);
    await new Promise<void>((resolve, reject) => {
      const timer = setTimeout(
        () => reject(new Error("WebSocket open timeout")),
        5000,
      );
      socket.onopen = () => {
        clearTimeout(timer);
        resolve();
      };
      socket.onerror = () => {
        clearTimeout(timer);
        reject(new Error("WebSocket connection failed"));
      };
    });
    const client = new TestSocket(socket);
    const auth = await client.waitFor("AUTH_SUCCESS");
    assert(auth.profile.id, "socket authenticated with a backend profile");
    return client;
  }

  send(packet: unknown): void {
    this.socket.send(JSON.stringify(packet));
  }

  waitFor(type: string, timeoutMs = 15000): Promise<any> {
    const existing = this.inbox.findIndex((packet) => packet.type === type);
    if (existing >= 0) {
      return Promise.resolve(this.inbox.splice(existing, 1)[0]);
    }
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.waiters.delete(type);
        reject(
          new Error(
            `Timed out waiting for ${type}; queued=${
              this.inbox.map((p) => p.type).join(",")
            }`,
          ),
        );
      }, timeoutMs);
      this.waiters.set(type, {
        resolve: (packet) => {
          clearTimeout(timer);
          resolve(packet);
        },
        reject,
      });
    });
  }

  close(): void {
    this.socket.close();
  }
}

const guestA = await request("POST", "/api/auth/guest", {
  body: {
    username: "Integration A",
    division: "Rajshahi",
    region: "BD",
    flagEmoji: "🇧🇩",
  },
});
const guestB = await request("POST", "/api/auth/guest", {
  body: {
    username: "Integration B",
    division: "Dhaka",
    region: "BD",
    flagEmoji: "🇧🇩",
  },
});
assert(
  guestA.status === 201 && guestB.status === 201,
  "guest accounts are created by the backend",
);
const tokenA = guestA.data.sessionToken as string;
const tokenB = guestB.data.sessionToken as string;
assert(
  tokenA.length >= 40 && tokenB.length >= 40,
  "cryptographic session tokens are issued",
);
assert(
  guestA.data.profile.coins === 75 && guestB.data.profile.coins === 75,
  "server assigns starter balances",
);

const unauthenticated = await request("GET", "/api/friends");
assert(
  unauthenticated.status === 401,
  "private endpoints reject anonymous calls",
);
const restored = await request("GET", "/api/auth/session", { token: tokenA });
assert(
  restored.status === 200 &&
    restored.data.profile.id === guestA.data.profile.id,
  "saved session restores",
);
const invalidGoogle = await request("POST", "/api/auth/google", {
  body: { idToken: "invalid" },
});
assert(
  invalidGoogle.status === 401 &&
    invalidGoogle.data.error.code === "INVALID_ID_TOKEN",
  "invalid provider tokens return a typed authentication error",
);

const dailyA = await request("POST", "/api/rewards/daily", {
  token: tokenA,
  body: {},
});
const dailyARepeat = await request("POST", "/api/rewards/daily", {
  token: tokenA,
  body: {},
});
const dailyB = await request("POST", "/api/rewards/daily", {
  token: tokenB,
  body: {},
});
assert(
  dailyA.data.reward === 200 && dailyA.data.profile.coins === 275,
  "daily reward is backend-owned",
);
assert(
  dailyARepeat.data.reward === 0 && dailyARepeat.data.profile.coins === 275,
  "daily reward cannot be claimed twice",
);
assert(
  dailyB.data.reward === 200,
  "second player has an independent reward clock",
);

const lockedPurchase = await request("POST", "/api/shop/purchase", {
  token: tokenA,
  body: { penId: "oceanGelPro" },
});
assert(
  lockedPurchase.status === 409 &&
    lockedPurchase.data.error.code === "LEVEL_REQUIRED",
  "server enforces pen level",
);
const forgedUpdate = await request("POST", "/api/user/update-profile", {
  token: tokenA,
  body: { username: "Integration A2", coins: 999999, trophyPoints: 99999 },
});
assert(
  forgedUpdate.status === 200 && forgedUpdate.data.profile.coins === 275,
  "profile endpoint ignores forged currency fields",
);

const addFriend = await request("POST", "/api/friends/add", {
  token: tokenA,
  body: { query: guestB.data.profile.tag },
});
assert(
  addFriend.status === 200 &&
    addFriend.data.friend.id === guestB.data.profile.id,
  "friend added by real player tag",
);
assert(
  !("email" in addFriend.data.friend),
  "public friend DTO excludes private identity data",
);
const friendsB = await request("GET", "/api/friends", { token: tokenB });
assert(
  friendsB.data.length === 1 && friendsB.data[0].id === guestA.data.profile.id,
  "friendship is mutual and persistent",
);

const socketA = await TestSocket.connect(tokenA);
const socketB = await TestSocket.connect(tokenB);
try {
  socketA.send({
    type: "QUEUE_JOIN",
    roomTypeId: "primary_school",
    penModel: "hiSchoolClassic",
  });
  const waiting = await socketA.waitFor("QUEUE_WAITING");
  assert(
    waiting.roomTypeId === "primary_school",
    "first human enters a real queue",
  );
  socketB.send({
    type: "QUEUE_JOIN",
    roomTypeId: "primary_school",
    penModel: "hiSchoolClassic",
  });
  const startA = await socketA.waitFor("MATCH_START");
  const startB = await socketB.waitFor("MATCH_START");
  assert(
    startA.roomId === startB.roomId,
    "both clients receive the same authoritative room",
  );
  assert(
    startA.initialState.pens.length === 2 && startA.isBot === false,
    "match includes real spawn state and no fake bot",
  );
  assert(startA.p2.id !== startA.p1.id, "two distinct humans are matched");
  assert(
    startA.initialState.pens.every((pen: any) =>
      pen.h === 132.5 && pen.m > 0 && pen.visc > 0
    ) && startA.inputLocked === false,
    "verified pen loadouts configure authoritative dimensions and damping",
  );

  const actorIsA = startA.firstTurn === guestA.data.profile.id;
  const actor = actorIsA ? socketA : socketB;
  const actorStart = actorIsA ? startA : startB;
  const actorSide = actorStart.p1.id === actorStart.firstTurn ? 0 : 1;
  actor.send({
    type: "FLICK_SUBMIT",
    impulseX: 15,
    impulseY: 0,
    strikeOffset: 0.2,
  });
  const shotA = await socketA.waitFor("SHOT_RESULT");
  const shotB = await socketB.waitFor("SHOT_RESULT");
  assert(
    shotA.frames.length > 1 && shotB.frames.length === shotA.frames.length,
    "server returns identical shot keyframes",
  );
  assert(
    shotA.actorId === startA.firstTurn && shotA.nextTurn !== shotA.actorId &&
      shotA.roomId === startA.roomId && shotB.roomId === startA.roomId,
    "authoritative actor, next turn, and room identity",
  );
  const xIndex = actorSide === 0 ? 1 : 5;
  const travel = shotA.frames[1][xIndex] - shotA.frames[0][xIndex];
  assert(
    Math.sign(travel) === (actorSide === 0 ? 1 : -1),
    "a rightward local drag moves toward the opponent for either authoritative side",
  );

  // The server unlocks input only after both clients have had time to play the
  // authoritative keyframes, matching the Flutter game screen.
  await new Promise((resolve) =>
    setTimeout(resolve, Math.ceil(shotA.duration * 1000) + 200)
  );
  const second = actorIsA ? socketB : socketA;
  const secondSide = 1 - actorSide;
  second.send({
    type: "FLICK_SUBMIT",
    impulseX: 12,
    impulseY: 0,
    strikeOffset: -0.2,
  });
  const secondShot = await socketA.waitFor("SHOT_RESULT");
  await socketB.waitFor("SHOT_RESULT");
  const secondXIndex = secondSide === 0 ? 1 : 5;
  const secondTravel = secondShot.frames[1][secondXIndex] -
    secondShot.frames[0][secondXIndex];
  assert(
    Math.sign(secondTravel) === (secondSide === 0 ? 1 : -1),
    "the opponent's rightward local drag is also normalized correctly",
  );

  socketA.send({ type: "MATCH_KNOCKOUT", winnerId: guestA.data.profile.id });
  const forgedWinner = await socketA.waitFor("ERROR");
  assert(
    forgedWinner.code === "UNKNOWN_ACTION",
    "clients cannot select match winners",
  );

  socketA.send({ type: "SURRENDER" });
  const overA = await socketA.waitFor("MATCH_OVER");
  const overB = await socketB.waitFor("MATCH_OVER");
  assert(
    overA.winnerId === guestB.data.profile.id &&
      overB.winnerId === guestB.data.profile.id &&
      overA.roomId === startA.roomId && overB.roomId === startA.roomId,
    "surrender settles the correct room for the opponent",
  );
  assert(
    overA.profile.coins === 225 && overA.payout === 0 &&
      overA.trophyDelta === -15,
    "loser receives own loss settlement",
  );
  assert(
    overB.profile.coins === 320 && overB.payout === 95 &&
      overB.trophyDelta === 25,
    "winner receives own pot and rating",
  );
  assert(
    overA.profile.stats.losses === 1 && overB.profile.stats.wins === 1,
    "both career profiles are updated",
  );

  socketA.send({ type: "REMATCH_REQUEST" });
  const offer = await socketB.waitFor("REMATCH_OFFER");
  assert(
    offer.requesterId === guestA.data.profile.id,
    "rematch offer reaches the recent opponent",
  );
  socketB.send({ type: "REMATCH_RESPOND", accept: true });
  const rematchA = await socketA.waitFor("MATCH_START");
  const rematchB = await socketB.waitFor("MATCH_START");
  assert(
    rematchA.roomId === rematchB.roomId && rematchA.roomId !== startA.roomId,
    "accepted rematch creates a new escrowed room",
  );
  socketA.send({ type: "SURRENDER" });
  await socketA.waitFor("MATCH_OVER");
  await socketB.waitFor("MATCH_OVER");
} finally {
  socketA.close();
  socketB.close();
}

const leaderboard = await request("GET", "/api/leaderboard?filter=global", {
  token: tokenA,
});
assert(
  leaderboard.status === 200 && leaderboard.data.length >= 2,
  "leaderboard reads persistent match ratings",
);
assert(
  leaderboard.data.every((entry: any) =>
    !("email" in entry) && entry.friends.length === 0
  ),
  "leaderboard exposes only public DTOs",
);
console.log(
  "PASS: authenticated REST + two-client authoritative multiplayer integration",
);
