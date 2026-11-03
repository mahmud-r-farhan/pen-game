// server_deno/physics_sim.ts
// Pure, deterministic physics simulation ported from Pen Fight prototype

export const TAU = Math.PI * 2;
export const W = 1100;
export const H = 640;
export const LIP = 30;
export const STEP = 1 / 240;
export const PEN_H = 78;
export const PEN_R = 10;
export const PEN_M = 1;
export const PEN_I = (2 * (PEN_H + PEN_R)) ** 2 / 12 * 1.6;
export const VISC = 1.25;
export const COUL = 110;
export const AVISC = 5.5;
export const ACOUL = 4;
export const REST = 0.5;
export const MU = 0.25;
export const MAXV = 1400;
export const MAXPULL = 190;
export const MINPULL = 14;
export const SPIN_K = 0.35;

export function clamp(v: number, a: number, b: number): number {
  return v < a ? a : v > b ? b : v;
}

export function rand(a: number, b: number): number {
  return a + Math.random() * (b - a);
}

export function gauss(): number {
  let u = 0, v = 0;
  while (!u) u = Math.random();
  while (!v) v = Math.random();
  return Math.sqrt(-2 * Math.log(u)) * Math.cos(TAU * v);
}

export interface SimPen {
  owner: number; // 0 or 1
  x: number;
  y: number;
  a: number; // angle in radians
  vx: number;
  vy: number;
  w: number; // angular velocity
  h: number; // half length
  r: number; // radius
  // Optional server-owned loadout/surface tuning. Missing values preserve the
  // original shared-vector physics used by makePen() and regression fixtures.
  m?: number;
  i?: number;
  visc?: number;
  coul?: number;
  avisc?: number;
  acoul?: number;
  rest?: number;
  fall: number; // 0 if on table, > 0 if fallen
}

export interface SimPenPhysics {
  h?: number;
  r?: number;
  m?: number;
  i?: number;
  visc?: number;
  coul?: number;
  avisc?: number;
  acoul?: number;
  rest?: number;
}

export interface SimShot {
  ang: number;
  power: number; // 0.0 to 1.0
  rx: number;
  ry: number;
}

export interface SimState {
  pens: [SimPen, SimPen];
  ended: boolean;
  winner: number; // -1 if not ended or draw, 0 or 1
}

export interface HitEvent {
  t: number;
  x: number;
  y: number;
  impact: number;
}

// 60Hz Keyframe: [t, x0, y0, a0, fall0, x1, y1, a1, fall1]
export type KeyframeSample = [
  number, // t
  number, // x0
  number, // y0
  number, // a0
  number, // fall0
  number, // x1
  number, // y1
  number, // a1
  number, // fall1
];

export interface TurnSimulationResult {
  frames: KeyframeSample[];
  events: HitEvent[];
  fell: number; // -1 none, 0 pen0 fell, 1 pen1 fell, 2 both fell
  finalState: SimState;
  winner: number; // -1 if match ongoing, 0 or 1
  duration: number;
}

export function makePen(
  owner: number,
  x: number,
  y: number,
  a: number,
  physics: SimPenPhysics = {},
): SimPen {
  return {
    owner,
    x,
    y,
    a,
    vx: 0,
    vy: 0,
    w: 0,
    h: physics.h ?? PEN_H,
    r: physics.r ?? PEN_R,
    m: physics.m,
    i: physics.i,
    visc: physics.visc,
    coul: physics.coul,
    avisc: physics.avisc,
    acoul: physics.acoul,
    rest: physics.rest,
    fall: 0,
  };
}

export function clonePen(p: SimPen): SimPen {
  return { ...p };
}

export function cloneState(s: SimState): SimState {
  return {
    pens: [clonePen(s.pens[0]), clonePen(s.pens[1])],
    ended: s.ended,
    winner: s.winner,
  };
}

