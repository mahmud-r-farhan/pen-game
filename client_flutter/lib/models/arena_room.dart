// lib/models/arena_room.dart
import 'package:flutter/material.dart';

enum ArenaCategory { school, college, university }

enum TableTextureType {
  woodScratched,
  varnishedTeak,
  draftingGreen,
  stainlessSteel,
  examMahogany,
  militaryCherry,
  executiveGlass,
}

class ArenaRoom {
  final String id;
  final String name;
  final String nameBn;
  final ArenaCategory category;
  final String? subCategory;
  final int entryCoins;
  final int potCoins;
  final int payoutCoins;
  final String description;
  final String descriptionBn;
  final Color tableColorStart;
  final Color tableColorEnd;
  final Color borderColor;
  final TableTextureType textureType;
  final double friction; // linear damping
  final double angularDamping; // spin damping
  final double bounce; // restitution

  final Color neonGlowColor;
  final String assetPath;

  const ArenaRoom({
    required this.id,
    required this.name,
    required this.nameBn,
    required this.category,
    this.subCategory,
    required this.entryCoins,
    required this.potCoins,
    required this.payoutCoins,
    required this.description,
    required this.descriptionBn,
    required this.tableColorStart,
    required this.tableColorEnd,
    required this.borderColor,
    required this.textureType,
    required this.friction,
    required this.angularDamping,
    required this.bounce,
    required this.neonGlowColor,
    required this.assetPath,
  });

  String get nameEn => name;
  String get descriptionEn => description;

  String localizedName(String langCode) {
    if (langCode == 'bn') return nameBn;
    if (langCode == 'hi') {
      switch (id) {
        case 'primary_school':
          return 'प्राथमिक विद्यालय बेंच';
        case 'high_school':
          return 'हाई स्कूल डेस्क';
        case 'polytechnic':
          return 'पॉलिटेक्निक ड्राफ्टिंग टेबल';
        case 'medical_college':
          return 'मेडिकल कॉलेज लैब टेबल';
        case 'national_university':
          return 'राष्ट्रीय विश्वविद्यालय बेंच';
        case 'coaching_center':
          return 'कोचिंग सेंटर डेस्क';
        case 'cadet_college':
          return 'कैडेट कॉलेज मेस टेबल';
        case 'public_university':
          return 'पब्लिक यूनिवर्सिटी हॉल';
      }
    }
    return name;
  }

  String localizedDescription(String langCode) {
    if (langCode == 'bn') return descriptionBn;
    if (langCode == 'hi') {
      switch (id) {
        case 'primary_school':
          return 'चॉक के निशान और रूलर से तराशी क्लासरूम की लकड़ी की बेंच।';
        case 'high_school':
          return 'सागौन की लकड़ी की क्लासिक चमकदार डेस्क, कम्पास के निशान के साथ।';
        case 'polytechnic':
          return 'इंजीनियरिंग ड्राफ्टिंग टेबल, टी-स्केल और सटीक ग्रिड।';
        case 'medical_college':
          return 'ठंडी स्टेनलेस स्टील प्रयोगशाला बेंच। सुपर स्पीड और स्लाइड!';
        case 'national_university':
          return 'परीक्षा हॉल की क्लासिक भारी बेंच, रोल नंबर के निशान के साथ।';
        case 'coaching_center':
          return 'कोचिंग सेंटर की लैमिनेट डेस्क, एडमिशन टेस्ट के निशान और एनर्जी ड्रिंक के गोले।';
        case 'cadet_college':
          return 'अभिजात गहरे चेरी की लकड़ी की अनुशासित मेस टेबल। हाई स्टेक्स!';
        case 'public_university':
          return 'टेम्पर्ड ग्लास एक्जीक्यूटिव टेबल। बर्फ जैसा फिसलन भरा सरफेस!';
      }
    }
    return description;
  }

  String localizedFriction(String langCode) {
    if (friction < 1.8) {
      if (langCode == 'bn') return 'সুপার ফাস্ট ড্রিফট (পিচ্ছিল)';
      if (langCode == 'hi') return 'अति तीव्र स्लाइड (कम घर्षण)';
      return 'Low Friction (Speed Drift)';
    } else if (friction > 2.3) {
      if (langCode == 'bn') return 'হাই গ্রিপ কন্ট্রোল';
      if (langCode == 'hi') return 'उच्च पकड़ नियंत्रण';
      return 'High Grip (Precision)';
    } else {
      if (langCode == 'bn') return 'ব্যালেন্সড গ্রিপ';
      if (langCode == 'hi') return 'संतुलित पकड़';
      return 'Balanced Table Physics';
    }
  }

