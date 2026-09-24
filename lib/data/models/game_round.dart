import 'package:flutter/material.dart';
import 'category.dart';
import 'player.dart';
import 'word_entry.dart';

enum RoundStatus { waiting, active, paused, finished }

class GameRound {
  final Category category;
  final Player player1;
  final Player player2;
  final String currentTurnPlayerId;
  final int turnDurationSeconds; // Her hamle için verilen standart süre (15 sn)
  final int remainingTurnSeconds; // Mevcut hamlede kalan süre (standart 15 sn)
  final int currentTurnMaxSeconds; // Mevcut hamlenin maksimum süresi (standart 15 sn)
  final List<WordEntry> words;
  final RoundStatus status;
  final String? winnerPlayerId;
  final String? defeatReason; // 'timeout' veya 'surrender'
  final int player1RoundScore; // Oyuncu 1 raunt puanı (0, 1, 2)
  final int player2RoundScore; // Oyuncu 2 raunt puanı (0, 1, 2)
  final int currentRoundNumber; // Kaçıncı raunt (1, 2, 3)
  final int targetWins; // Kaç raunt alan maçı kazanır (varsayılan: 2)

  // Çok Oyunculu & Takımlı Oyun Alanları
  final List<Player> allPlayers;
  final Map<String, String> playerTeamMap; // playerId -> teamId ('team_1', 'team_2')
  final Map<String, int> teamScores; // teamId -> score
  final Map<String, Color> teamColors; // teamId -> Color
  final Map<String, String> teamNames; // teamId -> TeamName
  final String currentTurnTeamId; // Hangi takımın sırası
  final bool isTeamMode;

  // Raunt Arası Düello Brifingi Durumu & Süre Barı
  final bool isShowingBriefing;
  final int briefingCountdown; // Kalan brifing saniyesi (örn: 6)
  final int briefingMaxCountdown; // Toplam brifing saniyesi (örn: 6)
  final bool hasBriefingCategoryChanged;
  // Alıştırma Modu (Bot ile yapılan maçlarda kupa/altın/istatistik değişmez)
  final bool isPracticeBot;

  const GameRound({
    required this.category,
    required this.player1,
    required this.player2,
    required this.currentTurnPlayerId,
    this.turnDurationSeconds = 15,
    this.remainingTurnSeconds = 15,
    this.currentTurnMaxSeconds = 15,
    this.words = const [],
    this.status = RoundStatus.waiting,
    this.winnerPlayerId,
    this.defeatReason,
    this.player1RoundScore = 0,
    this.player2RoundScore = 0,
    this.currentRoundNumber = 1,
    this.targetWins = 2,
    this.allPlayers = const [],
    this.playerTeamMap = const {},
    this.teamScores = const {'team_1': 0, 'team_2': 0},
    this.teamColors = const {
      'team_1': Color(0xFFEF4444),
      'team_2': Color(0xFF0284C7),
    },
    this.teamNames = const {
      'team_1': 'Kırmızı Takım',
      'team_2': 'Mavi Takım',
    },
    this.currentTurnTeamId = 'team_1',
    this.isTeamMode = false,
    this.isShowingBriefing = false,
    this.briefingCountdown = 6,
    this.briefingMaxCountdown = 6,
    this.hasBriefingCategoryChanged = false,
    this.isPracticeBot = false,
  });

  GameRound copyWith({
    Category? category,
    Player? player1,
    Player? player2,
    String? currentTurnPlayerId,
    int? turnDurationSeconds,
    int? remainingTurnSeconds,
    int? currentTurnMaxSeconds,
    List<WordEntry>? words,
    RoundStatus? status,
    String? winnerPlayerId,
    String? defeatReason,
    int? player1RoundScore,
    int? player2RoundScore,
    int? currentRoundNumber,
    int? targetWins,
    List<Player>? allPlayers,
    Map<String, String>? playerTeamMap,
    Map<String, int>? teamScores,
    Map<String, Color>? teamColors,
    Map<String, String>? teamNames,
    String? currentTurnTeamId,
    bool? isTeamMode,
    bool? isShowingBriefing,
    int? briefingCountdown,
    int? briefingMaxCountdown,
    bool? hasBriefingCategoryChanged,
    bool? isPracticeBot,
  }) {
    return GameRound(
      category: category ?? this.category,
      player1: player1 ?? this.player1,
      player2: player2 ?? this.player2,
      currentTurnPlayerId: currentTurnPlayerId ?? this.currentTurnPlayerId,
      turnDurationSeconds: turnDurationSeconds ?? this.turnDurationSeconds,
      remainingTurnSeconds: remainingTurnSeconds ?? this.remainingTurnSeconds,
      currentTurnMaxSeconds: currentTurnMaxSeconds ?? this.currentTurnMaxSeconds,
      words: words ?? this.words,
      status: status ?? this.status,
      winnerPlayerId: winnerPlayerId ?? this.winnerPlayerId,
      defeatReason: defeatReason ?? this.defeatReason,
      player1RoundScore: player1RoundScore ?? this.player1RoundScore,
      player2RoundScore: player2RoundScore ?? this.player2RoundScore,
      currentRoundNumber: currentRoundNumber ?? this.currentRoundNumber,
      targetWins: targetWins ?? this.targetWins,
      allPlayers: allPlayers ?? this.allPlayers,
      playerTeamMap: playerTeamMap ?? this.playerTeamMap,
      teamScores: teamScores ?? this.teamScores,
      teamColors: teamColors ?? this.teamColors,
      teamNames: teamNames ?? this.teamNames,
      currentTurnTeamId: currentTurnTeamId ?? this.currentTurnTeamId,
      isTeamMode: isTeamMode ?? this.isTeamMode,
      isShowingBriefing: isShowingBriefing ?? this.isShowingBriefing,
      briefingCountdown: briefingCountdown ?? this.briefingCountdown,
      briefingMaxCountdown: briefingMaxCountdown ?? this.briefingMaxCountdown,
      hasBriefingCategoryChanged: hasBriefingCategoryChanged ?? this.hasBriefingCategoryChanged,
      isPracticeBot: isPracticeBot ?? this.isPracticeBot,
    );
  }
}