export function edgeDist(p: SimPen): number {
  return Math.min(p.x, W - p.x, p.y, H - p.y);
}

export function travelDist(v: number): number {
  if (v < 8) return 0;
  const k = VISC, c = COUL;
  const q = (c / k) / (v + c / k);
  const t = Math.log(1 / q) / k;
  return (v + c / k) / k * (1 - q) - c * t / k;
}

interface SegResult {
  x1: number;
  y1: number;
  x2: number;
  y2: number;
}

const _seg: SegResult = { x1: 0, y1: 0, x2: 0, y2: 0 };

export function segSeg(
  p1x: number,
  p1y: number,
  q1x: number,
  q1y: number,
  p2x: number,
  p2y: number,
  q2x: number,
  q2y: number,
  o: SegResult,
) {
  const d1x = q1x - p1x, d1y = q1y - p1y;
  const d2x = q2x - p2x, d2y = q2y - p2y;
  const rx = p1x - p2x, ry = p1y - p2y;
  const a = d1x * d1x + d1y * d1y;
  const e = d2x * d2x + d2y * d2y;
  const f = d2x * rx + d2y * ry;
  let s: number, t: number;
  const c = d1x * rx + d1y * ry;
  const b = d1x * d2x + d1y * d2y;
  const denom = a * e - b * b;

  s = denom > 1e-9 ? clamp((b * f - c * e) / denom, 0, 1) : 0;
  t = (b * s + f) / e;
  if (t < 0) {
    t = 0;
    s = clamp(-c / a, 0, 1);
  } else if (t > 1) {
    t = 1;
    s = clamp((b - c) / a, 0, 1);
  }
  o.x1 = p1x + d1x * s;
  o.y1 = p1y + d1y * s;
  o.x2 = p2x + d2x * t;
  o.y2 = p2y + d2y * t;
}

export function collide(
  A: SimPen,
  B: SimPen,
  onHit?: (x: number, y: number, impact: number) => void,
) {
  const rs = A.r + B.r;
  const cdx = B.x - A.x, cdy = B.y - A.y;
  const reach = A.h + B.h + rs;
  if (cdx * cdx + cdy * cdy > reach * reach) return;

  const ca = Math.cos(A.a), sa = Math.sin(A.a);
  const cb = Math.cos(B.a), sb = Math.sin(B.a);

  segSeg(
    A.x - ca * A.h,
    A.y - sa * A.h,
    A.x + ca * A.h,
    A.y + sa * A.h,
    B.x - cb * B.h,
    B.y - sb * B.h,
    B.x + cb * B.h,
    B.y + sb * B.h,
    _seg,
  );

  const dx = _seg.x2 - _seg.x1;
  const dy = _seg.y2 - _seg.y1;
  let d = Math.hypot(dx, dy);
  if (d >= rs) return;

  let nx: number, ny: number, cx: number, cy: number;
  if (d > 1e-6) {
    nx = dx / d;
    ny = dy / d;
    cx = _seg.x1 + nx * A.r;
    cy = _seg.y1 + ny * A.r;
  } else {
    nx = -sa;
    ny = ca;
    if (nx * cdx + ny * cdy < 0) {
      nx = -nx;
      ny = -ny;
    }
    cx = (_seg.x1 + _seg.x2) / 2;
    cy = (_seg.y1 + _seg.y2) / 2;
    d = 0;
  }

  const pen = rs - d;
  const invMA = 1 / (A.m ?? PEN_M);
  const invMB = 1 / (B.m ?? PEN_M);
  const invIA = 1 / (A.i ?? PEN_I);
  const invIB = 1 / (B.i ?? PEN_I);
  const totalInvMass = invMA + invMB;
  A.x -= nx * pen * invMA / totalInvMass;
  A.y -= ny * pen * invMA / totalInvMass;
  B.x += nx * pen * invMB / totalInvMass;
  B.y += ny * pen * invMB / totalInvMass;

  const rax = cx - A.x, ray = cy - A.y;
  const rbx = cx - B.x, rby = cy - B.y;

  const vax = A.vx - A.w * ray;
  const vay = A.vy + A.w * rax;
  const vbx = B.vx - B.w * rby;
  const vby = B.vy + B.w * rbx;

  const rvx = vbx - vax;
  const rvy = vby - vay;
  const vn = rvx * nx + rvy * ny;
  if (vn > 0) return;

  const raN = rax * ny - ray * nx;
  const rbN = rbx * ny - rby * nx;
  const kN = invMA + invMB + raN * raN * invIA + rbN * rbN * invIB;
  const restitution = ((A.rest ?? REST) + (B.rest ?? REST)) / 2;
  const j = -(1 + restitution) * vn / kN;

  A.vx -= j * nx * invMA;
  A.vy -= j * ny * invMA;
  A.w -= raN * j * invIA;
  B.vx += j * nx * invMB;
  B.vy += j * ny * invMB;
  B.w += rbN * j * invIB;

  // Tangential friction
  const vax2 = A.vx - A.w * ray;
  const vay2 = A.vy + A.w * rax;
  const vbx2 = B.vx - B.w * rby;
  const vby2 = B.vy + B.w * rbx;
  const rvx2 = vbx2 - vax2;
  const rvy2 = vby2 - vay2;

  const tx = -ny, ty = nx;
  const vt = rvx2 * tx + rvy2 * ty;
  const raT = rax * ty - ray * tx;
  const rbT = rbx * ty - rby * tx;
  const kT = invMA + invMB + raT * raT * invIA + rbT * rbT * invIB;
  let jt = -vt / kT;
  const lim = MU * j;
  jt = clamp(jt, -lim, lim);

  A.vx -= jt * tx * invMA;
  A.vy -= jt * ty * invMA;
  A.w -= raT * jt * invIA;
  B.vx += jt * tx * invMB;
  B.vy += jt * ty * invMB;
  B.w += rbT * jt * invIB;

  if (onHit) onHit(cx, cy, -vn);
}

