import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/game_round.dart';
import '../../data/models/word_entry.dart';
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

    // Tüm rauntların listesi (Geçmiş + Eğer son raunt henüz geçmişte yoksa o raunt)
    final List<CompletedRoundSummary> allRounds = [];
    allRounds.addAll(round.roundHistory);
    final hasCurrentInHistory = round.roundHistory.any((h) => h.roundNumber == round.currentRoundNumber);
    if (!hasCurrentInHistory && round.words.isNotEmpty) {
      final roundWinnerId = round.winnerPlayerId ?? (round.isTeamMode ? round.currentTurnTeamId : round.player1.id);
      final winningName = round.isTeamMode
          ? (round.teamNames[round.playerTeamMap[roundWinnerId] ?? roundWinnerId] ?? 'Kazanan Takım')
          : (roundWinnerId == round.player1.id ? round.player1.name : round.player2.name);

      allRounds.add(CompletedRoundSummary(
        roundNumber: round.currentRoundNumber,
        category: round.category,
        winningTeamOrPlayerId: roundWinnerId,
        winningTeamOrPlayerName: winningName,
        words: List<WordEntry>.from(round.words),
        teamScoresAfterRound: round.isTeamMode
            ? round.teamScores
            : {
                round.player1.id: round.player1RoundScore,
                round.player2.id: round.player2RoundScore,
              },
      ));
    }

    // Toplam maç boyunca her oyuncunun ve takımın doğru kelime sayıları
    final Map<String, int> totalPlayerCorrectWords = {};
    final Map<String, int> totalTeamCorrectWords = {};
    for (final r in allRounds) {
      for (final w in r.words.where((entry) => entry.isCorrect)) {
        totalPlayerCorrectWords[w.playerId] = (totalPlayerCorrectWords[w.playerId] ?? 0) + 1;
        final tId = round.playerTeamMap[w.playerId] ?? (w.playerId == round.player1.id ? 'team_1' : 'team_2');
        totalTeamCorrectWords[tId] = (totalTeamCorrectWords[tId] ?? 0) + 1;
      }
    }

    return Column(
      children: [
        // 1. GENEL MAÇ ÖZETİ (Toplam Doğru Kelimeler)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Text('📊 ', style: TextStyle(fontSize: 16)),
                      Text(
                        'GENEL MAÇ İSTATİSTİKLERİ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${allRounds.length} Raunt Oynandı',
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (isMultiOrTeam) ...[
                ...round.teamScores.keys.map((teamId) {
                  final teamColor = round.teamColors[teamId] ?? const Color(0xFF10B981);
                  final teamName = round.teamNames[teamId] ?? 'Takım';
                  final teamPlayers = round.allPlayers
                      .where((p) => round.playerTeamMap[p.id] == teamId)
                      .toList();
                  final totalTeamWords = totalTeamCorrectWords[teamId] ?? 0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
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
                                  width: 9,
                                  height: 9,
                                  decoration: BoxDecoration(color: teamColor, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  teamName,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: teamColor,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: teamColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$totalTeamWords Toplam Doğru',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: teamColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (teamPlayers.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          ...teamPlayers.map((p) {
                            final pTotal = totalPlayerCorrectWords[p.id] ?? 0;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      AvatarBadge(player: p, size: 20),
                                      const SizedBox(width: 6),
                                      Text(
                                        p.name,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '$pTotal doğru',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: teamColor.withValues(alpha: 0.85),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
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
                      wordsCount: totalPlayerCorrectWords[round.player1.id] ?? userWordCount,
                      color: AppColors.playerColor,
                    ),
                    Container(width: 1, height: 40, color: AppColors.cardBorder),
                    _buildPlayerStat(
                      player: round.player2,
                      wordsCount: totalPlayerCorrectWords[round.player2.id] ?? opponentWordCount,
                      color: AppColors.opponentColor,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 2. HER BİR SORU İÇİN DOĞRU KELİMELER DETAYI
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Text('📝 ', style: TextStyle(fontSize: 16)),
                  Text(
                    'SORU VE RAUNT DETAYLARI',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                      color: Color(0xFF38BDF8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Maç boyunca oynanan her soruda verilen doğru cevaplar:',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              const SizedBox(height: 12),

              if (allRounds.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Bu maçta kaydedilen raunt cevabı bulunamadı.',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ),
                )
              else
                ...allRounds.map((rSummary) {
                  final correctWords = rSummary.words.where((w) => w.isCorrect).toList();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Raunt Başlığı & Kazanan
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(rSummary.category.iconEmoji, style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Raunt ${rSummary.roundNumber}: ${rSummary.category.title}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textLight,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '🏆 ${rSummary.winningTeamOrPlayerName} kazandı',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFF59E0B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${correctWords.length} kelime',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),
                        const Divider(color: Color(0xFF1E293B), height: 1),
                        const SizedBox(height: 10),

                        // Doğru kelimeler chip listesi
                        if (correctWords.isEmpty)
                          const Text(
                            'Bu rauntta doğru kelime yazılamadı.',
                            style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textMuted),
                          )
                        else
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: correctWords.map((cw) {
                              final sender = round.allPlayers.firstWhere(
                                (p) => p.id == cw.playerId,
                                orElse: () => cw.playerId == round.player1.id ? round.player1 : round.player2,
                              );
                              final senderTeamId = round.playerTeamMap[cw.playerId] ??
                                  (cw.playerId == round.player1.id ? 'team_1' : 'team_2');
                              final tColor = round.teamColors[senderTeamId] ??
                                  (cw.playerId == round.player1.id ? const Color(0xFF10B981) : const Color(0xFFEF4444));

                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: tColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: tColor.withValues(alpha: 0.4), width: 0.9),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      cw.word,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        color: tColor,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '(${sender.name})',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white.withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
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
