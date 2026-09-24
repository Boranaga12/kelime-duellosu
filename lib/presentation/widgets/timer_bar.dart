import 'package:flutter/material.dart';

class TimerBar extends StatelessWidget {
  final int totalSeconds;
  final int remainingSeconds;

  const TimerBar({
    super.key,
    required this.totalSeconds,
    required this.remainingSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalSeconds > 0
        ? (remainingSeconds / totalSeconds).clamp(0.0, 1.0)
        : 0.0;
    final isUrgent = remainingSeconds <= 4;
    final isWarning = remainingSeconds <= 8;

    final barColor = isUrgent
        ? const Color(0xFFEF4444) // Canlı kırmızı
        : (isWarning
            ? const Color(0xFFF59E0B) // Canlı sarı/turuncu
            : const Color(0xFF10B981)); // Canlı zümrüt yeşil

    final barDarkColor = isUrgent
        ? const Color(0xFF991B1B)
        : (isWarning
            ? const Color(0xFFB45309)
            : const Color(0xFF047857));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Süre Sayısı Rozeti (Sağda küçük ve net)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isUrgent
                      ? const Color(0xFFEF4444).withValues(alpha: 0.2)
                      : const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      offset: Offset(0, 2),
                      blurRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 13,
                      color: barColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${remainingSeconds}s',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: barColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // 3D Tok İlerleme Çubuğu
          Container(
            height: 9,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(6),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  offset: Offset(0, 2),
                  blurRadius: 3,
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final barWidth = constraints.maxWidth * progress;
                return Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.linear,
                      width: barWidth,
                      height: 9,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [barColor, barDarkColor],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: barColor.withValues(alpha: 0.4),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
