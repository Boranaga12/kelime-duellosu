import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class JokerButton extends StatelessWidget {
  final String icon;
  final String label;
  final int count;
  final VoidCallback onTap;
  final Color activeColor;

  const JokerButton({
    super.key,
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
    this.activeColor = AppColors.primaryLight,
  });

  @override
  Widget build(BuildContext context) {
    final bool isAvailable = count > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isAvailable ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Opacity(
          opacity: isAvailable ? 1.0 : 0.4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A),
                  offset: const Offset(0, 4),
                  blurRadius: 0, // 3D bevel effect
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(icon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textLight,
                      ),
                    ),
                    Text(
                      '$count adet',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isAvailable ? activeColor : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
