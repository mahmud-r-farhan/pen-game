// lib/ui/widgets/emoji_picker_overlay.dart
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_strings.dart';

class EmojiPickerOverlay extends StatelessWidget {
  final void Function(String emojiId, String text) onSelect;

  const EmojiPickerOverlay({super.key, required this.onSelect});

  static const List<Map<String, String>> classroomChats = [
    {'emoji': '💥', 'id': 'hit', 'textEn': 'What a wicked shot!', 'textBn': 'কী শট ছিল রে ভাই!', 'textHi': 'क्या शॉट था भाई!'},
    {'emoji': '😱', 'id': 'shock', 'textEn': 'It fell off the bench!', 'textBn': 'পড়ে গেল রে টেবিল থেকে!', 'textHi': 'गिर गया टेबल से!'},
    {'emoji': '🤫', 'id': 'quiet', 'textEn': 'Teacher is looking!', 'textBn': 'স্যার আসছেন, আস্তে!', 'textHi': 'टीचर देख रहे हैं!'},
    {'emoji': '🚫', 'id': 'nocap', 'textEn': 'No cap flick allowed!', 'textBn': 'ক্যাপ খুলে মারিস না!', 'textHi': 'कैप हटा के मत मारो!'},
    {'emoji': '🔥', 'id': 'fire', 'textEn': 'Absolute clutch fire!', 'textBn': 'সাবাশ টাইগার আগুন!', 'textHi': 'क्या बात है आग लगा दी!'},
    {'emoji': '🤦‍♂️', 'id': 'facepalm', 'textEn': 'Ugh, missed by a hair!', 'textBn': 'ধুররর! অল্পের জন্য মিস!', 'textHi': 'धत! बाल-बाल बचा!'},
    {'emoji': '👑', 'id': 'king', 'textEn': 'King of the classroom!', 'textBn': 'ক্লাসরুমের বস আমি!', 'textHi': 'क्लासरूम का किंग!'},
    {'emoji': '🔄', 'id': 'rematch', 'textEn': 'One more rematch?', 'textBn': 'আরেক ম্যাচ হয়ে যাক?', 'textHi': 'एक और मैच हो जाए?'},
  ];

  @override
  Widget build(BuildContext context) {
    final isBn = AppLocale.isBengali;
    final isHi = AppLocale.isHindi;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.glassSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocale.tr('quick_chat'),
                style: const TextStyle(
                  color: AppColors.goldTiffinCoin,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Icon(Icons.forum_rounded, size: 16, color: AppColors.goldTiffinCoin),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: classroomChats.map((chat) {
              final text = isBn
                  ? chat['textBn']!
                  : isHi
                      ? chat['textHi']!
                      : chat['textEn']!;

              return InkWell(
                onTap: () => onSelect(chat['id']!, text),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurfaceDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(chat['emoji']!, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        text,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
