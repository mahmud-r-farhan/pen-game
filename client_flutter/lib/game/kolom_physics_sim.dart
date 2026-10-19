// lib/game/kolom_physics_sim.dart
// Pure, deterministic physics simulation for Kolom Fight (matching server_deno)
import 'dart:math' as math;

const double tau = math.pi * 2;
const double simW = 1100.0;
const double simH = 640.0;
const double simLip = 30.0;
const double simStep = 1.0 / 240.0;
const double penH = 78.0;
const double penR = 10.0;
const double penM = 1.0;
final double penI = math.pow(2 * (penH + penR), 2) / 12.0 * 1.6;
const double visc = 1.25;
const double coul = 110.0;
const double aVisc = 5.5;
const double aCoul = 4.0;
const double rest = 0.5;
const double mu = 0.25;
const double maxV = 1400.0;
const double maxPull = 190.0;
const double minPull = 14.0;
const double spinK = 0.35;

double clampVal(double v, double a, double b) => v < a ? a : v > b ? b : v;

class SimPen {
  final int owner; // 0 or 1
  double x;
  double y;
  double a; // angle in radians
  double vx;
  double vy;
  double w; // angular velocity
  final double h;
  final double r;
  double fall; // 0 if on table, > 0 if fallen

  SimPen({
    required this.owner,
    required this.x,
    required this.y,
    required this.a,
    this.vx = 0.0,
    this.vy = 0.0,
    this.w = 0.0,
    this.h = penH,
    this.r = penR,
    this.fall = 0.0,
  });

  SimPen clone() => SimPen(
        owner: owner,
        x: x,
        y: y,
        a: a,
        vx: vx,
        vy: vy,
        w: w,
        h: h,
        r: r,
        fall: fall,
      );

  Map<String, dynamic> toJson() => {
        'owner': owner,
        'x': x,
        'y': y,
        'a': a,
        'vx': vx,
        'vy': vy,
        'w': w,
        'fall': fall,
      };

  factory SimPen.fromJson(Map<String, dynamic> json) => SimPen(
        owner: (json['owner'] as num?)?.toInt() ?? 0,
        x: (json['x'] as num?)?.toDouble() ?? 0.0,
        y: (json['y'] as num?)?.toDouble() ?? 0.0,
        a: (json['a'] as num?)?.toDouble() ?? 0.0,
        vx: (json['vx'] as num?)?.toDouble() ?? 0.0,
        vy: (json['vy'] as num?)?.toDouble() ?? 0.0,
        w: (json['w'] as num?)?.toDouble() ?? 0.0,
        fall: (json['fall'] as num?)?.toDouble() ?? 0.0,
      );
}

class SimShot {
  final double ang;
  final double power; // 0.0 to 1.0
  final double rx;
  final double ry;

  const SimShot({
    required this.ang,
    required this.power,
    this.rx = 0.0,
    this.ry = 0.0,
  });

  Map<String, dynamic> toJson() => {
        'ang': ang,
        'power': power,
        'rx': rx,
        'ry': ry,
      };

  factory SimShot.fromJson(Map<String, dynamic> json) => SimShot(
        ang: (json['ang'] as num?)?.toDouble() ?? 0.0,
        power: (json['power'] as num?)?.toDouble() ?? 0.5,
        rx: (json['rx'] as num?)?.toDouble() ?? 0.0,
        ry: (json['ry'] as num?)?.toDouble() ?? 0.0,
      );
}

class SimState {
  final List<SimPen> pens;
  bool ended;
  int winner; // -1 if active, 0 or 1

  SimState({
    required this.pens,
    this.ended = false,
    this.winner = -1,
  });

  SimState clone() => SimState(
        pens: [pens[0].clone(), pens[1].clone()],
        ended: ended,
        winner: winner,
      );

  Map<String, dynamic> toJson() => {
        'pens': pens.map((p) => p.toJson()).toList(),
        'ended': ended,
        'winner': winner,
      };

