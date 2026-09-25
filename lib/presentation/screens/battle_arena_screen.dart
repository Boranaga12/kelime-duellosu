import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../core/services/sound_service.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/game_round.dart';
import '../controllers/game_controller.dart';
import '../controllers/profile_controller.dart';
import '../widgets/avatar_badge.dart';
import '../widgets/emote_picker.dart';
import '../widgets/timer_bar.dart';
import '../widgets/word_bubble.dart';
import '../widgets/smooth_briefing_timer_bar.dart';
import 'game_over_screen.dart';

class BattleArenaScreen extends StatefulWidget {
  const BattleArenaScreen({super.key});

  @override
  State<BattleArenaScreen> createState() => _BattleArenaScreenState();
}

class _BattleArenaScreenState extends State<BattleArenaScreen> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _navigatedToGameOver = false;
  bool _showEmotePicker = false;

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _submitWord() {
    final game = context.read<GameController>();
    // Sıra bizde değilse gönderme tuşu çalışmaz, yazılan metin TextField'da kalır!
    if (!game.isUserTurn) return;

    final text = _textController.text.trim();
    if (text.isEmpty) return;

    game.submitPlayerWord(text);
    _textController.clear();
    // Klavye asla kapanmaz
    _focusNode.requestFocus();

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameController>();
    final profile = context.watch<ProfileController>();
    final round = game.round;

    if (round == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (round.status == RoundStatus.finished && !_navigatedToGameOver) {
      _navigatedToGameOver = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => GameOverScreen(round: round),
          ),
        );
      });
    }

    final isUserTurn = game.isUserTurn;
    final currentUserId = round.player1.id;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _showQuitDialog(context, game);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  // 1. Üst Bar: Sadece Çıkış, Sade Soru Başlığı ve Ses
                  _buildTopHeader(context, round, game),

                  // 2. 3D Kompakt Oyuncular ve Skor Kartı (SOLDA: RAKİP, SAĞDA: BEN)
                  _buildMatchHeader(round, isUserTurn),

                  // 3. 3D Doğru ve Kesintisiz Süre Barı (15s standart)
                  TimerBar(
                    totalSeconds: round.currentTurnMaxSeconds,
                    remainingSeconds: round.remainingTurnSeconds,
                  ),

                  // Canlı Emote Bildirimi (Varsa)
                  if (game.userEmote != null || game.opponentEmote != null)
                    _buildFloatingEmoteBanner(game, round),

                  // 4. Genişletilmiş Canlı Kelime Akışı (Takım Renkleri & Sağ/Sol Ayrımı)
                  Expanded(
                    child: round.words.isEmpty
                        ? Center(
                            child: Text(
                              'Cevabını yaz ve gönder!',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.3),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            reverse: false,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: round.words.length,
                            itemBuilder: (context, index) {
                              final entry = round.words[index];
                              final isFromMe = entry.playerId == currentUserId;

                              // Takım modunda kontrol
                              final playerTeam = round.playerTeamMap[entry.playerId] ?? (isFromMe ? 'team_1' : 'team_2');
                              final myTeam = round.playerTeamMap[currentUserId] ?? 'team_1';
                              final isFromMyTeam = round.isTeamMode ? (playerTeam == myTeam) : isFromMe;
                              final teamColor = round.teamColors[playerTeam];

                              final sender = round.allPlayers.firstWhere(
                                (p) => p.id == entry.playerId,
                                orElse: () => isFromMe ? round.player1 : round.player2,
                              );

                              return WordBubble(
                                entry: entry,
                                isFromCurrentUser: isFromMe,
                                isFromMyTeam: isFromMyTeam,
                                teamColor: teamColor,
                                senderName: round.isTeamMode ? sender.name : null,
                              );
                            },
                          ),
                  ),

              // Emote Seçici Açıkken
              if (_showEmotePicker)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: EmotePicker(
                    onEmoteSelected: (emoji) {
                      game.sendUserEmote(emoji);
                      setState(() => _showEmotePicker = false);
                    },
                  ),
                ),

              // 5. Sabit Yükseklikte Alt Bilgilendirme Barı (Kelime Akışını Kaydırmaz)
              _buildBottomFeedbackBanner(game),

              // 6. 3D Metin Yazma & Gönderme Alanı (Klavye Kapanmaz)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  boxShadow: [
                    BoxShadow(color: Colors.black45, offset: Offset(0, -3), blurRadius: 4),
                  ],
                ),
                child: Row(
                  children: [
                    // Emote Butonu
                    IconButton(
                      icon: Text(
                        _showEmotePicker ? '❌' : '😊',
                        style: const TextStyle(fontSize: 22),
                      ),
                      onPressed: () {
                        setState(() => _showEmotePicker = !_showEmotePicker);
                      },
                      tooltip: 'Tepki Gönder',
                    ),
                    const SizedBox(width: 6),

                    // Metin Alanı (Sıra başkasındayken de AÇIKTIR, klavye asla kapanmaz!)
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: TextField(
                          controller: _textController,
                          focusNode: _focusNode,
                          enabled: true, // Asla devre dışı bırakılmaz!
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _submitWord(),
                          style: const TextStyle(
                            color: AppColors.textLight,
                            fontWeight: FontWeight.w700,
                            fontSize: 15.5,
                          ),
                          decoration: InputDecoration(
                            hintText: isUserTurn
                                ? 'Kelime yazın...'
                                : 'Sıranı bekle, önceden yazabilirsin...',
                            hintStyle: TextStyle(
                              color: isUserTurn
                                  ? AppColors.textMuted
                                  : const Color(0xFFEF4444).withValues(alpha: 0.7),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // 3D Gönder Butonu (Sıra yoksa pasiftir)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: isUserTurn ? _submitWord : null,
                        borderRadius: BorderRadius.circular(16),
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: isUserTurn ? 1.0 : 0.35,
                          child: Container(
                            height: 48,
                            width: 48,
                            decoration: BoxDecoration(
                              color: isUserTurn ? const Color(0xFFF59E0B) : const Color(0xFF334155),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: isUserTurn ? const Color(0xFFB45309) : const Color(0xFF1E293B),
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.arrow_upward_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 7. Raunt Arası Düello Brifingi Overlay (Süre Barı & 50 Altın ile Soru Değiştirme)
        if (round.isShowingBriefing)
          _buildRoundBriefingOverlay(context, round, game, profile),
      ],
    ),
  ),
);
  }

  /// 1. Üst Bar: Sadece Çıkış Butonu, Sorunun Kendisi ve Ses İkonu
  Widget _buildTopHeader(BuildContext context, GameRound round, GameController game) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: const Color(0xFF1E293B),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 22),
            onPressed: () => _showQuitDialog(context, game),
            tooltip: 'Maçtan Çık',
          ),
          const SizedBox(width: 4),
          Text(round.category.iconEmoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          // Sadece Sorunun Kendisi (Sade ve Şık)
          Expanded(
            child: Text(
              round.category.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: AppColors.textLight,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(
              SoundService.isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              color: AppColors.textMuted,
              size: 20,
            ),
            onPressed: () {
              setState(() {
                SoundService.toggleMute();
              });
            },
            tooltip: SoundService.isMuted ? 'Sesi Aç' : 'Sesi Kapat',
          ),
        ],
      ),
    );
  }

  /// 2b. Çok Takımlı (2 - 5 Takım) 3D Scoreboard Paneli (Tam sığan, taşma yapmayan responsive düzen)
  Widget _buildTeamsScoreboard(GameRound round) {
    final currentUserId = context.read<ProfileController>().player.id;
    final myTeamId = round.playerTeamMap[currentUserId] ?? round.playerTeamMap[round.player1.id] ?? 'team_1';
    final teamIds = round.teamScores.keys.toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0xFF0F172A), offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: teamIds.map((tId) {
          final isCurrentTurn = round.currentTurnTeamId == tId;
          final isMyTeam = tId == myTeamId;
          final tColor = round.teamColors[tId] ?? const Color(0xFFEF4444);
          final tName = round.teamNames[tId] ?? tId;
          final score = round.teamScores[tId] ?? 0;

          // Takımın aktif oyuncu adı
          String? activePlayerName;
          if (isCurrentTurn) {
            final activeP = round.allPlayers.firstWhere(
              (p) => p.id == round.currentTurnPlayerId,
              orElse: () => round.allPlayers.firstWhere(
                (p) => round.playerTeamMap[p.id] == tId,
                orElse: () => round.player1,
              ),
            );
            activePlayerName = activeP.id == currentUserId ? 'Sen' : activeP.name;
          }

          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
              decoration: BoxDecoration(
                color: isCurrentTurn ? tColor.withValues(alpha: 0.18) : const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isCurrentTurn ? tColor : tColor.withValues(alpha: 0.25),
                  width: isCurrentTurn ? 2 : 1,
                ),
                boxShadow: [
                  if (isCurrentTurn)
                    BoxShadow(
                      color: tColor.withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: tColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          tName,
                          style: TextStyle(
                            fontSize: teamIds.length > 3 ? 10 : 11.5,
                            fontWeight: FontWeight.w800,
                            color: isCurrentTurn ? Colors.white : AppColors.textLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isMyTeam) ...[
                        const SizedBox(width: 2),
                        const Text('🛡️', style: TextStyle(fontSize: 8)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$score',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          color: tColor,
                        ),
                      ),
                      if (isCurrentTurn && activePlayerName != null) ...[
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '($activePlayerName)',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: isCurrentTurn ? tColor : AppColors.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// 2. 3D Kompakt Oyuncular ve Skor Paneli
  /// KURAL: Solda her zaman RAKİP, Sağda o cihazda oynayan OYUNCU gözükür!
  Widget _buildMatchHeader(GameRound round, bool isUserTurn) {
    if (round.isTeamMode) {
      return _buildTeamsScoreboard(round);
    }

    // Takım modu kontrolleri
    final myTeamId = round.playerTeamMap[round.player1.id] ?? 'team_1';
    final rivalTeamIds = round.teamScores.keys.where((t) => t != myTeamId).toList();
    final rivalTeamId = rivalTeamIds.isNotEmpty ? rivalTeamIds.first : 'team_2';

    final rivalScore = round.isTeamMode
        ? (round.teamScores[rivalTeamId] ?? 0)
        : round.player2RoundScore;
    final myScore = round.isTeamMode
        ? (round.teamScores[myTeamId] ?? 0)
        : round.player1RoundScore;

    final rivalTeamColor = round.isTeamMode
        ? (round.teamColors[rivalTeamId] ?? const Color(0xFFEF4444))
        : const Color(0xFFEF4444);
    final myTeamColor = round.isTeamMode
        ? (round.teamColors[myTeamId] ?? const Color(0xFF10B981))
        : const Color(0xFF10B981);

    final rivalName = round.isTeamMode
        ? (round.teamNames[rivalTeamId] ?? 'Rakip Takım')
        : round.player2.name;
    final myName = round.isTeamMode
        ? (round.teamNames[myTeamId] ?? 'Takımım')
        : round.player1.name;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0xFF0F172A), offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // SOLDA: RAKİP (Veya Rakip Takım)
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AvatarBadge(
                  player: round.player2,
                  size: 38,
                  borderColor: !isUserTurn ? rivalTeamColor : Colors.transparent,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        rivalName,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: round.isTeamMode ? rivalTeamColor : AppColors.textLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (round.isTeamMode)
                        Text(
                          'Rakip Takım',
                          style: TextStyle(fontSize: 10, color: rivalTeamColor.withValues(alpha: 0.8), fontWeight: FontWeight.w700),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ORTA: Canlı 3D Skor & Sıra Durumu (Solda Rakip Puanı, Sağda Kullanıcı Puanı)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$rivalScore',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: rivalTeamColor,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        ':',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                    Text(
                      '$myScore',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: myTeamColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isUserTurn ? myTeamColor : rivalTeamColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isUserTurn
                        ? (round.isTeamMode ? 'Sıra Takımında' : 'Sıra Sende')
                        : (round.isTeamMode ? 'Sıra Rakipte' : 'Sıra Rakipte'),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // SAĞDA: KULLANICI (O Cihazda Oynayan / Takımı)
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        myName,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: round.isTeamMode ? myTeamColor : AppColors.textLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (round.isTeamMode)
                        Text(
                          'Benim Takımım',
                          style: TextStyle(fontSize: 10, color: myTeamColor.withValues(alpha: 0.8), fontWeight: FontWeight.w700),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AvatarBadge(
                  player: round.player1,
                  size: 38,
                  isRightAligned: true,
                  borderColor: isUserTurn ? myTeamColor : Colors.transparent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 7. Raunt Arası Düello Brifingi Overlay (Süre Barı & 50 Altın ile Soru Değiştirme)
  Widget _buildRoundBriefingOverlay(
    BuildContext context,
    GameRound round,
    GameController game,
    ProfileController profile,
  ) {
    return Container(
      color: Colors.black.withValues(alpha: 0.88),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: SingleChildScrollView(
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 390),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5), width: 1.5),
            boxShadow: const [
              BoxShadow(color: Colors.black54, offset: Offset(0, 10), blurRadius: 16),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Üst Başlık & Bakiye
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      round.currentRoundNumber == 1
                          ? '⚔️ DÜELLO BRİFİNGİ (RAUNT 1)'
                          : '⚔️ RAUNT ${round.currentRoundNumber} BRİFİNGİ',
                      style: const TextStyle(
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
                          '${profile.coins}',
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
              const SizedBox(height: 16),

              // Soru / Kategori Kartı
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                      round.category.iconEmoji,
                      style: const TextStyle(fontSize: 40),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      round.category.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textLight,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      round.category.description,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted,
                        height: 1.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Brifing Akıcı Süre Barı (60fps continuous + reset support)
              SmoothBriefingTimerBar(
                totalSeconds: round.briefingMaxCountdown,
                resetTrigger: round.hasBriefingCategoryChanged ? 1 : 0,
                onFinished: () {
                  game.endBriefingAndStartNextRound();
                },
              ),
              const SizedBox(height: 16),

              // 🪙 50 Altın ile Soru Değiştirme Butonu (Süre barını tam doldurur)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: round.hasBriefingCategoryChanged
                      ? null
                      : () {
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
                          game.changeBriefingCategory(profile);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Soru değiştirildi ve süre barı yenilendi! 🔄'),
                              backgroundColor: const Color(0xFF10B981),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: round.hasBriefingCategoryChanged ? const Color(0xFF334155) : const Color(0xFFD97706),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: round.hasBriefingCategoryChanged ? const Color(0xFF1E293B) : const Color(0xFF92400E),
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          round.hasBriefingCategoryChanged ? Icons.check_circle_rounded : Icons.change_circle_outlined,
                          size: 20,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          round.hasBriefingCategoryChanged
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
            ],
          ),
        ),
      ),
    );
  }

  /// Alt Bilgilendirme ve Uyarı Barı (Sabit 38px Yükseklik - Kelime Akışını Asla Kaydırmaz)
  Widget _buildBottomFeedbackBanner(GameController game) {
    final msg = game.lastFeedbackMessage;
    return Container(
      height: 38,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      alignment: Alignment.center,
      child: (msg != null && msg.isNotEmpty)
          ? _buildFeedbackChip(msg, game.isLastFeedbackSuccess)
          : const SizedBox.shrink(),
    );
  }

  Widget _buildFeedbackChip(String msg, bool isSuccess) {
    final isAi = msg.contains('🤖') ||
        msg.contains('Yapay Zeka') ||
        msg.contains('Düzeltildi') ||
        msg.contains('✨');

    final Color borderColor = isAi
        ? const Color(0xFF38BDF8)
        : (isSuccess ? const Color(0xFF10B981) : const Color(0xFFF43F5E));

    final Color bgColor = isAi
        ? const Color(0xFF0F172A).withValues(alpha: 0.95)
        : (isSuccess
            ? const Color(0xFF064E3B).withValues(alpha: 0.92)
            : const Color(0xFF4C0519).withValues(alpha: 0.92));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor.withValues(alpha: 0.75), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: borderColor.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isAi) ...[
            const Text('🤖', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
          ] else if (isSuccess) ...[
            const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 15),
            const SizedBox(width: 6),
          ] else ...[
            const Icon(Icons.info_outline_rounded, color: Color(0xFFF43F5E), size: 15),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              msg,
              style: TextStyle(
                color: isAi ? const Color(0xFFE0F2FE) : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Canlı Emote Balonu
  Widget _buildFloatingEmoteBanner(GameController game, GameRound round) {
    final isFromUser = game.userEmote != null;
    final emoji = isFromUser ? game.userEmote! : game.opponentEmote!;
    final senderName = isFromUser ? round.player1.name : round.player2.name;
    final avatarEmoji = isFromUser ? round.player1.avatarEmoji : round.player2.avatarEmoji;
    final color = isFromUser ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(avatarEmoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(
            '$senderName:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            emoji,
            style: const TextStyle(fontSize: 26),
          ),
        ],
      ),
    ).animate().scale(duration: 250.ms, curve: Curves.easeOutBack);
  }

  /// Çıkış Dialogu (Teslim Olunduğunda GameOverScreen'e gider, doğrudan ana menüye atmaz!)
  void _showQuitDialog(BuildContext context, GameController game) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Düellodan Çıkılsın mı?',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textLight),
        ),
        content: const Text(
          'Maçtan ayrılırsanız maçı kaybetmiş sayılacaksınız ve kupa kaybedeceksiniz.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Devam Et', style: TextStyle(color: AppColors.textLight, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              // Hükmen mağlubiyet tetikle (status = finished olur ve GameOverScreen açılır)
              game.surrenderMatch();
            },
            child: const Text(
              'Çık ve Teslim Ol',
              style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
