// lib/models/kolom_spec.dart
import 'package:flutter/material.dart';

enum KolomModel {
  hiSchoolClassic, // Matador Hi-School vibe
  econoStriker,    // Econo DX vibe (transparent yellow)
  oceanGelPro,     // Linc Ocean Gel vibe (rubber grip)
  hectorMetalTank, // Metallic charcoal & gold executive pen
  doubleCapMod,    // Classroom legendary modified pen (dual caps + weight)
  goldParkerVIP,   // Golden luxury Parker vibe
  neonSpinner,     // High-tech futuristic glow pen
}

class KolomSpec {
  final KolomModel model;
  final String id;
  final String name;
  final String nameBn;
  final String tagLineEn;
  final String tagLineBn;
  final double length;         // meters in physics world (slender & longer)
  final double radius;         // half-thickness (sleek ballpoint profile)
  final double density;        // mass density
  final double linearDamping;  // sliding friction
  final double angularDamping; // spin resistance
  final double restitution;    // bounciness
  final double comOffsetX;     // center-of-mass shift toward cap
  final Color barrelColor;
  final Color capColor;
  final Color gripColor;
  final Color accentColor;
  final bool isTransparent;
  final bool hasRubberGrip;
  final bool isDoubleCapped;
  final int unlockPrice;
  final int minLevel;

  const KolomSpec({
    required this.model,
    required this.id,
    required this.name,
    required this.nameBn,
    required this.tagLineEn,
    required this.tagLineBn,
    required this.length,
    required this.radius,
    required this.density,
    required this.linearDamping,
    required this.angularDamping,
    required this.restitution,
    required this.comOffsetX,
    required this.barrelColor,
    required this.capColor,
    required this.gripColor,
    required this.accentColor,
    this.isTransparent = false,
    this.hasRubberGrip = false,
    this.isDoubleCapped = false,
    this.unlockPrice = 0,
    this.minLevel = 1,
  });

  String get nameEn => name;
  int get massRating => ((density / 2.8) * 100).clamp(10, 100).toInt();
  int get gripRating => ((angularDamping / 4.0) * 100).clamp(10, 100).toInt();
  int get speedRating => (((4.0 - linearDamping) / 2.5) * 100).clamp(10, 100).toInt();
  int get whipSpinRating => ((comOffsetX.abs() / 0.55) * 100).clamp(20, 100).toInt();

