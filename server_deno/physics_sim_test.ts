// server_deno/physics_sim_test.ts
/// <reference path="./deno.d.ts" />
import { makePen, SimState, simulateTurn } from "./physics_sim.ts";

function assertEquals(
  actual: unknown,
  expected: unknown,
  message: string,
): void {
  if (actual !== expected) {
    throw new Error(`${message}: expected ${expected}, received ${actual}`);
  }
}

function assertAlmostEquals(
  actual: number,
  expected: number,
  tolerance: number,
  message: string,
): void {
  if (Math.abs(actual - expected) > tolerance) {
    throw new Error(
      `${message}: expected ${expected} ±${tolerance}, received ${actual}`,
    );
  }
}

Deno.test("Physics Engine - Parity with Shared Vectors", () => {
  let content = "";
  try {
    content = Deno.readTextFileSync(
      "../test_vectors/shared_physics_vectors.json",
    );
  } catch {
    content = Deno.readTextFileSync("test_vectors/shared_physics_vectors.json");
  }
  const data = JSON.parse(content);
  for (const tc of data) {
    const simRes = simulateTurn(
      tc.initialState as SimState,
      tc.activeSide,
      tc.shot,
      5.0,
    );
    const exp = tc.expectedFinalState;
    assertAlmostEquals(
      simRes.finalState.pens[0].x,
      exp.pen0.x,
      0.05,
      `${tc.name}: pen0 x`,
    );
    assertAlmostEquals(
      simRes.finalState.pens[0].y,
      exp.pen0.y,
      0.05,
      `${tc.name}: pen0 y`,
    );
    assertAlmostEquals(
      simRes.finalState.pens[1].x,
      exp.pen1.x,
      0.05,
      `${tc.name}: pen1 x`,
    );
    assertAlmostEquals(
      simRes.finalState.pens[1].y,
      exp.pen1.y,
      0.05,
      `${tc.name}: pen1 y`,
    );
    assertEquals(simRes.fell, exp.fell, `${tc.name}: fell`);
    assertEquals(simRes.winner, exp.winner, `${tc.name}: winner`);
  }
});

Deno.test("Physics Engine - Loadouts and arena damping are deterministic", () => {
  function configuredState(frictionScale: number): SimState {
    const h = 132.5;
    const r = 8;
    const m = 1;
    return {
      pens: [
        makePen(0, 200, 320, 0, {
          h,
          r,
          m,
          i: (2 * (h + r)) ** 2 / 12 * 1.6 * m,
          visc: 1.25 * frictionScale,
          coul: 110 * frictionScale,
          avisc: 5.5,
          acoul: 4,
          rest: 0.5,
        }),
        makePen(1, 900, 320, Math.PI),
      ],
      ended: false,
      winner: -1,
    };
  }

  const shot = { ang: 0, power: 0.45, rx: 20, ry: 0 };
  const lowFriction = simulateTurn(configuredState(1), 0, shot);
  const lowFrictionRepeat = simulateTurn(configuredState(1), 0, shot);
  const highFriction = simulateTurn(configuredState(2.5), 0, shot);
  assertEquals(
    JSON.stringify(lowFriction.frames),
    JSON.stringify(lowFrictionRepeat.frames),
    "identical configured states produce identical playback",
  );
  assertEquals(
    lowFriction.finalState.pens[0].x > highFriction.finalState.pens[0].x,
    true,
    "higher surface damping reduces travel",
  );
  assertEquals(
    lowFriction.frames.every((frame) => frame.every(Number.isFinite)),
    true,
    "configured loadout keyframes remain finite",
  );
});
