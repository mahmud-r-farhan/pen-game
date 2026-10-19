// server_deno/physics_sim_test.ts
/// <reference path="./deno.d.ts" />
// deno-lint-ignore no-import-prefix
import { assertEquals, assertAlmostEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { simulateTurn, SimState } from "./physics_sim.ts";

Deno.test("Physics Engine - Parity with Shared Vectors", () => {
  let content = "";
  try {
    content = Deno.readTextFileSync("../test_vectors/shared_physics_vectors.json");
  } catch (_) {
    content = Deno.readTextFileSync("test_vectors/shared_physics_vectors.json");
  }
  const data = JSON.parse(content);

  for (const tc of data) {
    const simRes = simulateTurn(tc.initialState as SimState, tc.activeSide, tc.shot, 5.0);
    const exp = tc.expectedFinalState;

    assertAlmostEquals(simRes.finalState.pens[0].x, exp.pen0.x, 0.05, `${tc.name}: pen0 x`);
    assertAlmostEquals(simRes.finalState.pens[0].y, exp.pen0.y, 0.05, `${tc.name}: pen0 y`);
    assertAlmostEquals(simRes.finalState.pens[1].x, exp.pen1.x, 0.05, `${tc.name}: pen1 x`);
    assertAlmostEquals(simRes.finalState.pens[1].y, exp.pen1.y, 0.05, `${tc.name}: pen1 y`);
    assertEquals(simRes.fell, exp.fell, `${tc.name}: fell`);
    assertEquals(simRes.winner, exp.winner, `${tc.name}: winner`);
  }
});