  factory SimState.fromJson(Map<String, dynamic> json) {
    final pensRaw = json['pens'] as List<dynamic>? ?? [];
    return SimState(
      pens: pensRaw.map((p) => SimPen.fromJson(p as Map<String, dynamic>)).toList(),
      ended: json['ended'] as bool? ?? false,
      winner: (json['winner'] as num?)?.toInt() ?? -1,
    );
  }
}

class SimHitEvent {
  final double t;
  final double x;
  final double y;
  final double impact;

  const SimHitEvent({
    required this.t,
    required this.x,
    required this.y,
    required this.impact,
  });

  factory SimHitEvent.fromJson(Map<String, dynamic> json) => SimHitEvent(
        t: (json['t'] as num?)?.toDouble() ?? 0.0,
        x: (json['x'] as num?)?.toDouble() ?? 0.0,
        y: (json['y'] as num?)?.toDouble() ?? 0.0,
        impact: (json['impact'] as num?)?.toDouble() ?? 0.0,
      );

  Map<String, dynamic> toJson() => {
        't': t,
        'x': x,
        'y': y,
        'impact': impact,
      };
}

class SimKeyframe {
  final double t;
  final double x0;
  final double y0;
  final double a0;
  final double fall0;
  final double x1;
  final double y1;
  final double a1;
  final double fall1;

  const SimKeyframe({
    required this.t,
    required this.x0,
    required this.y0,
    required this.a0,
    required this.fall0,
    required this.x1,
    required this.y1,
    required this.a1,
    required this.fall1,
  });

  factory SimKeyframe.fromList(List<dynamic> list) => SimKeyframe(
        t: (list[0] as num).toDouble(),
        x0: (list[1] as num).toDouble(),
        y0: (list[2] as num).toDouble(),
        a0: (list[3] as num).toDouble(),
        fall0: (list[4] as num).toDouble(),
        x1: (list[5] as num).toDouble(),
        y1: (list[6] as num).toDouble(),
        a1: (list[7] as num).toDouble(),
        fall1: (list[8] as num).toDouble(),
      );

  List<double> toList() => [t, x0, y0, a0, fall0, x1, y1, a1, fall1];
}

class SimTurnResult {
  final List<SimKeyframe> frames;
  final List<SimHitEvent> events;
  final int fell; // -1 none, 0 pen0 fell, 1 pen1 fell, 2 both fell
  final SimState finalState;
  final int winner;
  final double duration;

  const SimTurnResult({
    required this.frames,
    required this.events,
    required this.fell,
    required this.finalState,
    required this.winner,
    required this.duration,
  });
}

double edgeDist(SimPen p) => math.min(math.min(p.x, simW - p.x), math.min(p.y, simH - p.y));

double travelDist(double v) {
  if (v < 8.0) return 0.0;
  const k = visc;
  const c = coul;
  final q = (c / k) / (v + c / k);
  final t = math.log(1.0 / q) / k;
  return (v + c / k) / k * (1.0 - q) - c * t / k;
}

class SimSegResult {
  double x1 = 0.0;
  double y1 = 0.0;
  double x2 = 0.0;
  double y2 = 0.0;
}

final SimSegResult _sharedSeg = SimSegResult();

void segSeg(
  double p1x,
  double p1y,
  double q1x,
  double q1y,
  double p2x,
  double p2y,
  double q2x,
  double q2y,
  SimSegResult o,
) {
  final d1x = q1x - p1x, d1y = q1y - p1y;
  final d2x = q2x - p2x, d2y = q2y - p2y;
  final rx = p1x - p2x, ry = p1y - p2y;
  final a = d1x * d1x + d1y * d1y;
  final e = d2x * d2x + d2y * d2y;
  final f = d2x * rx + d2y * ry;
  double s, t;
  final c = d1x * rx + d1y * ry;
  final b = d1x * d2x + d1y * d2y;
  final denom = a * e - b * b;

  s = denom > 1e-9 ? clampVal((b * f - c * e) / denom, 0.0, 1.0) : 0.0;
  t = (b * s + f) / e;
  if (t < 0.0) {
    t = 0.0;
    s = clampVal(-c / a, 0.0, 1.0);
  } else if (t > 1.0) {
    t = 1.0;
    s = clampVal((b - c) / a, 0.0, 1.0);
  }
  o.x1 = p1x + d1x * s;
  o.y1 = p1y + d1y * s;
  o.x2 = p2x + d2x * t;
  o.y2 = p2y + d2y * t;
}

