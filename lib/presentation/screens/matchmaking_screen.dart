import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../core/services/sound_service.dart';
import '../../core/theme/app_colors.dart';
import '../../data/categories_data.dart';
import '../../data/models/category.dart';
import '../../data/models/player.dart';
import '../../data/services/multiplayer_service.dart';
import '../../data/services/supabase_service.dart';
import '../../domain/bot_ai_engine.dart';
import '../controllers/game_controller.dart';
import '../controllers/profile_controller.dart';
import '../widgets/avatar_badge.dart';
import 'battle_arena_screen.dart';

enum MatchmakingStage { searching, found, briefing }

class MatchmakingScreen extends StatefulWidget {
  final bool isPracticeBot;

  const MatchmakingScreen({
    super.key,
    this.isPracticeBot = false,
  });

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen> {
  MatchmakingStage _stage = MatchmakingStage.searching;
  Player? _opponent;
  Category? _selectedCategory;
  bool _hasChangedCategory = false;
  final int _countdown = 5;
  Timer? _countdownTimer;
  Timer? _transitionTimer;

  @override
  void initState() {
    super.initState();
    _startMatchmaking();
  }

  void _startMatchmaking() {
    final cat = sampleCategories[Random().nextInt(sampleCategories.length)];
    _selectedCategory = cat;

    if (widget.isPracticeBot) {
      // Bot ile alıştırma modu
      _transitionTimer = Timer(const Duration(milliseconds: 2200), () {
        if (!mounted) return;
        final bot = BotAiEngine.generateBotPlayer();
        _onMatchFound(bot);
      });
    } else {
      // Gerçek Online 1v1 Eşleştirmesi (Supabase)
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final isOnline = await SupabaseService.checkConnection();
        if (!mounted) return;

        if (!isOnline) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '⚠️ Çevrimiçi sunucuya bağlanılamadı (${SupabaseService.connectionError ?? "Sunucu kapalı"}). 12 sn içinde rakip bulunamazsa alıştırma botuna geçilecek.',
              ),
              backgroundColor: const Color(0xFFEF4444),
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }

        final user = context.read<ProfileController>().player;
        final game = context.read<GameController>();

        // 12 saniyelik güvenlik zaman aşımı: Eğer gerçek oyuncu gelmezse bot ile oyunu başlat (kullanıcı takılı kalmasın)
        _transitionTimer = Timer(const Duration(seconds: 12), () {
          if (!mounted || _stage != MatchmakingStage.searching) return;
          MultiplayerService.cancelQuickMatch();
          final bot = BotAiEngine.generateBotPlayer();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Canlı rakip bulunamadı, antrenman botu bağlandı! 🤖'),
              backgroundColor: const Color(0xFF0284C7),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
          _onMatchFound(bot);
        });

        MultiplayerService.findOrCreateQuickMatch(
          currentPlayer: user,
          onMatchFound: (opponent, isHost, roomCode) {
            if (!mounted) return;
            _transitionTimer?.cancel();
            _onMatchFound(opponent);
          },
          onWordReceived: (payload) {
            final word = payload['word']?.toString() ?? '';
            final isCorrect = payload['is_correct'] == true;
            game.submitOpponentRemoteWord(word, isCorrect: isCorrect);
          },
          onEmoteReceived: (emoji, senderId) {
            game.triggerRemoteEmote(emoji);
          },
        );
      });
    }
  }

  void _onMatchFound(Player opponent) {
    if (!mounted) return;

    setState(() {
      _opponent = opponent;
      _stage = MatchmakingStage.found;
    });

    SoundService.playTurnSwitch();

    // 1.2 saniye sonra doğrudan BattleArenaScreen'e ve birleşik brifing paneline geçiş yap
    _transitionTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      _launchBattle();
    });
  }


  void _changeCategory() {
    if (_hasChangedCategory || _selectedCategory == null) return;

    final profile = context.read<ProfileController>();
    if (profile.coins < 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Soruyu değiştirmek için en az 50 altınınız olmalı! 🪙'),
          backgroundColor: const Color(0xFFEF4444),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final success = profile.spendCoins(50);
    if (!success) return;

    final remainingCategories = sampleCategories
        .where((c) => c.id != _selectedCategory!.id)
        .toList();
    final newCategory = remainingCategories[Random().nextInt(remainingCategories.length)];

    setState(() {
      _selectedCategory = newCategory;
      _hasChangedCategory = true;
    });

    SoundService.playCorrect();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Soru değiştirildi: "${newCategory.title}" 🔄'),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _cancelMatchmaking() {
    _countdownTimer?.cancel();
    _transitionTimer?.cancel();

    if (!widget.isPracticeBot) {
      MultiplayerService.cancelQuickMatch();
    }
    Navigator.of(context).pop();
  }

  void _launchBattle() {
    _countdownTimer?.cancel();
    _transitionTimer?.cancel();

    final userPlayer = context.read<ProfileController>().player;
    context.read<GameController>().startNewGame(
          category: _selectedCategory ?? sampleCategories.first,
          userPlayer: userPlayer,
          opponentPlayer: _opponent!,
          isPracticeBot: widget.isPracticeBot,
          showBriefing: true,
        );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const BattleArenaScreen()),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _transitionTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileController>();
    final userPlayer = profile.player;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _cancelMatchmaking();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                child: _stage == MatchmakingStage.searching
                    ? _buildSearchingView()
                    : _stage == MatchmakingStage.found
                        ? _buildMatchFoundView(userPlayer)
                        : _buildBriefingView(userPlayer, profile.coins),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 1. Aşama: Rakip Aranıyor (Radar)
  Widget _buildSearchingView() {
    final isBot = widget.isPracticeBot;

    return Column(
      key: const ValueKey('searching_stage'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isBot ? const Color(0xFF0284C7) : const Color(0xFFF59E0B)).withValues(alpha: 0.15),
              ),
            )
                .animate(onPlay: (controller) => controller.repeat())
                .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.6, 1.6), duration: 1500.ms)
                .fadeOut(duration: 1500.ms),
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1E293B),
                boxShadow: const [
                  BoxShadow(color: Colors.black45, offset: Offset(0, 4), blurRadius: 6),
                ],
              ),
              child: Center(
                child: Icon(
                  isBot ? Icons.smart_toy_rounded : Icons.flash_on_rounded,
                  color: isBot ? const Color(0xFF38BDF8) : const Color(0xFFFBBF24),
                  size: 38,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 36),
        Text(
          isBot ? 'Bot Rakip Aranıyor...' : 'Canlı Rakip Aranıyor...',
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w900,
            color: AppColors.textLight,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isBot
              ? 'Yapay zeka antrenman partneriniz hazırlanıyor'
              : 'Supabase üzerinden gerçek canlı bir düellocu eşleştiriliyor',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 40),

        // 3D İptal Butonu
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _cancelMatchmaking,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Color(0xFF0F172A), offset: Offset(0, 4)),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
                  SizedBox(width: 8),
                  Text(
                    'İptal Et',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textLight),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 2. Aşama: Eşleşme Sağlandı Animasyonu (VS)
  Widget _buildMatchFoundView(Player userPlayer) {
    return Column(
      key: const ValueKey('found_stage'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Color(0xFF047857), offset: Offset(0, 4)),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'EŞLEŞME SAĞLANDI!',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack),
        const SizedBox(height: 32),

        // 3D VS Kartı
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(color: Color(0xFF0F172A), offset: Offset(0, 6)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  AvatarBadge(player: userPlayer, size: 56),
                  const SizedBox(height: 8),
                  Text(
                    userPlayer.name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textLight),
                  ),
                ],
              ),
              const Text(
                'VS',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFFF59E0B),
                ),
              ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
              Column(
                children: [
                  AvatarBadge(player: _opponent!, size: 56, borderColor: const Color(0xFFEF4444)),
                  const SizedBox(height: 8),
                  Text(
                    _opponent!.name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textLight),
                  ),
                ],
              ),
            ],
          ),
        ).animate().scale(duration: 350.ms, curve: Curves.easeOutBack),
        const SizedBox(height: 24),
        const Text(
          'Oyun bilgileri yükleniyor...',
          style: TextStyle(fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  /// 3. Aşama: Maç Öncesi Brifing Paneli & Soru Değiştirme
  Widget _buildBriefingView(Player userPlayer, int userCoins) {
    return Container(
      key: const ValueKey('briefing_stage'),
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(color: Color(0xFF0F172A), offset: Offset(0, 8), blurRadius: 4),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Başlık ve Bakiye
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '⚔️ DÜELLO BRİFİNGİ',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                    color: Color(0xFFF59E0B),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Text('🪙 ', style: TextStyle(fontSize: 13)),
                    Text(
                      '$userCoins',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Karşılaşma Özeti (3D Mini VS Paneli)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(userPlayer.avatarEmoji, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 8),
                    Text(
                      userPlayer.name,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF10B981)),
                    ),
                  ],
                ),
                const Text(
                  'VS',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textMuted,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      _opponent!.name,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFFEF4444)),
                    ),
                    const SizedBox(width: 8),
                    Text(_opponent!.avatarEmoji, style: const TextStyle(fontSize: 22)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Soru / Kategori Kartı
          if (_selectedCategory != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: const Color(0xFF243046),
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(color: Color(0xFF131A28), offset: Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    _selectedCategory!.iconEmoji,
                    style: const TextStyle(fontSize: 38),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedCategory!.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textLight,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedCategory!.description,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textMuted,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 250.ms),

          const SizedBox(height: 18),

          // 🪙 50 Altın ile Soru Değiştirme Butonu (3D Tok)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _hasChangedCategory ? null : _changeCategory,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: _hasChangedCategory ? const Color(0xFF334155) : const Color(0xFFD97706),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _hasChangedCategory ? const Color(0xFF1E293B) : const Color(0xFF92400E),
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _hasChangedCategory ? Icons.check_circle_rounded : Icons.change_circle_outlined,
                      size: 20,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _hasChangedCategory
                          ? 'Soru 1 Kez Değiştirildi'
                          : 'Soruyu Değiştir (🪙 50 Altın)',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Geri Sayım ve Hemen Başla
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0F172A),
                  boxShadow: const [
                    BoxShadow(color: Colors.black38, offset: Offset(0, 3)),
                  ],
                ),
                child: Center(
                  child: Text(
                    '$_countdown',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _launchBattle,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(color: Color(0xFF047857), offset: Offset(0, 4)),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                          SizedBox(width: 6),
                          Text(
                            'Hemen Başla',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().scale(duration: 350.ms, curve: Curves.easeOutBack);
  }
}