export function applyShot(p: SimPen, shot: SimShot) {
  const mass = p.m ?? PEN_M;
  const inertia = p.i ?? PEN_I;
  // Equal flick impulse: heavier pens launch more slowly but carry their mass
  // into collisions, matching the offline Forge2D loadout behavior.
  const v = shot.power * MAXV * PEN_M / mass;
  const dx = Math.cos(shot.ang);
  const dy = Math.sin(shot.ang);
  p.vx += dx * v;
  p.vy += dy * v;
  if (shot.rx || shot.ry) {
    p.w += (shot.rx * dy * v - shot.ry * dx * v) / (inertia / mass) * SPIN_K;
  }
}

export function stepPhysics(
  S: SimState,
  dt: number,
  onHit?: (x: number, y: number, impact: number) => void,
) {
  const pens = S.pens;
  for (let i = 0; i < 2; i++) {
    const p = pens[i];
    p.x += p.vx * dt;
    p.y += p.vy * dt;
    p.a += p.w * dt;

    if (p.fall > 0) {
      p.fall += dt * 1.6;
      const k = Math.exp(-0.6 * dt);
      p.vx *= k;
      p.vy *= k;
      continue;
    }

    const sp = Math.hypot(p.vx, p.vy);
    if (sp > 0) {
      const visc = p.visc ?? VISC;
      const coul = p.coul ?? COUL;
      const ns = Math.max(0, sp * Math.exp(-visc * dt) - coul * dt);
      if (ns < 6) {
        p.vx = 0;
        p.vy = 0;
      } else {
        const k = ns / sp;
        p.vx *= k;
        p.vy *= k;
      }
    }

    if (p.w !== 0) {
      const avisc = p.avisc ?? AVISC;
      const acoul = p.acoul ?? ACOUL;
      let nw = Math.max(0, Math.abs(p.w) * Math.exp(-avisc * dt) - acoul * dt);
      if (nw < 0.08) nw = 0;
      p.w = Math.sign(p.w) * nw;
    }
  }

  if (pens[0].fall === 0 && pens[1].fall === 0) {
    collide(pens[0], pens[1], onHit);
  }

  for (let i = 0; i < 2; i++) {
    const p = pens[i];
    if (p.fall === 0 && (p.x < 0 || p.x > W || p.y < 0 || p.y > H)) {
      p.fall = 0.0001;
      if (p.x < 0) p.vx = Math.min(p.vx, -110);
      if (p.x > W) p.vx = Math.max(p.vx, 110);
      if (p.y < 0) p.vy = Math.min(p.vy, -110);
      if (p.y > H) p.vy = Math.max(p.vy, 110);
    }
  }
}