  static const List<ArenaRoom> rooms = [
    ArenaRoom(
      id: 'primary_school',
      name: 'Primary School',
      nameBn: 'প্রাথমিক বিদ্যালয় বেঞ্চ',
      category: ArenaCategory.school,
      entryCoins: 50,
      potCoins: 100,
      payoutCoins: 95,
      description:
          'Weathered tin-shed school bench with chalk scratches and pencil carvings.',
      descriptionBn:
          'টিনের চালা ক্লাসরুমের কাঠের বেঞ্চ, চকের দাগ আর কম স্টেক্স।',
      tableColorStart: Color(0xFF8D5524),
      tableColorEnd: Color(0xFF583111),
      borderColor: Color(0xFF00FF7F),
      textureType: TableTextureType.woodScratched,
      friction: 2.6,
      angularDamping: 2.2,
      bounce: 0.60,
      neonGlowColor: Color(0xFF00FF7F),
      assetPath: 'assets/arenas/room_primary.webp',
    ),
    ArenaRoom(
      id: 'high_school',
      name: 'High School',
      nameBn: 'উচ্চ বিদ্যালয় ডেস্ক',
      category: ArenaCategory.school,
      entryCoins: 200,
      potCoins: 400,
      payoutCoins: 380,
      description:
          'Classic red-brick school desk with compass markings and varnished teak.',
      descriptionBn:
          'লাল ইটের স্কুল ঘর, সেগুন কাঠের চকচকে টেবিল ও কম্পাসের দাগ।',
      tableColorStart: Color(0xFFA0522D),
      tableColorEnd: Color(0xFF5C290E),
      borderColor: Color(0xFF00E5FF),
      textureType: TableTextureType.varnishedTeak,
      friction: 2.4,
      angularDamping: 2.0,
      bounce: 0.62,
      neonGlowColor: Color(0xFF00E5FF),
      assetPath: 'assets/arenas/room_highschool.webp',
    ),
    ArenaRoom(
      id: 'polytechnic',
      name: 'Polytechnic Institute',
      nameBn: 'পলিটেকনিক ড্রাফটিং টেবিল',
      category: ArenaCategory.college,
      subCategory: 'Engineering & Tech',
      entryCoins: 500,
      potCoins: 1000,
      payoutCoins: 950,
      description:
          'Precision engineering drafting table with T-square grid markings.',
      descriptionBn:
          'সবুজ ম্যাট ড্রাফটিং টেবিল, টি-স্কেল আর গ্রিড লাইনের মসৃণ সারফেস।',
      tableColorStart: Color(0xFF1B4D3E),
      tableColorEnd: Color(0xFF0F281E),
      borderColor: Color(0xFF00E676),
      textureType: TableTextureType.draftingGreen,
      friction: 2.1,
      angularDamping: 1.8,
      bounce: 0.55,
      neonGlowColor: Color(0xFF00E676),
      assetPath: 'assets/arenas/room_polytechnic.webp',
    ),
    ArenaRoom(
      id: 'medical_college',
      name: 'Medical College',
      nameBn: 'মেডিকেল কলেজ ডিসেকশন ল্যাব',
      category: ArenaCategory.college,
      subCategory: 'Medical (DMC / SSMC)',
      entryCoins: 1000,
      potCoins: 2000,
      payoutCoins: 1900,
      description:
          'Cold polished stainless steel laboratory bench. Extreme slide speeds!',
      descriptionBn:
          'ঠান্ডা চকচকে স্টিলের ল্যাব টেবিল। কম ঘর্ষণ, প্রচণ্ড গতি আর তীক্ষ্ণ বাউন্স!',
      tableColorStart: Color(0xFF607D8B),
      tableColorEnd: Color(0xFF263238),
      borderColor: Color(0xFF40C4FF),
      textureType: TableTextureType.stainlessSteel,
      friction: 1.7,
      angularDamping: 1.4,
      bounce: 0.70,
      neonGlowColor: Color(0xFF40C4FF),
      assetPath: 'assets/arenas/room_medical.webp',
    ),
    ArenaRoom(
      id: 'national_university',
      name: 'College Adda & Canteen',
      nameBn: 'কলেজ ক্যান্টিন আড্ডা',
      category: ArenaCategory.college,
      subCategory: 'Degree & Honours',
      entryCoins: 2500,
      potCoins: 5000,
      payoutCoins: 4750,
      description:
          'College canteen table with hot milk tea, fresh samosas, and pen skirmishes.',
      descriptionBn:
          'গরম দুধ চা ও সিঙ্গাড়ার ক্যান্টিন টেবিল। জমজমাট আড্ডা ও রোমাঞ্চকর কলম লড়াই!',
      tableColorStart: Color(0xFF795548),
      tableColorEnd: Color(0xFF3E2723),
      borderColor: Color(0xFFE040FB),
      textureType: TableTextureType.examMahogany,
      friction: 2.3,
      angularDamping: 1.9,
      bounce: 0.58,
      neonGlowColor: Color(0xFFE040FB),
      assetPath: 'assets/arenas/room_college.webp',
    ),
    ArenaRoom(
      id: 'coaching_center',
      name: 'Coaching Center',
      nameBn: 'কোচিং সেন্টারের ডেস্ক',
      category: ArenaCategory.college,
      subCategory: 'Admission & Test Prep',
      entryCoins: 1500,
      potCoins: 3000,
      payoutCoins: 2850,
      description:
          'Laminate coaching-center desk with admission-test scribbles and energy-drink rings.',
      descriptionBn:
          'ল্যামিনেট কোচিং সেন্টারের ডেস্ক, ভর্তি পরীক্ষার লেখা আর এনার্জি ড্রিংকের দাগ।',
      tableColorStart: Color(0xFF37474F),
      tableColorEnd: Color(0xFF1A237E),
      borderColor: Color(0xFF7C4DFF),
      textureType: TableTextureType.draftingGreen,
      friction: 1.8,
      angularDamping: 1.6,
      bounce: 0.66,
      neonGlowColor: Color(0xFF7C4DFF),
      assetPath: 'assets/arenas/room_college.webp',
    ),
    ArenaRoom(
      id: 'cadet_college',
      name: 'Cadet College Mess',
      nameBn: 'ক্যাডেট কলেজ অফিসার্স মেস',
      category: ArenaCategory.college,
      subCategory: 'Cadet / Military',
      entryCoins: 5000,
      potCoins: 10000,
      payoutCoins: 9500,
      description:
          'Heavy dark cherrywood desk with polished brass corners and elite stakes.',
      descriptionBn:
          'অভিজাত ডার্ক চেরি কাঠ ও পিতলের কোনাওয়ালা সুশৃঙ্খল টেবিল। হাই স্টেক্স!',
      tableColorStart: Color(0xFF4A0E17),
      tableColorEnd: Color(0xFF23060B),
      borderColor: Color(0xFFFFB300),
      textureType: TableTextureType.militaryCherry,
      friction: 1.9,
      angularDamping: 1.6,
      bounce: 0.65,
      neonGlowColor: Color(0xFFFFB300),
      assetPath: 'assets/arenas/room_highschool.webp',
    ),
    ArenaRoom(
      id: 'public_university',
      name: 'Public University (DU / BUET)',
      nameBn: 'পাবলিক বিশ্ববিদ্যালয় সেমিনার',
      category: ArenaCategory.university,
      subCategory: 'DU, BUET, RUET, CUET',
      entryCoins: 10000,
      potCoins: 20000,
      payoutCoins: 19000,
      description:
          'Grand golden dome academy with slippery glass tables. Master esports level!',
      descriptionBn:
          'সোনালী গম্বুজ আর স্তম্ভওয়ালা একাডেমি। কাঁচের মতো পিচ্ছিল টেবিল!',
      tableColorStart: Color(0xFF102027),
      tableColorEnd: Color(0xFF000A12),
      borderColor: Color(0xFFFF9100),
      textureType: TableTextureType.executiveGlass,
      friction: 1.3,
      angularDamping: 1.1,
      bounce: 0.75,
      neonGlowColor: Color(0xFFFF9100),
      assetPath: 'assets/arenas/room_university.webp',
    ),
  ];

  static ArenaRoom getById(String id) {
    return rooms.firstWhere((r) => r.id == id, orElse: () => rooms.first);
  }
}
