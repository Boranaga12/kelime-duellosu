import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/player.dart';

class AvatarBadge extends StatelessWidget {
  final Player player;
  final bool isRightAligned;
  final Color borderColor;
  final double size;
  final bool showDetails;

  const AvatarBadge({
    super.key,
    required this.player,
    this.isRightAligned = false,
    this.borderColor = AppColors.cardBorderActive,
    this.size = 46,
    this.showDetails = false,
  });

  @override
  Widget build(BuildContext context) {
    final avatarCircle = Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surfaceLight,
            border: Border.all(color: borderColor, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipOval(
            child: (player.avatarUrl != null && player.avatarUrl!.isNotEmpty)
                ? Image.network(
                    player.avatarUrl!,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Center(
                      child: Text(
                        player.avatarEmoji,
                        style: TextStyle(fontSize: size * 0.48),
                      ),
                    ),
                    loadingBuilder: (_, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: Text(
                          player.avatarEmoji,
                          style: TextStyle(fontSize: size * 0.48),
                        ),
                      );
                    },
                  )
                : Center(
                    child: Text(
                      player.avatarEmoji,
                      style: TextStyle(fontSize: size * 0.48),
                    ),
                  ),
          ),
        ),
        Positioned(
          bottom: -2,
          right: -2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.cardBorder, width: 1),
            ),
            child: Text(
              '${player.level}',
              style: const TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFFF59E0B),
              ),
            ),
          ),
        ),
      ],
    );

    if (!showDetails) {
      return avatarCircle;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: isRightAligned ? TextDirection.rtl : TextDirection.ltr,
      children: [
        avatarCircle,
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment:
              isRightAligned ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              player.name,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
                color: AppColors.textLight,
                letterSpacing: 0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 1),
            Text(
              '🏆 ${player.trophies}',
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFFF59E0B),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
