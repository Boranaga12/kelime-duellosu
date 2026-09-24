import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class EmotePicker extends StatelessWidget {
  final void Function(String emoji) onEmoteSelected;

  const EmotePicker({super.key, required this.onEmoteSelected});

  static const List<Map<String, String>> emotes = [
    {'emoji': '🤔', 'label': 'Düşünce'},
    {'emoji': '👏', 'label': 'Bravo'},
    {'emoji': '⚡', 'label': 'Hızlı Ol'},
    {'emoji': '😱', 'label': 'Olamaz'},
    {'emoji': '😎', 'label': 'Havalı'},
    {'emoji': '🔥', 'label': 'Alev'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorderActive, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: emotes.map((item) {
          final emoji = item['emoji']!;
          return InkWell(
            onTap: () => onEmoteSelected(emoji),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(emoji, style: const TextStyle(fontSize: 24)),
            ),
          );
        }).toList(),
      ),
    );
  }
}
