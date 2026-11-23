// lib/core/localization/app_strings.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLocale {
  static final AppLocale _instance = AppLocale._internal();
  factory AppLocale() => _instance;
  AppLocale._internal();

  static const String keyPrefLanguage = 'pref_app_language_v2';
  static const String keyPrefRegion = 'pref_app_region';
  static const String keyPrefFlag = 'pref_app_flag';

  // Default Language is English!
  final ValueNotifier<String> currentLanguage = ValueNotifier('en');
  final ValueNotifier<String> currentRegion = ValueNotifier('GLOBAL');
  final ValueNotifier<String> currentFlag = ValueNotifier('🌐');

  static ValueNotifier<String> get currentCode => _instance.currentLanguage;
  static bool get isBengali => _instance.currentLanguage.value == 'bn';
  static bool get isHindi => _instance.currentLanguage.value == 'hi';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    currentLanguage.value = prefs.getString(keyPrefLanguage) ?? 'en';
    currentRegion.value = prefs.getString(keyPrefRegion) ?? 'GLOBAL';
    currentFlag.value = prefs.getString(keyPrefFlag) ?? '🌐';
  }

  Future<void> setLanguage(String code) async {
    currentLanguage.value = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyPrefLanguage, code);
  }

  Future<void> setRegion(String region, String flag) async {
    currentRegion.value = region;
    currentFlag.value = flag;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyPrefRegion, region);
    await prefs.setString(keyPrefFlag, flag);
  }

  static String tr(String key) {
    final lang = _instance.currentLanguage.value;
    return _translations[lang]?[key] ?? _translations['en']?[key] ?? key;
  }

  static final Map<String, Map<String, String>> _translations = {
    'en': {
      // General
      'app_title': 'Kolom Fight: Tactical Classroom Pen Battle',
      'guest_play': 'Play as Guest (75 Coins)',
      'play_as_guest': 'Play as Guest',
      'practice_offline': 'Practice Offline',
      'practice_offline_note': 'Local profile only. No online rewards or account sync.',
      'google_sign_in': 'Sign in with Google (+120 Coins)',
      'sign_in_google': 'Sign in with Google',
      'link_google': 'Link Google Account',
      'merge_success': 'Account linked! Progress and coins merged.',
      'loading': 'Loading...',
      'save': 'Save',
      'cancel': 'Cancel',
      'back': 'Back',
      'settings': 'Settings',
      'physics_kolom_championship': 'PHYSICS-DRIVEN TABLETOP CHAMPIONSHIP',
      'coins': 'Coins',
      'quick_chat': 'Classroom Chat Reactions',

      // Lobby & Modes
      'quick_play': 'Quick Match',
      'quick_play_sub': 'Human-only real-time 1v1 duels',
      'arenas': 'Select Arena',
      'arenas_sub': '7 Bangladeshi Educational System Benches',
      'bot_practice': 'Bot Practice',
      'bot_practice_sub': 'Offline Play with Pro AI Bot',
      'private_room': 'Private Room',
      'private_match': 'Private Room & Matches',
      'private_room_sub': 'Play with Friends via 6-Digit Code',
      'friends': 'Friends & Social',
      'friends_sub': 'Tag search, friends & direct challenges',
      'garage': 'Stationery',
      'pen_garage': 'Stationery Shop & Pens',
      'garage_sub': 'Buy, inspect & equip pens',
      'leaderboard': 'Leaderboard',
      'leaderboard_sub': 'Global, Division & Trophy Rankings',
      'global_standings': 'Global Standings',
      'regional_division': 'Regional Division',
      'empty_leaderboard': 'No standings yet. Play matches to climb!',
      'clubs': 'Clubs & Guilds',
      'clubs_sub': 'Create, join & compare clubs',
      'profile': 'Profile',

      // In-Game
      'your_turn': 'YOUR TURN! Drag anywhere to aim & flick',
      'opponent_turn': 'Opponent thinking...',
      'bot_turn': 'Bot calculating shot...',
      'turn_timeout_warning': '30s Turn Timer Expiring!',
      'turn_passed': 'Time expired! Turn passed to opponent.',
      'strike_slider_label': 'Strike Point',
      'strike_center': 'Center Push',
      'strike_tip': 'Tip Whip-Spin',
      'strike_cap': 'Back-Cap Smash',
      'knockout_win': 'KNOCKOUT VICTORY! Opponent went off table!',
      'knockout_lose': 'KNOCKOUT DEFEAT! Your pen fell off the bench!',
      'rematch': 'Play Again',
      'lobby': 'Return to Lobby',
      'pot_label': 'POT',
      'rp_label': 'RP',
      'trophies_label': 'Trophies',

      // Cups
      'cup_bronze': 'Bronze Cup 🥉',
      'cup_silver': 'Silver Cup 🥈',
      'cup_gold': 'Gold Cup 🥇',
      'cup_diamond': 'Diamond Master Cup 💎',
      'cup_grandmaster': 'Grandmaster National Cup 👑',

      'play_1v1_duel': 'PLAY 1v1 DUEL',
      'play_bot': 'PLAY WITH BOT',
      'insufficient_coins': 'Insufficient Coins',
      'entry_fee': 'Entry Fee',
      'winner_pot': 'Winner Pot',
      'table_physics': 'Table Physics',
      'select_room_title': 'Select Arena Bench',
      'swipe_hint': 'Swipe left or right to explore arenas',
      'xp_label': 'XP',
      'level_label': 'LVL',
      'win_rate': 'Win Rate',
      'win_streak': 'Win Streak',

      // Settings
      'language': 'Language',
      'sound_effects': 'Sound Effects',
      'vibration': 'Haptic Vibration',
      'region': 'Region / Flag',
      'version': 'Version 1.0.0',
    },

    'bn': {
      // General
      'app_title': 'কলম খেলা: ক্লাসরুম পেন ব্যাটেল',
      'guest_play': 'গেস্ট হিসেবে খেলুন (৭৫ কয়েন)',
      'play_as_guest': 'গেস্ট হিসেবে খেলুন',
      'practice_offline': 'অফলাইনে প্র্যাকটিস',
      'practice_offline_note': 'শুধু স্থানীয় প্রোফাইল। অনলাইন পুরস্কার বা অ্যাকাউন্ট সিঙ্ক নেই।',
      'google_sign_in': 'গুগল দিয়ে সাইন ইন (+১২০ কয়েন)',
      'sign_in_google': 'গুগল দিয়ে সাইন ইন',
      'link_google': 'গুগল অ্যাকাউন্ট লিংক করুন',
      'merge_success': 'অ্যাকাউন্ট মার্জ সফল! কয়েন ও প্রগ্রেস সুরক্ষিত।',
      'loading': 'লোড হচ্ছে...',
      'save': 'সংরক্ষণ',
      'cancel': 'বাতিল',
      'back': 'পেছনে',
      'settings': 'সেটিংস',
      'physics_kolom_championship': 'পদার্থবিজ্ঞান নির্ভর টেবিল ব্যাটেল চ্যাম্পিয়নশিপ',
      'coins': 'কয়েন',
      'quick_chat': 'ক্লাসরুম রিঅ্যাকশন চ্যাট',

      // Lobby & Modes
      'quick_play': 'কুইক ম্যাচ',
      'quick_play_sub': 'শুধু মানুষের সঙ্গে রিয়েল-টাইম ১ বনাম ১ ম্যাচ',
      'arenas': 'অ্যারেনা বাছুন',
      'arenas_sub': '৭টি ক্লাসরুম কাঠের বেঞ্চ',
      'bot_practice': 'বট প্র্যাকটিস',
      'bot_practice_sub': 'অফলাইন মোড (প্রো এআই বট)',
      'private_room': 'প্রাইভেট রুম',
      'private_match': 'প্রাইভেট ম্যাচ রুম',
      'private_room_sub': '৬ ডিজিট কোড দিয়ে খেলুন',
      'friends': 'বন্ধুমহল',
      'friends_sub': 'ট্যাগ সার্চ, বন্ধু ও সরাসরি চ্যালেঞ্জ',
      'garage': 'স্টেশনারি',
      'pen_garage': 'স্টেশনারি শপ ও কলমের দোকান',
      'garage_sub': 'কলম কিনুন, দেখুন ও ব্যবহার করুন',
      'leaderboard': 'লিডারবোর্ড',
      'leaderboard_sub': 'গ্লোবাল, বিভাগ ও ট্রফি র‍্যাংকিং',
      'global_standings': 'গ্লোবাল তালিকা',
      'regional_division': 'বিভাগীয় তালিকা',
      'empty_leaderboard': 'কোনো রেকর্ড নেই। ম্যাচ খেলে লিডারবোর্ডে উঠুন!',
      'clubs': 'ক্লাব ও গিল্ড',
      'clubs_sub': 'ক্লাব তৈরি, যোগ ও তুলনা করুন',
      'profile': 'প্রোফাইল',

      // In-Game
      'your_turn': 'আপনার চাল! স্ক্রিনে ড্র্যাগ করে ফ্লিক করুন',
      'opponent_turn': 'প্রতিপক্ষের চাল... অপেক্ষা করুন',
      'bot_turn': 'বট শট হিসাব করছে...',
      'turn_timeout_warning': '৩০ সেকেন্ডের সময় শেষ হয়ে আসছে!',
      'turn_passed': 'সময় শেষ! চাল প্রতিপক্ষের কাছে চলে গেছে।',
      'strike_slider_label': 'স্ট্রাইক পয়েন্ট',
      'strike_center': 'সেন্টার পুশ',
      'strike_tip': 'টিপ হুইপ-স্পিন',
      'strike_cap': 'ক্যাপ পাওয়ার স্ম্যাশ',
      'knockout_win': 'বিজয়! প্রতিপক্ষের কলম নিচে পড়ে গেছে!',
      'knockout_lose': 'আউট! আপনার কলম নিচে পড়ে গেছে!',
      'rematch': 'আবার খেলুন',
      'lobby': 'লবিতে ফিরুন',
      'pot_label': 'পট',
      'rp_label': 'রেটিং',
      'trophies_label': 'ট্রফি',

      // Cups
      'cup_bronze': 'ব্রোঞ্জ কাপ 🥉',
      'cup_silver': 'সিলভার কাপ 🥈',
      'cup_gold': 'গোল্ড কাপ 🥇',
      'cup_diamond': 'ডায়মন্ড মাস্টার কাপ 💎',
      'cup_grandmaster': 'গ্র্যান্ডমাস্টার ন্যাশনাল কাপ 👑',

      'play_1v1_duel': '১ বনাম ১ ডুয়েল খেলুন',
      'play_bot': 'বট প্র্যাকটিস করুন',
      'insufficient_coins': 'পর্যাপ্ত কয়েন নেই',
      'entry_fee': 'এন্ট্রি ফি',
      'winner_pot': 'বিজয়ীর পট',
      'table_physics': 'টেবিল বৈশিষ্ট্য',
      'select_room_title': 'অ্যারেনা বেঞ্চ বাছুন',
      'swipe_hint': 'ডানে-বামে সোয়াইপ করে অ্যারেনা দেখুন',
      'xp_label': 'এক্সপি',
      'level_label': 'লেভেল',
      'win_rate': 'উইন রেট',
      'win_streak': 'উইন স্ট্রাইক',

      // Settings
      'language': 'ভাষা (Language)',
      'sound_effects': 'সাউন্ড ইফেক্টস',
      'vibration': 'ভাইব্রেশন / হ্যাপটিক্স',
      'region': 'অঞ্চল ও পতাকা',
      'version': 'ভার্সন ১.০.০',
    },

    'hi': {
      // General
      'app_title': 'कलम फाइट: क्लासरूम पेन बैटल',
      'guest_play': 'गेस्ट के रूप में खेलें (75 कॉइन्स)',
      'play_as_guest': 'गेस्ट के रूप में खेलें',
      'practice_offline': 'ऑफ़लाइन अभ्यास',
      'practice_offline_note': 'केवल स्थानीय प्रोफ़ाइल। ऑनलाइन पुरस्कार या सिंक नहीं।',
      'google_sign_in': 'गूगल से लॉगिन करें (+120 कॉइन्स)',
      'sign_in_google': 'गूगल से लॉगिन करें',
      'link_google': 'गूगल खाता लिंक करें',
      'merge_success': 'खाता लिंक हो गया! कॉइन्स सुरक्षित हैं।',
      'loading': 'लोड हो रहा है...',
      'save': 'सहेजें',
      'cancel': 'रद्द करें',
      'back': 'वापस',
      'settings': 'सेटिंग्स',
      'physics_kolom_championship': 'भौतिकी आधारित टेबल बैटल चैंपियनशिप',
      'coins': 'कॉइन्स',
      'quick_chat': 'क्लासरूम चैट प्रतिक्रियाएं',

      // Lobby & Modes
      'quick_play': 'क्विक मैच',
      'quick_play_sub': 'केवल मनुष्यों के साथ रीयल-टाइम 1v1 मुकाबले',
      'arenas': 'अखाड़ा चुनें',
      'arenas_sub': '7 क्लासरूम लकड़ी के बेंच',
      'bot_practice': 'बॉट प्रैक्टिस',
      'bot_practice_sub': 'ऑफलाइन मोड (प्रो एआई बॉट)',
      'private_room': 'प्राइवेट रूम',
      'private_match': 'प्राइवेट मैच रूम',
      'private_room_sub': '6 अंकों के कोड से खेलें',
      'friends': 'दोस्त और सोशल',
      'friends_sub': 'टैग खोज, दोस्त और सीधी चुनौतियाँ',
      'garage': 'स्टेशनरी',
      'pen_garage': 'स्टेशनरी दुकान और पेन',
      'garage_sub': 'पेन खरीदें, देखें और चुनें',
      'leaderboard': 'लीडरबोर्ड',
      'leaderboard_sub': 'ग्लोबल और ट्रॉफी रैंकिंग',
      'global_standings': 'ग्लोबल स्टैंडिंग्स',
      'regional_division': 'क्षेत्रीय प्रभाग',
      'empty_leaderboard': 'अभी कोई रिकॉर्ड नहीं है। आगे बढ़ें!',
      'clubs': 'क्लब और गिल्ड',
      'clubs_sub': 'क्लब बनाएं, जुड़ें और तुलना करें',
      'profile': 'प्रोफाइल',

      // In-Game
      'your_turn': 'आपकी बारी! निशाना लगाकर फ्लिक करें',
      'opponent_turn': 'प्रतिद्वंद्वी सोच रहा है...',
      'bot_turn': 'बॉट निशाना लगा रहा है...',
      'turn_timeout_warning': '30 सेकंड समाप्त होने वाले हैं!',
      'turn_passed': 'समय समाप्त! बारी विरोधी को दी गई।',
      'strike_slider_label': 'स्ट्राइक पॉइंट',
      'strike_center': 'सेंटर पुश',
      'strike_tip': 'टिप व्हिप-स्पिन',
      'strike_cap': 'बैक-कैप स्मैश',
      'knockout_win': 'शानदार जीत! विरोधी की कलम गिर गई!',
      'knockout_lose': 'हार! आपकी कलम टेबल से गिर गई!',
      'rematch': 'फिर से खेलें',
      'lobby': 'लॉबी में जाएं',
      'pot_label': 'पॉट',
      'rp_label': 'आर.पी',
      'trophies_label': 'ट्रॉफी',

      // Cups
      'cup_bronze': 'कांस्य कप 🥉',
      'cup_silver': 'रजत कप 🥈',
      'cup_gold': 'स्वर्ण कप 🥇',
      'cup_diamond': 'डायमंड मास्टर कप 💎',
      'cup_grandmaster': 'ग्रैंडमास्टर नेशनल कप 👑',

      'play_1v1_duel': '1v1 मुकाबला खेलें',
      'play_bot': 'बॉट के साथ खेलें',
      'insufficient_coins': 'अपर्याप्त कॉइन्स',
      'entry_fee': 'प्रवेश शुल्क',
      'winner_pot': 'विजेता पॉट',
      'table_physics': 'टेबल भौतिकी',
      'select_room_title': 'अखाड़ा बेंच चुनें',
      'swipe_hint': 'अखाड़े देखने के लिए बाएं-दाएं स्वाइप करें',
      'xp_label': 'एक्स.पी',
      'level_label': 'स्तर',
      'win_rate': 'जीत दर',
      'win_streak': 'जीत का सिलसिला',

      // Settings
      'language': 'भाषा (Language)',
      'sound_effects': 'ध्वनि प्रभाव',
      'vibration': 'कंपन (Vibration)',
      'region': 'क्षेत्र और ध्वज',
      'version': 'संस्करण 1.0.0',
    },
  };
}