export function settled(S: SimState): boolean {
  return S.pens.every((p) =>
    p.fall > 0 || (p.vx === 0 && p.vy === 0 && p.w === 0)
  );
}

export function createInitialMatchState(
  p1Physics: SimPenPhysics = {},
  p2Physics: SimPenPhysics = {},
): SimState {
  const y = H / 2 + rand(-90, 90);
  const a = rand(-0.55, 0.55);
  return {
    pens: [
      makePen(0, W * 0.22, y, a, p1Physics),
      makePen(1, W - W * 0.22, H - y, a + Math.PI, p2Physics),
    ],
    ended: false,
    winner: -1,
  };
}

/**
 * Runs server-authoritative turn physics and samples keyframes at 60 Hz.
 */
export function simulateTurn(
  initialState: SimState,
  activeSide: number,
  shot: SimShot,
  maxSimSeconds = 6.0,
): TurnSimulationResult {
  const sim = cloneState(initialState);
  applyShot(sim.pens[activeSide], shot);

  const frames: KeyframeSample[] = [];
  const events: HitEvent[] = [];

  const sampleInterval = 1 / 60; // 60 FPS keyframe sampling
  let nextSampleTime = 0;
  let elapsed = 0;

  // Record initial frame
  frames.push([
    0,
    round3(sim.pens[0].x),
    round3(sim.pens[0].y),
    round4(sim.pens[0].a),
    round3(sim.pens[0].fall),
    round3(sim.pens[1].x),
    round3(sim.pens[1].y),
    round4(sim.pens[1].a),
    round3(sim.pens[1].fall),
  ]);

  while (elapsed < maxSimSeconds) {
    stepPhysics(sim, STEP, (x, y, impact) => {
      if (impact > 25) {
        events.push({
          t: round3(elapsed),
          x: round2(x),
          y: round2(y),
          impact: round2(impact),
        });
      }
    });

    elapsed += STEP;

    if (elapsed >= nextSampleTime) {
      frames.push([
        round3(elapsed),
        round3(sim.pens[0].x),
        round3(sim.pens[0].y),
        round4(sim.pens[0].a),
        round3(sim.pens[0].fall),
        round3(sim.pens[1].x),
        round3(sim.pens[1].y),
        round4(sim.pens[1].a),
        round3(sim.pens[1].fall),
      ]);
      nextSampleTime += sampleInterval;
    }

    if (sim.pens[0].fall > 0 || sim.pens[1].fall > 0) {
      // Continue simulation for extra 0.8s so fall tumble finishes smoothly
      if (sim.pens[0].fall > 0.8 || sim.pens[1].fall > 0.8) {
        break;
      }
    } else if (settled(sim) && elapsed > 0.25) {
      break;
    }
  }

  // Final settling snapshot
  frames.push([
    round3(elapsed),
    round3(sim.pens[0].x),
    round3(sim.pens[0].y),
    round4(sim.pens[0].a),
    round3(sim.pens[0].fall),
    round3(sim.pens[1].x),
    round3(sim.pens[1].y),
    round4(sim.pens[1].a),
    round3(sim.pens[1].fall),
  ]);

  const f0 = sim.pens[0].fall > 0;
  const f1 = sim.pens[1].fall > 0;
  let fell = -1;
  let winner = -1;

  if (f0 && f1) {
    fell = 2;
    sim.ended = true;
    sim.winner = -1;
  } else if (f0) {
    fell = 0;
    sim.ended = true;
    sim.winner = 1;
    winner = 1;
  } else if (f1) {
    fell = 1;
    sim.ended = true;
    sim.winner = 0;
    winner = 0;
  }

  return {
    frames,
    events,
    fell,
    finalState: sim,
    winner,
    duration: round3(elapsed),
  };
}