  static const Map<KolomModel, KolomSpec> catalog = {
    KolomModel.hiSchoolClassic: KolomSpec(
      model: KolomModel.hiSchoolClassic,
      id: 'hiSchoolClassic',
      name: 'Hi-Bench Classic',
      nameBn: 'হাই-বেঞ্চ ক্লাসিক',
      tagLineEn: 'Lightweight slender body, ultra-long-range rocket speed!',
      tagLineBn: 'হালকা বডি, দূরপাল্লার রকেট স্পিড!',
      length: 5.3,
      radius: 0.16,
      density: 0.85,
      linearDamping: 2.2,
      angularDamping: 1.6,
      restitution: 0.65,
      comOffsetX: -0.42,
      barrelColor: Color(0xFFF5F7FA),
      capColor: Color(0xFF1565C0),
      gripColor: Color(0xFF1565C0),
      accentColor: Color(0xFF42A5F5),
      unlockPrice: 0,
      minLevel: 1,
    ),
    KolomModel.econoStriker: KolomSpec(
      model: KolomModel.econoStriker,
      id: 'econoStriker',
      name: 'Econo DX Striker',
      nameBn: 'ইকোনো ডিএক্স স্ট্রাইকার',
      tagLineEn: 'Translucent yellow tube, classic red cap pinpoint accuracy!',
      tagLineBn: 'স্বচ্ছ বডি, ক্লাসিক লাল ক্যাপের নির্ভুল নিশানা!',
      length: 5.4,
      radius: 0.165,
      density: 0.95,
      linearDamping: 2.4,
      angularDamping: 1.8,
      restitution: 0.60,
      comOffsetX: -0.38,
      barrelColor: Color(0x99FFF59D),
      capColor: Color(0xFFD32F2F),
      gripColor: Color(0xFFD32F2F),
      accentColor: Color(0xFFFF5252),
      isTransparent: true,
      unlockPrice: 200,
      minLevel: 1,
    ),
    KolomModel.oceanGelPro: KolomSpec(
      model: KolomModel.oceanGelPro,
      id: 'oceanGelPro',
      name: 'Ocean Gel Grip',
      nameBn: 'ওশান জেল গ্রিপ',
      tagLineEn: 'Ribbed rubber grip with quick-stop friction at bench edges!',
      tagLineBn: 'রাবার গ্রিপ দিয়ে তৈরি, টেবিলের কিনারায় চটজলদি থামে!',
      length: 5.3,
      radius: 0.18,
      density: 1.35,
      linearDamping: 3.0,
      angularDamping: 2.8,
      restitution: 0.50,
      comOffsetX: -0.40,
      barrelColor: Color(0xAA4FC3F7),
      capColor: Color(0xFF0277BD),
      gripColor: Color(0xFF01579B),
      accentColor: Color(0xFF00E5FF),
      isTransparent: true,
      hasRubberGrip: true,
      unlockPrice: 500,
      minLevel: 2,
    ),
    KolomModel.hectorMetalTank: KolomSpec(
      model: KolomModel.hectorMetalTank,
      id: 'hectorMetalTank',
      name: 'Hector Metal Tank',
      nameBn: 'হেক্টর মেটাল ট্যাংক',
      tagLineEn: 'Heavy metallic executive body, knock opponent pens off in one blow!',
      tagLineBn: 'ভারী ধাতব শরীর, প্রতিপক্ষের কলম এক ধাক্কায় মেঝেতে!',
      length: 5.5,
      radius: 0.19,
      density: 2.10,
      linearDamping: 3.4,
      angularDamping: 3.2,
      restitution: 0.72,
      comOffsetX: -0.48,
      barrelColor: Color(0xFF37474F),
      capColor: Color(0xFF263238),
      gripColor: Color(0xFFFFB300),
      accentColor: Color(0xFFFFD54F),
      unlockPrice: 1200,
      minLevel: 3,
    ),
    KolomModel.doubleCapMod: KolomSpec(
      model: KolomModel.doubleCapMod,
      id: 'doubleCapMod',
      name: 'Double-Cap Boss',
      nameBn: 'ডাবল ক্যাপ বস',
      tagLineEn: 'Modified with dual caps for crazy helicopter whip-spin strikes!',
      tagLineBn: 'উভয় মাথায় ক্যাপ লাগানো, পাগলাটে স্পিন আর ব্যালেন্স!',
      length: 5.6,
      radius: 0.18,
      density: 1.65,
      linearDamping: 2.6,
      angularDamping: 2.4,
      restitution: 0.68,
      comOffsetX: -0.15,
      barrelColor: Color(0xFF2E7D32),
      capColor: Color(0xFF1B5E20),
      gripColor: Color(0xFF81C784),
      accentColor: Color(0xFF69F0AE),
      isDoubleCapped: true,
      unlockPrice: 2000,
      minLevel: 4,
    ),
    KolomModel.goldParkerVIP: KolomSpec(
      model: KolomModel.goldParkerVIP,
      id: 'goldParkerVIP',
      name: 'Royal Gold Parker',
      nameBn: 'রয়েল গোল্ড পার্কার',
      tagLineEn: '24K gold finish with diamond-cut nib for high-roller champions!',
      tagLineBn: '২৪ ক্যারেট গোল্ডেন ফিনিশ, অভিজাত টুর্নামেন্টের মুকুট!',
      length: 5.5,
      radius: 0.185,
      density: 1.95,
      linearDamping: 2.8,
      angularDamping: 2.6,
      restitution: 0.65,
      comOffsetX: -0.45,
      barrelColor: Color(0xFFFFD700),
      capColor: Color(0xFFDAA520),
      gripColor: Color(0xFFB8860B),
      accentColor: Color(0xFFFFF8DC),
      unlockPrice: 4000,
      minLevel: 5,
    ),
    KolomModel.neonSpinner: KolomSpec(
      model: KolomModel.neonSpinner,
      id: 'neonSpinner',
      name: 'Cyberpunk Neon Spinner',
      nameBn: 'সাইবারপাঙ্ক নিয়ন স্পিনার',
      tagLineEn: 'Futuristic glowing light emitter with zero-friction drift!',
      tagLineBn: 'ভবিষ্যতের সাইবার লাইট, চোখ ধাঁধানো স্পিড আর গ্লো!',
      length: 5.4,
      radius: 0.175,
      density: 1.40,
      linearDamping: 2.0,
      angularDamping: 1.5,
      restitution: 0.75,
      comOffsetX: -0.50,
      barrelColor: Color(0xFF00E5FF),
      capColor: Color(0xFFD500F9),
      gripColor: Color(0xFF651FFF),
      accentColor: Color(0xFF00E5FF),
      unlockPrice: 6500,
      minLevel: 6,
    ),
  };

  static KolomSpec getById(String id) {
    return catalog.values.firstWhere(
      (element) => element.id == id,
      orElse: () => catalog[KolomModel.hiSchoolClassic]!,
    );
  }
}
