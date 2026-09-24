import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/word_entry.dart';

class WordBubble extends StatelessWidget {
  final WordEntry entry;
  final bool isFromCurrentUser;
  final bool isFromMyTeam;
  final Color? teamColor;
  final String? senderName;

  const WordBubble({
    super.key,
    required this.entry,
    required this.isFromCurrentUser,
    this.isFromMyTeam = false,
    this.teamColor,
    this.senderName,
  });

  @override
  Widget build(BuildContext context) {
    final bool isCorrect = entry.isCorrect;
    final bool isRightSide = isFromCurrentUser || isFromMyTeam;

    // Renkleri takıma ve doğruluğa göre belirle
    final effectiveTeamColor = teamColor ??
        (isRightSide ? const Color(0xFF10B981) : const Color(0xFFEF4444));

    final Color textColor = isCorrect
        ? AppColors.textLight
        : AppColors.textLight.withValues(alpha: 0.7);

    final Color bgColor = effectiveTeamColor.withValues(alpha: isCorrect ? 0.22 : 0.16);

    final Color borderColor = effectiveTeamColor.withValues(alpha: isCorrect ? 0.6 : 0.35);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment:
            isRightSide ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 290),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(14),
                topRight: const Radius.circular(14),
                bottomLeft: Radius.circular(isRightSide ? 14 : 2),
                bottomRight: Radius.circular(isRightSide ? 2 : 14),
              ),
              border: Border.all(color: borderColor, width: 1.0),
            ),
            child: Column(
              crossAxisAlignment:
                  isRightSide ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (senderName != null && senderName!.isNotEmpty && !isFromCurrentUser) ...[
                  Text(
                    senderName!,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: effectiveTeamColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (entry.isAiApproved) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        margin: const EdgeInsets.only(right: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.6), width: 0.8),
                        ),
                        child: const Text('🤖', style: TextStyle(fontSize: 11)),
                      ),
                    ] else if (isCorrect) ...[
                      Icon(
                        Icons.check_rounded,
                        size: 13,
                        color: effectiveTeamColor,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(
                        entry.word,
                        style: TextStyle(
                          fontWeight: isCorrect ? FontWeight.w700 : FontWeight.w400,
                          fontSize: 14.5,
                          color: textColor,
                          decoration: isCorrect
                              ? TextDecoration.none
                              : TextDecoration.lineThrough,
                          decorationColor: AppColors.textLight.withValues(alpha: 0.7),
                          decorationThickness: 2.0,
                        ),
                      ),
                    ),
                  ],
                ),
                if (entry.isAiApproved && isCorrect) ...[
                  const SizedBox(height: 3),
                  if (entry.originalTypo != null &&
                      entry.originalTypo!.trim().toLowerCase() != entry.word.trim().toLowerCase()) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF818CF8).withValues(alpha: 0.6), width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('✨', style: TextStyle(fontSize: 10)),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              'Düzeltildi: "${entry.originalTypo}"',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFFA5B4FC),
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.6), width: 0.8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('🤖', style: TextStyle(fontSize: 10)),
                          SizedBox(width: 3),
                          Text(
                            'Yapay Zeka Onayladı',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF7DD3FC),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