// Bot AI Monte Carlo shot planner
const BOT_CFG = [
  { n: 12, sig: 0.18, psig: 0.18, ref: 0 }, // EASY
  { n: 45, sig: 0.07, psig: 0.08, ref: 0 }, // NORMAL
  { n: 120, sig: 0.025, psig: 0.035, ref: 12 }, // HARD
  { n: 240, sig: 0.003, psig: 0.008, ref: 36 }, // INSANE
];

export function evalShot(S: SimState, shot: SimShot): number {
  const sim = cloneState(S);
  applyShot(sim.pens[1], shot);
  let touched = false;

  for (let t = 0; t < 5.0; t += STEP) {
    stepPhysics(sim, STEP, (_x, _y, imp) => {
      if (imp > 30) touched = true;
    });
    if (sim.pens[0].fall > 0 || sim.pens[1].fall > 0) break;
    if (settled(sim)) break;
  }

  const me = sim.pens[1], op = sim.pens[0];
  if (me.fall > 0 && op.fall > 0) return -50;
  if (op.fall > 0) return 1000;
  if (me.fall > 0) return -1000;

  let sc = -edgeDist(op) + Math.min(edgeDist(me), 200) * 0.6;
  if (touched) sc += 60;
  return sc;
}

export function planBotShot(S: SimState, difficulty = 1): SimShot {
  const c = BOT_CFG[Math.min(BOT_CFG.length - 1, Math.max(0, difficulty))];
  const B = S.pens[1], P = S.pens[0];
  let best: SimShot = { ang: 0, power: 0.5, rx: 0, ry: 0 };
  let bs = -1e9;

  for (let i = 0; i < c.n; i++) {
    let ang: number;
    const m = i % 4;
    if (m < 2) {
      const t = rand(-0.9, 0.9);
      ang = Math.atan2(
        P.y + Math.sin(P.a) * P.h * t - B.y,
        P.x + Math.cos(P.a) * P.h * t - B.x,
      ) + rand(-0.05, 0.05);
    } else if (m === 2) {
      ang = Math.atan2(P.y - B.y, P.x - B.x) + rand(-0.5, 0.5);
    } else {
      ang = rand(0, TAU);
    }

    const shot: SimShot = { ang, power: rand(0.3, 1.0), rx: 0, ry: 0 };
    const sc = evalShot(S, shot);
    if (sc > bs) {
      bs = sc;
      best = shot;
    }
  }

  for (let i = 0; i < c.ref; i++) {
    const s: SimShot = {
      ang: best.ang + gauss() * 0.02,
      power: clamp(best.power + gauss() * 0.06, 0.2, 1.0),
      rx: 0,
      ry: 0,
    };
    const sc = evalShot(S, s);
    if (sc > bs) {
      bs = sc;
      best = s;
    }
  }

  best.ang += gauss() * c.sig;
  best.power = clamp(best.power + gauss() * c.psig, 0.2, 1.0);
  return best;
}

function round2(v: number): number {
  return Math.round(v * 100) / 100;
}

function round3(v: number): number {
  return Math.round(v * 1000) / 1000;
}

function round4(v: number): number {
  return Math.round(v * 10000) / 10000;
}
