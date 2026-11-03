// server_deno/validation.ts
import { ARENA_ROOMS } from "./arena_config.ts";
import { PEN_CATALOG } from "./catalog.ts";

export class HttpError extends Error {
  constructor(
    public readonly status: number,
    public readonly code: string,
    message: string,
  ) {
    super(message);
    this.name = "HttpError";
  }
}

function stripControlCharacters(value: string): string {
  return Array.from(value, (character) => {
    const codePoint = character.codePointAt(0)!;
    return codePoint <= 0x1f || codePoint === 0x7f ? "" : character;
  }).join("");
}

export function cleanText(
  value: unknown,
  fallback: string,
  min: number,
  max: number,
): string {
  const text = stripControlCharacters(
    typeof value === "string" ? value : fallback,
  ).trim();
  if (text.length < min || text.length > max) {
    throw new HttpError(
      400,
      "INVALID_INPUT",
      `Text must contain ${min}-${max} characters.`,
    );
  }
  return text;
}

export function optionalText(
  value: unknown,
  fallback: string,
  max: number,
): string {
  if (value === undefined || value === null) return fallback;
  if (typeof value !== "string") {
    throw new HttpError(400, "INVALID_INPUT", "Invalid text value.");
  }
  const text = stripControlCharacters(value).trim();
  if (text.length > max) {
    throw new HttpError(
      400,
      "INVALID_INPUT",
      `Text exceeds ${max} characters.`,
    );
  }
  return text;
}

export function cleanUsername(
  value: unknown,
  fallback = "Kolom Player",
): string {
  return cleanText(value, fallback, 2, 24);
}

export function cleanRegion(value: unknown, fallback = "BD"): string {
  const region = optionalText(value, fallback, 16).toUpperCase();
  if (!/^[A-Z]{2,8}(?:-[A-Z]{2,8})?$/.test(region)) {
    throw new HttpError(400, "INVALID_REGION", "Invalid region code.");
  }
  return region;
}

export function cleanDivision(value: unknown, fallback = "Dhaka"): string {
  const division = optionalText(value, fallback, 32);
  if (!/^[\p{L}\p{N} .'-]{2,32}$/u.test(division)) {
    throw new HttpError(400, "INVALID_DIVISION", "Invalid division or city.");
  }
  return division;
}

export function cleanFlag(value: unknown, fallback = "🇧🇩"): string {
  return optionalText(value, fallback, 16);
}

export function cleanAvatar(value: unknown, fallback = "avatar_shuvo"): string {
  const avatar = optionalText(value, fallback, 96);
  if (!/^avatar_[a-z0-9_]{1,64}$/.test(avatar)) {
    throw new HttpError(
      400,
      "INVALID_AVATAR",
      "Choose an avatar from the built-in catalog.",
    );
  }
  return avatar;
}

export function cleanPenId(value: unknown): string {
  if (typeof value !== "string" || !PEN_CATALOG[value]) {
    throw new HttpError(400, "INVALID_PEN", "Unknown pen model.");
  }
  return value;
}

export function cleanArenaId(value: unknown): string {
  if (typeof value !== "string" || !ARENA_ROOMS[value]) {
    throw new HttpError(400, "INVALID_ARENA", "Unknown arena.");
  }
  return value;
}

export function cleanRoomCode(value: unknown): string {
  if (typeof value !== "string" || !/^\d{6}$/.test(value)) {
    throw new HttpError(
      400,
      "INVALID_ROOM_CODE",
      "Enter the six-digit room code.",
    );
  }
  return value;
}

export function finiteNumber(value: unknown, min: number, max: number): number {
  if (
    typeof value !== "number" || !Number.isFinite(value) || value < min ||
    value > max
  ) {
    throw new HttpError(
      400,
      "INVALID_INPUT",
      "A numeric value is outside its allowed range.",
    );
  }
  return value;
}

export function asObject(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new HttpError(400, "INVALID_JSON", "Expected a JSON object.");
  }
  return value as Record<string, unknown>;
}
