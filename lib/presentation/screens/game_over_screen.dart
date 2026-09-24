import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/game_round.dart';
import '../controllers/leaderboard_controller.dart';
import '../controllers/profile_controller.dart';
import '../../data/services/multiplayer_service.dart';
import '../widgets/avatar_badge.dart';
import 'custom_room_screen.dart';
import 'home_screen.dart';
import 'matchmaking_screen.dart';

class GameOverScreen extends StatefulWidget {
  final GameRound round;

  const GameOverScreen({super.key, required this.round});

  @override
  State<GameOverScreen> createState() => _GameOverScreenState();
}

class _GameOverScreenState extends State<GameOverScreen> {
  bool _rewardsRecorded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_rewardsRecorded) {
        _rewardsRecorded = true;
        // Bot ile alıştırma yapmak hiçbir şey kaybedip kazandırmaz (kupa, altın, istatistik)
        if (!widget.round.isPracticeBot) {
          final userTeamId = widget.round.playerTeamMap[widget.round.player1.id] ?? 'team_1';
          final bool isWon = widget.round.isTeamMode
              ? (widget.round.teamScores[userTeamId] ?? 0) >= widget.round.targetWins
              : widget.round.winnerPlayerId == widget.round.player1.id;
          final profile = context.read<ProfileController>();
          profile.recordMatchResult(won: isWon);

          // Liderlik tablosuna kaydet
          context.read<LeaderboardController>().syncScoreToSupabase(
                username: profile.player.name,
                trophies: profile.player.trophies,
              );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final round = widget.round;
    final userTeamId = round.playerTeamMap[round.player1.id] ?? 'team_1';
    final bool isWon = round.isTeamMode
        ? (round.teamScores[userTeamId] ?? 0) >= round.targetWins
        : round.winnerPlayerId == round.player1.id;
    final bool isTimeout = round.defeatReason == 'timeout';

    final int userWordCount = round.words
        .where((w) => w.isCorrect && w.playerId == round.player1.id)
        .length;
    final int opponentWordCount = round.words
        .where((w) => w.isCorrect && w.playerId == round.player2.id)
        .length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _navigateToHome(context);
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Galibiyet / Yenilgi Banner
                  _buildOutcomeBanner(isWon, isTimeout)
                      .animate()
                      .scale(duration: 400.ms, curve: Curves.easeOutBack),
                  const SizedBox(height: 24),

                  // Kupa Değişim Kartı (Alıştırma modunda kupa/altın etkilenmez)
                  (round.isPracticeBot
                          ? _buildPracticeBannerCard()
                          : _buildTrophyRewardCard(isWon))
                      .animate()
                      .fadeIn(delay: 150.ms),
                  const SizedBox(height: 16),

                  // Final Maç Skoru (Örn: 2 - 1)
                  _buildMatchScoreCard(round)
                      .animate()
                      .fadeIn(delay: 200.ms),
                  const SizedBox(height: 16),

                  // Düello Kelime İstatistikleri
                  _buildSummaryCard(round, userWordCount, opponentWordCount)
                      .animate()
                      .fadeIn(delay: 250.ms),
                  const SizedBox(height: 32),

                  // Aksiyon Butonları
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _navigateToHome(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textLight,
                            side: const BorderSide(color: AppColors.cardBorder, width: 1.2),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Ana Menü', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _handleReplay(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Tekrar Oyna', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToHome(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  void _handleReplay(BuildContext context) {
    if (widget.round.isPracticeBot) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const MatchmakingScreen(isPracticeBot: true),
        ),
      );
    } else if (MultiplayerService.isInRoom || widget.round.isTeamMode) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const CustomRoomScreen()),
        (route) => route.isFirst,
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const MatchmakingScreen(isPracticeBot: false),
        ),
      );
    }
  }

  Widget _buildPracticeBannerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.5), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Text('🤖', style: TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alıştırma Maçı (Sıfır Risk)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF38BDF8),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Alıştırma maçlarında kupa, altın veya istatistik değişmez.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutcomeBanner(bool isWon, bool isTimeout) {
    String title = isWon ? 'ZAFER!' : 'YENİLGİ!';
    String icon = isWon ? '🏆' : '⌛';
    Color color = isWon ? AppColors.accentGreen : AppColors.opponentColor;

    String subtitle = '';
    if (isWon) {
      subtitle = isTimeout ? 'Rakibin süresi doldu, maçı kazandınız!' : 'Mükemmel bir mücadele!';
    } else {
      subtitle = isTimeout ? 'Süreniz doldu ve elendiniz!' : 'Maçı kaybettiniz.';
    }

    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 54)),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textMuted,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildTrophyRewardCard(bool isWon) {
    final trophyText = isWon ? '+30 Kupa' : '-15 Kupa';
    final Color trophyColor = isWon ? AppColors.primaryLight : AppColors.opponentColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🏆 ', style: TextStyle(fontSize: 16)),
          Text(
            trophyText,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: trophyColor,
            ),
          ),
          const SizedBox(width: 20),
          const Text('🪙 ', style: TextStyle(fontSize: 16)),
          Text(
            isWon ? '+100 Altın' : '+25 Altın',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchScoreCard(GameRound round) {
    if (round.isTeamMode && round.teamScores.isNotEmpty) {
      final teamIds = round.teamScores.keys.toList();
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          children: [
            const Text(
              'MAÇ SKORU',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: teamIds.map((tId) {
                final tName = round.teamNames[tId] ?? tId;
                final tColor = round.teamColors[tId] ?? AppColors.primary;
                final score = round.teamScores[tId] ?? 0;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: tColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: tColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: tColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(tName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: tColor)),
                      const SizedBox(width: 8),
                      Text('$score', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: tColor)),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 6),
            Text(
              'İlk ${round.targetWins} Raunt Kazanan Şampiyon',
              style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          const Text(
            'MAÇ SKORU',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${round.player1RoundScore}',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.playerColor,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  '-',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              Text(
                '${round.player2RoundScore}',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.opponentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Toplam ${round.targetWins} Raunt Kazanan Şampiyon',
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(GameRound round, int userWordCount, int opponentWordCount) {
    final bool isMultiOrTeam = round.isTeamMode || round.allPlayers.length > 2;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(round.category.iconEmoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  round.category.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (isMultiOrTeam) ...[
            // Bütün takımlar ve her bir oyuncunun doğru kelime sayısı
            ...round.teamScores.keys.map((teamId) {
              final teamColor = round.teamColors[teamId] ?? const Color(0xFF10B981);
              final teamName = round.teamNames[teamId] ?? 'Takım';
              final teamPlayers = round.allPlayers
                  .where((p) => round.playerTeamMap[p.id] == teamId)
                  .toList();
              final teamWordCount = round.words
                  .where((w) => w.isCorrect && round.playerTeamMap[w.playerId] == teamId)
                  .length;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: teamColor.withValues(alpha: 0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(color: teamColor, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              teamName,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: teamColor,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '$teamWordCount Doğru',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: teamColor,
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Color(0xFF1E293B), height: 16),
                    ...teamPlayers.map((p) {
                      final pWordCount = round.words
                          .where((w) => w.isCorrect && w.playerId == p.id)
                          .length;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                AvatarBadge(player: p, size: 24),
                                const SizedBox(width: 8),
                                Text(
                                  p.name,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textLight,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '$pWordCount Doğru Kelime',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: teamColor.withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              );
            }),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildPlayerStat(
                  player: round.player1,
                  wordsCount: userWordCount,
                  color: AppColors.playerColor,
                ),
                Container(width: 1, height: 40, color: AppColors.cardBorder),
                _buildPlayerStat(
                  player: round.player2,
                  wordsCount: opponentWordCount,
                  color: AppColors.opponentColor,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlayerStat({
    required dynamic player,
    required int wordsCount,
    required Color color,
  }) {
    return Column(
      children: [
        AvatarBadge(player: player, size: 38),
        const SizedBox(height: 6),
        Text(
          player.name,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textLight),
        ),
        const SizedBox(height: 2),
        Text(
          '$wordsCount Doğru Kelime',
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }
}
