import 'package:flutter/material.dart';

/// 60 FPS akıcı ve kesintisiz azalan süre sayacı barı
class SmoothBriefingTimerBar extends StatefulWidget {
  final int totalSeconds;
  final int resetTrigger;
  final VoidCallback? onFinished;

  const SmoothBriefingTimerBar({
    super.key,
    this.totalSeconds = 6,
    this.resetTrigger = 0,
    this.onFinished,
  });

  @override
  State<SmoothBriefingTimerBar> createState() => _SmoothBriefingTimerBarState();
}

class _SmoothBriefingTimerBarState extends State<SmoothBriefingTimerBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.totalSeconds),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        widget.onFinished?.call();
      }
    });

    _startCountdown();
  }

  void _startCountdown() {
    _controller.duration = Duration(seconds: widget.totalSeconds);
    _controller.reverse(from: 1.0);
  }

  @override
  void didUpdateWidget(covariant SmoothBriefingTimerBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.resetTrigger != oldWidget.resetTrigger) {
      // Soru değiştiğinde veya süre sıfırlandığında süre barı tekrar tam dolar!
      _startCountdown();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value.clamp(0.0, 1.0);
        final remainingSec = (progress * widget.totalSeconds).ceil().clamp(0, widget.totalSeconds);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Raunt Başlıyor',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                Text(
                  '⏳ ${remainingSec}s',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFF59E0B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 10,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(10),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFF10B981)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
