// server_deno/auth.ts
/// <reference path="./deno.d.ts" />

const SESSION_TTL_MS = 30 * 24 * 60 * 60 * 1000;
const WS_TICKET_TTL_MS = 60 * 1000;
const FIREBASE_PROJECT_ID = Deno.env.get("FIREBASE_PROJECT_ID") ??
  "kolom-khela";
const FIREBASE_JWKS_URL =
  "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com";

const kv = await Deno.openKv();

export class AuthError extends Error {
  constructor(message: string, public readonly status = 401) {
    super(message);
    this.name = "AuthError";
  }
}

export interface SessionRecord {
  userId: string;
  expiresAt: number;
}

export interface FirebaseIdentity {
  uid: string;
  name: string;
  email: string;
  picture: string;
}

interface FirebaseJwtPayload {
  sub?: string;
  user_id?: string;
  aud?: string;
  iss?: string;
  exp?: number;
  iat?: number;
  name?: string;
  email?: string;
  picture?: string;
  firebase?: { sign_in_provider?: string };
}

type FirebaseJwk = JsonWebKey & { kid?: string };

let firebaseKeys: FirebaseJwk[] = [];
let firebaseKeysExpireAt = 0;

function bytesToBase64Url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replaceAll(
    "=",
    "",
  );
}

function base64UrlDecode(value: string): Uint8Array {
  const normalized = value.replaceAll("-", "+").replaceAll("_", "/");
  const padded = normalized + "=".repeat((4 - normalized.length % 4) % 4);
  const binary = atob(padded);
  return Uint8Array.from(binary, (char) => char.charCodeAt(0));
}

function decodeJsonPart<T>(part: string): T {
  try {
    return JSON.parse(new TextDecoder().decode(base64UrlDecode(part))) as T;
  } catch {
    throw new AuthError("Malformed identity token.");
  }
}

export function randomToken(byteLength = 32): string {
  const bytes = crypto.getRandomValues(new Uint8Array(byteLength));
  return bytesToBase64Url(bytes);
}

export async function hashToken(token: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(token),
  );
  return bytesToBase64Url(new Uint8Array(digest));
}

export async function createSession(
  userId: string,
): Promise<{ token: string; expiresAt: number }> {
  const token = randomToken();
  const expiresAt = Date.now() + SESSION_TTL_MS;
  const record: SessionRecord = { userId, expiresAt };
  await kv.set(["sessions", await hashToken(token)], record, {
    expireIn: SESSION_TTL_MS,
  });
  return { token, expiresAt };
}

export async function getSession(token: string): Promise<SessionRecord | null> {
  if (token.length < 32 || token.length > 256) return null;
  const key = ["sessions", await hashToken(token)];
  const result = await kv.get<SessionRecord>(key);
  if (!result.value) return null;
  if (result.value.expiresAt <= Date.now()) {
    await kv.delete(key);
    return null;
  }
  return result.value;
}

export async function revokeSession(token: string): Promise<void> {
  if (token.length >= 32 && token.length <= 256) {
    await kv.delete(["sessions", await hashToken(token)]);
  }
}

export async function revokeAllSessions(userId: string): Promise<void> {
  const deletions: Deno.KvKey[] = [];
  for await (const entry of kv.list<SessionRecord>({ prefix: ["sessions"] })) {
    if (entry.value.userId === userId) deletions.push(entry.key);
  }
  for (const key of deletions) await kv.delete(key);
}

export async function createWebSocketTicket(userId: string): Promise<string> {
  const ticket = randomToken();
  await kv.set(
    ["ws_tickets", await hashToken(ticket)],
    { userId, expiresAt: Date.now() + WS_TICKET_TTL_MS },
    { expireIn: WS_TICKET_TTL_MS },
  );
  return ticket;
}

export async function consumeWebSocketTicket(
  ticket: string,
): Promise<string | null> {
  if (ticket.length < 32 || ticket.length > 256) return null;
  const key = ["ws_tickets", await hashToken(ticket)];

  for (let attempt = 0; attempt < 3; attempt++) {
    const result = await kv.get<{ userId: string; expiresAt: number }>(key);
    if (!result.value || result.value.expiresAt <= Date.now()) return null;
    const committed = await kv.atomic().check(result).delete(key).commit();
    if (committed.ok) return result.value.userId;
  }
  return null;
}

export function bearerToken(request: Request): string | null {
  const header = request.headers.get("authorization");
  if (!header?.startsWith("Bearer ")) return null;
  const token = header.slice(7).trim();
  return token || null;
}