void collide(
  SimPen A,
  SimPen B, [
  void Function(double x, double y, double impact)? onHit,
]) {
  final rs = A.r + B.r;
  final cdx = B.x - A.x, cdy = B.y - A.y;
  final reach = A.h + B.h + rs;
  if (cdx * cdx + cdy * cdy > reach * reach) return;

  final ca = math.cos(A.a), sa = math.sin(A.a);
  final cb = math.cos(B.a), sb = math.sin(B.a);

  segSeg(
    A.x - ca * A.h,
    A.y - sa * A.h,
    A.x + ca * A.h,
    A.y + sa * A.h,
    B.x - cb * B.h,
    B.y - sb * B.h,
    B.x + cb * B.h,
    B.y + sb * B.h,
    _sharedSeg,
  );

  final dx = _sharedSeg.x2 - _sharedSeg.x1;
  final dy = _sharedSeg.y2 - _sharedSeg.y1;
  double d = math.sqrt(dx * dx + dy * dy);
  if (d >= rs) return;

  double nx, ny, cx, cy;
  if (d > 1e-6) {
    nx = dx / d;
    ny = dy / d;
    cx = _sharedSeg.x1 + nx * A.r;
    cy = _sharedSeg.y1 + ny * A.r;
  } else {
    nx = -sa;
    ny = ca;
    if (nx * cdx + ny * cdy < 0) {
      nx = -nx;
      ny = -ny;
    }
    cx = (_sharedSeg.x1 + _sharedSeg.x2) / 2.0;
    cy = (_sharedSeg.y1 + _sharedSeg.y2) / 2.0;
    d = 0.0;
  }

  final pen = rs - d;
  A.x -= nx * pen * 0.5;
  A.y -= ny * pen * 0.5;
  B.x += nx * pen * 0.5;
  B.y += ny * pen * 0.5;

  final rax = cx - A.x, ray = cy - A.y;
  final rbx = cx - B.x, rby = cy - B.y;

  final vax = A.vx - A.w * ray;
  final vay = A.vy + A.w * rax;
  final vbx = B.vx - B.w * rby;
  final vby = B.vy + B.w * rbx;

  final rvx = vbx - vax;
  final rvy = vby - vay;
  final vn = rvx * nx + rvy * ny;
  if (vn > 0.0) return;

  final invM = 1.0 / penM;
  final invI = 1.0 / penI;
  final raN = rax * ny - ray * nx;
  final rbN = rbx * ny - rby * nx;
  final kN = 2.0 * invM + raN * raN * invI + rbN * rbN * invI;
  final j = -(1.0 + rest) * vn / kN;

  A.vx -= j * nx * invM;
  A.vy -= j * ny * invM;
  A.w -= raN * j * invI;
  B.vx += j * nx * invM;
  B.vy += j * ny * invM;
  B.w += rbN * j * invI;

  // Tangential friction
  final vax2 = A.vx - A.w * ray;
  final vay2 = A.vy + A.w * rax;
  final vbx2 = B.vx - B.w * rby;
  final vby2 = B.vy + B.w * rbx;
  final rvx2 = vbx2 - vax2;
  final rvy2 = vby2 - vay2;

  final tx = -ny, ty = nx;
  final vt = rvx2 * tx + rvy2 * ty;
  final raT = rax * ty - ray * tx;
  final rbT = rbx * ty - rby * tx;
  final kT = 2.0 * invM + raT * raT * invI + rbT * rbT * invI;
  double jt = -vt / kT;
  final lim = mu * j;
  jt = clampVal(jt, -lim, lim);

  A.vx -= jt * tx * invM;
  A.vy -= jt * ty * invM;
  A.w -= raT * jt * invI;
  B.vx += jt * tx * invM;
  B.vy += jt * ty * invM;
  B.w += rbT * jt * invI;

  onHit?.call(cx, cy, -vn);
}

