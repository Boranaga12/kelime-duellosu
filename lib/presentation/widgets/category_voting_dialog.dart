import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/categories_data.dart';
import '../../data/models/category.dart';

class CategoryVotingDialog extends StatefulWidget {
  final void Function(Category selectedCategory) onCategoryFinalized;

  const CategoryVotingDialog({super.key, required this.onCategoryFinalized});

  @override
  State<CategoryVotingDialog> createState() => _CategoryVotingDialogState();
}

class _CategoryVotingDialogState extends State<CategoryVotingDialog> {
  late List<Category> _options;
  Category? _userVote;
  Category? _opponentVote;
  int _secondsLeft = 5;
  Timer? _timer;
  bool _isSpinning = false;
  Category? _finalCategory;

  @override
  void initState() {
    super.initState();
    // 3 rastgele kategori seç
    final shuffled = List<Category>.from(sampleCategories)..shuffle();
    _options = shuffled.take(3).toList();

    _startVotingCountdown();
  }

  void _startVotingCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_secondsLeft <= 1) {
        timer.cancel();
        _finalizeSelection();
      } else {
        setState(() => _secondsLeft--);
      }
    });

    // Rakibin oy vermesi simülasyonu (2 saniye sonra)
    Timer(const Duration(milliseconds: 1800), () {
      if (mounted) {
        setState(() {
          _opponentVote = _options[Random().nextInt(_options.length)];
        });
      }
    });
  }

  void _finalizeSelection() {
    _userVote ??= _options[0];
    _opponentVote ??= _options[1];

    setState(() => _isSpinning = true);

    // Kura çek / Karar ver
    Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      final selected = (_userVote == _opponentVote)
          ? _userVote!
          : (_random.nextBool() ? _userVote! : _opponentVote!);

      setState(() {
        _finalCategory = selected;
        _isSpinning = false;
      });

      Timer(const Duration(milliseconds: 900), () {
        widget.onCategoryFinalized(selected);
      });
    });
  }

  final Random _random = Random();

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Kategori Oylaması',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textLight,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '${_secondsLeft}s',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryLight,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Oynamak istediğiniz kategoriye oy verin:',
              style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),

            if (_isSpinning)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: const [
                    CircularProgressIndicator(color: AppColors.primary),
                    SizedBox(height: 12),
                    Text(
                      'Kategori belirleniyor...',
                      style: TextStyle(fontSize: 13, color: AppColors.primaryLight, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              )
            else if (_finalCategory != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary, width: 1.5),
                ),
                child: Column(
                  children: [
                    Text(_finalCategory!.iconEmoji, style: const TextStyle(fontSize: 36)),
                    const SizedBox(height: 6),
                    Text(
                      _finalCategory!.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryLight,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Seçildi! Düello Başlıyor...',
                      style: TextStyle(fontSize: 11, color: AppColors.accentGreen, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              )
            else
              ..._options.map((cat) {
                final isMyVote = _userVote == cat;
                final isOpponentVote = _opponentVote == cat;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () {
                      setState(() => _userVote = cat);
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isMyVote ? AppColors.surfaceLight : AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isMyVote ? AppColors.primary : AppColors.cardBorder,
                          width: isMyVote ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(cat.iconEmoji, style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              cat.title,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: isMyVote ? AppColors.primaryLight : AppColors.textLight,
                              ),
                            ),
                          ),
                          if (isMyVote)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.playerColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Senin Oyun',
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.playerColor),
                              ),
                            ),
                          if (isOpponentVote) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.opponentColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Rakip',
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.opponentColor),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