async function loadFirebaseKeys(forceRefresh = false): Promise<FirebaseJwk[]> {
  if (
    !forceRefresh && firebaseKeys.length > 0 &&
    firebaseKeysExpireAt > Date.now()
  ) {
    return firebaseKeys;
  }

  let response: Response;
  try {
    response = await fetch(FIREBASE_JWKS_URL, {
      headers: { Accept: "application/json" },
    });
  } catch {
    throw new AuthError("Identity provider is temporarily unavailable.", 503);
  }
  if (!response.ok) {
    throw new AuthError("Identity provider is temporarily unavailable.", 503);
  }

  const payload = await response.json() as { keys?: FirebaseJwk[] };
  if (!Array.isArray(payload.keys) || payload.keys.length === 0) {
    throw new AuthError("Identity provider returned no signing keys.", 503);
  }
  firebaseKeys = payload.keys;
  firebaseKeysExpireAt = Date.now() + 60 * 60 * 1000;
  return firebaseKeys;
}

async function verifySignature(
  token: string,
  keys: FirebaseJwk[],
): Promise<FirebaseJwtPayload> {
  const parts = token.split(".");
  if (parts.length !== 3) throw new AuthError("Malformed identity token.");
  const header = decodeJsonPart<{ alg?: string; kid?: string }>(parts[0]);
  if (header.alg !== "RS256" || !header.kid) {
    throw new AuthError("Unsupported identity token.");
  }
  const jwk = keys.find((key) => key.kid === header.kid && key.kty === "RSA");
  if (!jwk) {
    throw new AuthError("Identity token signing key was not recognized.");
  }

  let key: CryptoKey;
  try {
    key = await crypto.subtle.importKey(
      "jwk",
      jwk,
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      false,
      ["verify"],
    );
  } catch {
    throw new AuthError("Identity token signing key is invalid.");
  }

  let signature: Uint8Array;
  try {
    signature = base64UrlDecode(parts[2]);
  } catch {
    throw new AuthError("Malformed identity token signature.");
  }
  const valid = await crypto.subtle.verify(
    "RSASSA-PKCS1-v1_5",
    key,
    signature.buffer as ArrayBuffer,
    new TextEncoder().encode(`${parts[0]}.${parts[1]}`),
  );
  if (!valid) throw new AuthError("Identity token signature is invalid.");
  return decodeJsonPart<FirebaseJwtPayload>(parts[1]);
}

/** Verifies a real Firebase Auth ID token; no client-supplied UID is trusted. */
export async function verifyFirebaseGoogleIdToken(
  idToken: string,
): Promise<FirebaseIdentity> {
  if (idToken.length < 100 || idToken.length > 8192) {
    throw new AuthError("A valid Firebase ID token is required.");
  }

  let keys = await loadFirebaseKeys();
  let payload: FirebaseJwtPayload;
  try {
    payload = await verifySignature(idToken, keys);
  } catch (error) {
    if (
      !(error instanceof AuthError) || !error.message.includes("signing key")
    ) throw error;
    keys = await loadFirebaseKeys(true);
    payload = await verifySignature(idToken, keys);
  }

  const now = Math.floor(Date.now() / 1000);
  const acceptedIssuers = new Set([
    `https://securetoken.google.com/${FIREBASE_PROJECT_ID}`,
    `securetoken.google.com/${FIREBASE_PROJECT_ID}`,
  ]);
  if (
    payload.aud !== FIREBASE_PROJECT_ID || !payload.iss ||
    !acceptedIssuers.has(payload.iss)
  ) {
    throw new AuthError(
      "Identity token was issued for a different Firebase project.",
    );
  }
  if (
    !payload.exp || !payload.iat || payload.exp <= now ||
    payload.iat > now + 300
  ) {
    throw new AuthError("Identity token is expired or not yet valid.");
  }
  if (payload.firebase?.sign_in_provider !== "google.com") {
    throw new AuthError("Google sign-in is required for this operation.");
  }

  const uid = payload.user_id ?? payload.sub;
  if (!uid || uid.length > 128) {
    throw new AuthError("Identity token has no valid subject.");
  }
  return {
    uid,
    name: typeof payload.name === "string" ? payload.name : "Kolom Player",
    email: typeof payload.email === "string" ? payload.email : "",
    picture: typeof payload.picture === "string" ? payload.picture : "",
  };
}