void applyShot(SimPen p, SimShot shot) {
  final v = shot.power * maxV;
  final dx = math.cos(shot.ang);
  final dy = math.sin(shot.ang);
  p.vx += dx * v;
  p.vy += dy * v;
  if (shot.rx != 0.0 || shot.ry != 0.0) {
    p.w += (shot.rx * dy * v - shot.ry * dx * v) / (penI / penM) * spinK;
  }
}

void stepPhysics(
  SimState S,
  double dt, [
  void Function(double x, double y, double impact)? onHit,
]) {
  final pens = S.pens;
  for (int i = 0; i < 2; i++) {
    final p = pens[i];
    p.x += p.vx * dt;
    p.y += p.vy * dt;
    p.a += p.w * dt;

    if (p.fall > 0.0) {
      p.fall += dt * 1.6;
      final k = math.exp(-0.6 * dt);
      p.vx *= k;
      p.vy *= k;
      continue;
    }

    final sp = math.sqrt(p.vx * p.vx + p.vy * p.vy);
    if (sp > 0.0) {
      final ns = math.max(0.0, sp * math.exp(-visc * dt) - coul * dt);
      if (ns < 6.0) {
        p.vx = 0.0;
        p.vy = 0.0;
      } else {
        final k = ns / sp;
        p.vx *= k;
        p.vy *= k;
      }
    }

    if (p.w != 0.0) {
      double nw = math.max(0.0, p.w.abs() * math.exp(-aVisc * dt) - aCoul * dt);
      if (nw < 0.08) nw = 0.0;
      p.w = p.w.sign * nw;
    }
  }

  if (pens[0].fall == 0.0 && pens[1].fall == 0.0) {
    collide(pens[0], pens[1], onHit);
  }

  for (int i = 0; i < 2; i++) {
    final p = pens[i];
    if (p.fall == 0.0 && (p.x < 0.0 || p.x > simW || p.y < 0.0 || p.y > simH)) {
      p.fall = 0.0001;
      if (p.x < 0.0) p.vx = math.min(p.vx, -110.0);
      if (p.x > simW) p.vx = math.max(p.vx, 110.0);
      if (p.y < 0.0) p.vy = math.min(p.vy, -110.0);
      if (p.y > simH) p.vy = math.max(p.vy, 110.0);
    }
  }
}

bool settled(SimState S) => S.pens.every((p) => p.fall > 0.0 || (p.vx == 0.0 && p.vy == 0.0 && p.w == 0.0));

SimState createInitialMatchState([double? fixedY, double? fixedA]) {
  final y = fixedY ?? (simH / 2.0 + (math.Random().nextDouble() - 0.5) * 180.0);
  final a = fixedA ?? ((math.Random().nextDouble() - 0.5) * 1.10);
  return SimState(
    pens: [
      SimPen(owner: 0, x: simW * 0.22, y: y, a: a),
      SimPen(owner: 1, x: simW - simW * 0.22, y: simH - y, a: a + math.pi),
    ],
    ended: false,
    winner: -1,
  );
}

