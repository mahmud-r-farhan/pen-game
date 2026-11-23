// lib/game/shot_predictor.dart
import 'dart:math' as math;

/// Pure aiming math shared by the HUD and unit tests.
///
/// Forge2D applies exponential linear damping, so the analytic stopping
/// distance of a struck pen is `initialSpeed / linearDamping`. This is far more
/// accurate than scaling the raw drag length and keeps the trajectory preview
/// honest across every pen and arena surface.
class ShotPredictor {
  const ShotPredictor._();

  /// Matches the server-side `FLICK_SUBMIT` magnitude limit.
  static const double maxImpulse = 44.0;

  /// Matches `KolomGameEngine.onDragEnd`.
  static const double pullToImpulse = 7.4;

  static const double minPull = 0.4;

  static double impulseForPull(double pullLength) {
    if (!pullLength.isFinite || pullLength <= minPull) return 0;
    return math.min(pullLength * pullToImpulse, maxImpulse);
  }

  static double powerForImpulse(double impulse) {
    if (!impulse.isFinite || impulse <= 0) return 0;
    return (impulse / maxImpulse).clamp(0.0, 1.0);
  }

  /// Analytic travel distance under exponential surface damping.
  static double travelDistance({
    required double impulse,
    required double mass,
    required double linearDamping,
  }) {
    if (!impulse.isFinite || !mass.isFinite || !linearDamping.isFinite)
      return 0;
    if (impulse <= 0 || mass <= 0 || linearDamping <= 0) return 0;
    return (impulse / mass) / linearDamping;
  }

  /// Normalized spin contribution from the strike point, -1..1.
  static double spinForOffset(double strikeOffset) {
    return (strikeOffset / 0.85).clamp(-1.0, 1.0);
  }

  /// Distance from an inside point to the bench boundary along [dirX, dirY].
  /// Returns [maxDistance] when the ray never exits (should not happen for an
  /// inside point), and 0 when the start point is already outside.
  static double distanceToEdge({
    required double startX,
    required double startY,
    required double dirX,
    required double dirY,
    required double left,
    required double top,
    required double right,
    required double bottom,
    double maxDistance = double.infinity,
  }) {
    if (startX < left || startX > right || startY < top || startY > bottom) {
      return 0;
    }

    double tMin = 0;
    double tMax = maxDistance;

    void clipAxis(double start, double direction, double min, double max) {
      if (direction.abs() < 1e-9) {
        if (start < min || start > max) tMin = double.infinity;
        return;
      }
      double t1 = (min - start) / direction;
      double t2 = (max - start) / direction;
      if (t1 > t2) {
        final swap = t1;
        t1 = t2;
        t2 = swap;
      }
      if (t1 > tMin) tMin = t1;
      if (t2 < tMax) tMax = t2;
    }

    clipAxis(startX, dirX, left, right);
    clipAxis(startY, dirY, top, bottom);
    if (tMin > tMax || tMax == double.infinity) return maxDistance;
    // `tMin` is the ray's *entry* parameter and `tMax` its exit parameter. The
    // start point is inside the bench, so entry is behind us (clamped to 0) and
    // `tMax` is the distance actually travelled before the pen leaves the table.
    return tMax.clamp(0.0, maxDistance);
  }
}
