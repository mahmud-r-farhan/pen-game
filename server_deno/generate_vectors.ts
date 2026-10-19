// server_deno/generate_vectors.ts
/// <reference path="./deno.d.ts" />
import { makePen, SimPen, SimShot, SimState, simulateTurn } from "./physics_sim.ts";

interface VectorTestCase {
  name: string;
  initialState: SimState;
  activeSide: number;
  shot: SimShot;
}

const testCases: VectorTestCase[] = [
  {
    name: "straight_head_on_collision",
    initialState: {
      pens: [
        makePen(0, 242, 320, 0),
        makePen(1, 858, 320, Math.PI),
      ],
      ended: false,
      winner: -1,
    },
    activeSide: 0,
    shot: { ang: 0, power: 0.85, rx: 0, ry: 0 },
  },
  {
    name: "glancing_whip_spin_strike",
    initialState: {
      pens: [
        makePen(0, 350, 280, 0.2),
        makePen(1, 650, 310, 3.1),
      ],
      ended: false,
      winner: -1,
    },
    activeSide: 0,
    shot: { ang: 0.12, power: 0.9, rx: 35, ry: 0 },
  },
  {
    name: "edge_knockout_push",
    initialState: {
      pens: [
        makePen(0, 750, 510, 1.4),
        makePen(1, 800, 570, 1.5),
      ],
      ended: false,
      winner: -1,
    },
    activeSide: 0,
    shot: { ang: 1.52, power: 0.88, rx: 0, ry: 0 },
  },
];

const results = testCases.map((tc) => {
  const simRes = simulateTurn(tc.initialState, tc.activeSide, tc.shot, 5.0);
  return {
    name: tc.name,
    initialState: tc.initialState,
    activeSide: tc.activeSide,
    shot: tc.shot,
    expectedFinalState: {
      pen0: {
        x: simRes.finalState.pens[0].x,
        y: simRes.finalState.pens[0].y,
        a: simRes.finalState.pens[0].a,
        fall: simRes.finalState.pens[0].fall,
      },
      pen1: {
        x: simRes.finalState.pens[1].x,
        y: simRes.finalState.pens[1].y,
        a: simRes.finalState.pens[1].a,
        fall: simRes.finalState.pens[1].fall,
      },
      fell: simRes.fell,
      winner: simRes.winner,
    },
  };
});

try {
  Deno.mkdirSync("test_vectors", { recursive: true });
} catch (_) {
  // Directory exists
}
Deno.writeTextFileSync(
  "test_vectors/shared_physics_vectors.json",
  JSON.stringify(results, null, 2),
);
console.log("Successfully generated test_vectors/shared_physics_vectors.json with", results.length, "cases");