SimTurnResult simulateTurn(
  SimState initialState,
  int activeSide,
  SimShot shot, [
  double maxSimSeconds = 6.0,
]) {
  final sim = initialState.clone();
  applyShot(sim.pens[activeSide], shot);

  final frames = <SimKeyframe>[];
  final events = <SimHitEvent>[];
  const sampleInterval = 1.0 / 60.0;
  double nextSampleTime = 0.0;
  double elapsed = 0.0;

  frames.add(SimKeyframe(
    t: 0.0,
    x0: sim.pens[0].x,
    y0: sim.pens[0].y,
    a0: sim.pens[0].a,
    fall0: sim.pens[0].fall,
    x1: sim.pens[1].x,
    y1: sim.pens[1].y,
    a1: sim.pens[1].a,
    fall1: sim.pens[1].fall,
  ));

  while (elapsed < maxSimSeconds) {
    stepPhysics(sim, simStep, (x, y, impact) {
      if (impact > 25.0) {
        events.add(SimHitEvent(
          t: elapsed,
          x: x,
          y: y,
          impact: impact,
        ));
      }
    });

    elapsed += simStep;

    if (elapsed >= nextSampleTime) {
      frames.add(SimKeyframe(
        t: elapsed,
        x0: sim.pens[0].x,
        y0: sim.pens[0].y,
        a0: sim.pens[0].a,
        fall0: sim.pens[0].fall,
        x1: sim.pens[1].x,
        y1: sim.pens[1].y,
        a1: sim.pens[1].a,
        fall1: sim.pens[1].fall,
      ));
      nextSampleTime += sampleInterval;
    }

    if (sim.pens[0].fall > 0.0 || sim.pens[1].fall > 0.0) {
      if (sim.pens[0].fall > 0.8 || sim.pens[1].fall > 0.8) break;
    } else if (settled(sim) && elapsed > 0.25) {
      break;
    }
  }

  frames.add(SimKeyframe(
    t: elapsed,
    x0: sim.pens[0].x,
    y0: sim.pens[0].y,
    a0: sim.pens[0].a,
    fall0: sim.pens[0].fall,
    x1: sim.pens[1].x,
    y1: sim.pens[1].y,
    a1: sim.pens[1].a,
    fall1: sim.pens[1].fall,
  ));

  final f0 = sim.pens[0].fall > 0.0;
  final f1 = sim.pens[1].fall > 0.0;
  int fell = -1;
  int winner = -1;

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

  return SimTurnResult(
    frames: frames,
    events: events,
    fell: fell,
    finalState: sim,
    winner: winner,
    duration: elapsed,
  );
}

// Keyframe playback interpolator
class KeyframeInterpolator {
  final List<SimKeyframe> frames;

  const KeyframeInterpolator(this.frames);

  bool get isEmpty => frames.isEmpty;
  double get totalDuration => frames.isEmpty ? 0.0 : frames.last.t;

  void sample(double t, SimPen pen0, SimPen pen1) {
    if (frames.isEmpty) return;
    if (t <= frames.first.t) {
      _applyFrame(frames.first, pen0, pen1);
      return;
    }
    if (t >= frames.last.t) {
      _applyFrame(frames.last, pen0, pen1);
      return;
    }

    // Binary search for interval
    int low = 0;
    int high = frames.length - 1;
    while (low <= high) {
      final mid = (low + high) ~/ 2;
      if (frames[mid].t <= t) {
        if (mid == frames.length - 1 || frames[mid + 1].t > t) {
          final fA = frames[mid];
          final fB = frames[mid + 1];
          final span = fB.t - fA.t;
          final alpha = span > 1e-6 ? (t - fA.t) / span : 0.0;

          pen0.x = fA.x0 + (fB.x0 - fA.x0) * alpha;
          pen0.y = fA.y0 + (fB.y0 - fA.y0) * alpha;
          pen0.a = _lerpAngle(fA.a0, fB.a0, alpha);
          pen0.fall = fA.fall0 + (fB.fall0 - fA.fall0) * alpha;

          pen1.x = fA.x1 + (fB.x1 - fA.x1) * alpha;
          pen1.y = fA.y1 + (fB.y1 - fA.y1) * alpha;
          pen1.a = _lerpAngle(fA.a1, fB.a1, alpha);
          pen1.fall = fA.fall1 + (fB.fall1 - fA.fall1) * alpha;
          return;
        }
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
  }

  void _applyFrame(SimKeyframe f, SimPen pen0, SimPen pen1) {
    pen0.x = f.x0;
    pen0.y = f.y0;
    pen0.a = f.a0;
    pen0.fall = f.fall0;

    pen1.x = f.x1;
    pen1.y = f.y1;
    pen1.a = f.a1;
    pen1.fall = f.fall1;
  }

  double _lerpAngle(double a, double b, double t) {
    double diff = (b - a) % tau;
    if (diff > math.pi) diff -= tau;
    if (diff < -math.pi) diff += tau;
    return a + diff * t;
  }
}
