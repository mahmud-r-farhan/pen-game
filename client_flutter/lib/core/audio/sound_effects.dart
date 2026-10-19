// lib/core/audio/sound_effects.dart
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoundEffects {
  static final SoundEffects _instance = SoundEffects._internal();
  factory SoundEffects() => _instance;
  SoundEffects._internal();

  final AudioPlayer _player = AudioPlayer();
  final AudioPlayer _hitPlayer = AudioPlayer();
  bool soundEnabled = true;
  bool vibrationEnabled = true;

  static const String keyPrefSound = 'pref_sound_enabled';
  static const String keyPrefVibration = 'pref_vibration_enabled';

  Future<void> init() async {
    try {
      await _player.setReleaseMode(ReleaseMode.stop);
      await _hitPlayer.setReleaseMode(ReleaseMode.stop);
      final prefs = await SharedPreferences.getInstance();
      soundEnabled = prefs.getBool(keyPrefSound) ?? true;
      vibrationEnabled = prefs.getBool(keyPrefVibration) ?? true;
    } catch (e) {
      debugPrint('Audio initialization note: $e');
    }
  }

  Future<void> toggleSound(bool enabled) async {
    soundEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyPrefSound, enabled);
  }

  Future<void> toggleVibration(bool enabled) async {
    vibrationEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyPrefVibration, enabled);
    if (enabled) {
      HapticFeedback.mediumImpact();
    }
  }

  void playFlick([double power = 0.5]) {
    if (vibrationEnabled) {
      if (power > 0.7) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.lightImpact();
      }
    }
    if (!soundEnabled) return;
    _playSafe('flick', volume: (0.5 + power * 0.5).clamp(0.2, 1.0));
  }

  void playCollision({bool isMetal = false, double intensity = 1.0}) {
    if (vibrationEnabled) {
      if (intensity > 0.8) {
        HapticFeedback.heavyImpact();
      } else if (intensity > 0.4) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.selectionClick();
      }
    }
    if (!soundEnabled) return;

    final volume = (0.35 + intensity * 0.65).clamp(0.2, 1.0);
    _playHitSafe(isMetal ? 'clack_metal' : 'clack_plastic', volume: volume);
  }

  void playTimerWarning() {
    if (vibrationEnabled) {
      HapticFeedback.selectionClick();
    }
    if (!soundEnabled) return;
    SystemSound.play(SystemSoundType.alert);
  }

  void playFallOff() {
    if (vibrationEnabled) {
      HapticFeedback.heavyImpact();
    }
    if (!soundEnabled) return;
    _playSafe('fall_off', volume: 1.0);
  }

  void playVictory() {
    if (vibrationEnabled) {
      HapticFeedback.vibrate();
    }
    if (!soundEnabled) return;
    _playSafe('victory', volume: 0.95);
  }

  void playRibbonFanfare() {
    if (vibrationEnabled) {
      HapticFeedback.vibrate();
    }
    if (!soundEnabled) return;
    _playSafe('ribbon_fanfare', volume: 1.0);
  }

  void playDefeatMotivation() {
    if (vibrationEnabled) {
      HapticFeedback.selectionClick();
    }
    if (!soundEnabled) return;
    _playSafe('defeat_motivation', volume: 0.85);
  }

  void playCoin() {
    if (vibrationEnabled) {
      HapticFeedback.selectionClick();
    }
    if (!soundEnabled) return;
    _playSafe('coin', volume: 0.8);
  }

  void playPenSelect() {
    if (vibrationEnabled) {
      HapticFeedback.selectionClick();
    }
    if (!soundEnabled) return;
    _playSafe('flick', volume: 0.5);
  }

  void playSchoolBell() {
    if (vibrationEnabled) {
      HapticFeedback.mediumImpact();
    }
    if (!soundEnabled) return;
    _playSafe('ribbon_fanfare', volume: 0.7);
  }

  void _playSafe(String soundName, {double volume = 1.0}) async {
    try {
      await _player.setVolume(volume);
      await _player.play(AssetSource('audio/$soundName.wav'));
    } catch (_) {
      SystemSound.play(SystemSoundType.click);
    }
  }

  void _playHitSafe(String soundName, {double volume = 1.0}) async {
    try {
      await _hitPlayer.setVolume(volume);
      await _hitPlayer.play(AssetSource('audio/$soundName.wav'));
    } catch (_) {
      SystemSound.play(SystemSoundType.click);
    }
  }
}
