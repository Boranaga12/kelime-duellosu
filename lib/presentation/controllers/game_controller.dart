import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/services/sound_service.dart';
import '../../core/utils/turkish_strings.dart';
import '../../data/categories_data.dart';
import '../../data/models/category.dart';
import '../../data/models/custom_room.dart';
import '../../data/models/game_round.dart';
import '../../data/models/player.dart';
import '../../data/models/word_entry.dart';
import '../../data/services/multiplayer_service.dart';
import '../../domain/bot_ai_engine.dart';
import '../../domain/word_engine.dart';

class GameController extends ChangeNotifier {
  GameRound? _round;
  Timer? _timer;
  final BotAiEngine _botEngine = BotAiEngine();

  String? _lastFeedbackMessage;
  bool _isLastFeedbackSuccess = true;
  String? _currentHint;

  // Canlı Emote Alanları
  String? _userEmote;
  String? _opponentEmote;
  Timer? _userEmoteTimer;
  Timer? _opponentEmoteTimer;

  Timer? _briefingTimer;
  Timer? _feedbackTimer;

  void setFeedbackMessage(String msg, bool isSuccess) {
    _feedbackTimer?.cancel();
    _lastFeedbackMessage = msg;
    _isLastFeedbackSuccess = isSuccess;
    notifyListeners();

    _feedbackTimer = Timer(const Duration(milliseconds: 3200), () {
      _lastFeedbackMessage = null;
      notifyListeners();
    });
  }

  GameRound? get round => _round;
  @visibleForTesting
  set round(GameRound? val) => _round = val;
  String? get lastFeedbackMessage => _lastFeedbackMessage;
  bool get isLastFeedbackSuccess => _isLastFeedbackSuccess;
  String? get currentHint => _currentHint;
  String? get userEmote => _userEmote;
  String? get opponentEmote => _opponentEmote;

  bool get isGameActive =>
      _round != null && _round!.status == RoundStatus.active;

  bool get isUserTurn {
    if (_round == null || _round!.status != RoundStatus.active || _round!.isShowingBriefing) {
      return false;
    }
    if (_round!.isTeamMode) {
      final userTeam = _round!.playerTeamMap[_round!.player1.id];
      return userTeam != null && userTeam == _round!.currentTurnTeamId;
    }
    return _round!.currentTurnPlayerId == _round!.player1.id;
  }

  String get currentTurnPlayerName {
    if (_round == null) return '';
    if (_round!.isTeamMode) {
      return _round!.teamNames[_round!.currentTurnTeamId] ?? 'Takım Sırası';
    }
    return _round!.currentTurnPlayerId == _round!.player1.id
        ? _round!.player1.name
        : _round!.player2.name;
  }

  /// Yeni düello başlatır (Standart 15 sn, 2 kat süre kaldırıldı)
  void startNewGame({
    required Category category,
    required Player userPlayer,
    Player? opponentPlayer,
    int turnDurationSeconds = 15,
    bool isPracticeBot = false,
    bool showBriefing = false,
  }) {
    _timer?.cancel();
    _briefingTimer?.cancel();
    _botEngine.stop();
    _userEmoteTimer?.cancel();
    _opponentEmoteTimer?.cancel();

    final opponent = opponentPlayer ?? BotAiEngine.generateBotPlayer();
    final startingPlayerId = userPlayer.id;

    _round = GameRound(
      category: category,
      player1: userPlayer,
      player2: opponent,
      currentTurnPlayerId: startingPlayerId,
      turnDurationSeconds: turnDurationSeconds,
      remainingTurnSeconds: turnDurationSeconds,
      currentTurnMaxSeconds: turnDurationSeconds,
      status: RoundStatus.active,
      player1RoundScore: 0,
      player2RoundScore: 0,
      currentRoundNumber: 1,
      targetWins: 2,
      allPlayers: [userPlayer, opponent],
      playerTeamMap: {userPlayer.id: 'team_1', opponent.id: 'team_2'},
      teamScores: {'team_1': 0, 'team_2': 0},
      teamColors: const {
        'team_1': Color(0xFF10B981),
        'team_2': Color(0xFFEF4444),
      },
      teamNames: {
        'team_1': userPlayer.name,
        'team_2': opponent.name,
      },
      currentTurnTeamId: 'team_1',
      isTeamMode: false,
      isShowingBriefing: showBriefing,
      briefingCountdown: 6,
      briefingMaxCountdown: 6,
      hasBriefingCategoryChanged: false,
      isPracticeBot: isPracticeBot,
    );

    _currentHint = null;
    _userEmote = null;
    _opponentEmote = null;
    _lastFeedbackMessage = null;
    _isLastFeedbackSuccess = true;

    SoundService.playTurnSwitch();
    notifyListeners();

    if (showBriefing) {
      _startBriefingTimer();
    } else {
      _startTurnTimer();
    }
  }

  /// 1 saniyelik sayaç döngüsü
  void _startTurnTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_round == null || _round!.status != RoundStatus.active) {
        timer.cancel();
        return;
      }

      // Son 4 saniyede kritik uyarı sesi
      if (_round!.remainingTurnSeconds <= 4 && _round!.remainingTurnSeconds > 1) {
        SoundService.playUrgentTick();
      }

      // Tur süresi kontrolü
      if (_round!.remainingTurnSeconds <= 1) {
        _handleTurnTimeout();
      } else {
        _round = _round!.copyWith(
          remainingTurnSeconds: _round!.remainingTurnSeconds - 1,
        );
        notifyListeners();
      }
    });
  }

  /// Çok oyunculu ve takımlı özel oda oyunu başlatır
  void startTeamOrCustomGame({
    required CustomRoom room,
    required Player userPlayer,
    required Category category,
    bool showBriefing = false,
  }) {
    _timer?.cancel();
    _briefingTimer?.cancel();
    _botEngine.stop();
    _userEmoteTimer?.cancel();
    _opponentEmoteTimer?.cancel();

    final allPlayers = room.players.map((rp) => Player(
      id: rp.id,
      name: rp.name,
      tag: rp.tag,
      avatarEmoji: rp.avatarEmoji,
      avatarUrl: rp.avatarUrl,
      botWrongAnswers: rp.isBot ? BotAiEngine.getWrongAnswersForBot(rp.name) : null,
      trophies: rp.trophies,
      level: rp.level,
      isBot: rp.isBot,
    )).toList();

    final bool effectiveTeamMode = true;

    final Map<String, String> playerTeamMap = room.isTeamMode
        ? {for (var rp in room.players) rp.id: rp.teamId}
        : {for (var rp in room.players) rp.id: 'team_${rp.id}'};

    final Map<String, int> teamScores = room.isTeamMode
        ? {for (var t in room.teams) t.id: 0}
        : {for (var rp in room.players) 'team_${rp.id}': 0};

    final Map<String, Color> teamColors = room.isTeamMode
        ? {for (var t in room.teams) t.id: t.color}
        : {for (var rp in room.players) 'team_${rp.id}': rp.effectiveColor};

    final Map<String, String> teamNames = room.isTeamMode
        ? {for (var t in room.teams) t.id: t.name}
        : {for (var rp in room.players) 'team_${rp.id}': rp.name};

    final userTeamId = playerTeamMap[userPlayer.id] ??
        (room.isTeamMode && room.teams.isNotEmpty
            ? room.teams.first.id
            : 'team_${userPlayer.id}');

    final opponentCandidate = allPlayers.firstWhere(
      (p) => (playerTeamMap[p.id] ?? '') != userTeamId,
      orElse: () => allPlayers.firstWhere((p) => p.id != userPlayer.id, orElse: () => BotAiEngine.generateBotPlayer()),
    );

    final firstTeamId = room.isTeamMode
        ? (room.teams.isNotEmpty ? room.teams.first.id : 'team_1')
        : (room.players.isNotEmpty ? 'team_${room.players.first.id}' : 'team_${userPlayer.id}');

    final firstPlayerId = room.isTeamMode
        ? userPlayer.id
        : (room.players.isNotEmpty ? room.players.first.id : userPlayer.id);

    _round = GameRound(
      category: category,
      player1: userPlayer,
      player2: opponentCandidate,
      currentTurnPlayerId: firstPlayerId,
      turnDurationSeconds: 15,
      remainingTurnSeconds: 15,
      currentTurnMaxSeconds: 15,
      status: RoundStatus.active,
      player1RoundScore: 0,
      player2RoundScore: 0,
      currentRoundNumber: 1,
      targetWins: room.targetWins,
      allPlayers: allPlayers,
      playerTeamMap: playerTeamMap,
      teamScores: teamScores,
      teamColors: teamColors,
      teamNames: teamNames,
      currentTurnTeamId: firstTeamId,
      isTeamMode: effectiveTeamMode,
      isShowingBriefing: showBriefing,
      briefingCountdown: 6,
      briefingMaxCountdown: 6,
      hasBriefingCategoryChanged: false,
    );

    _currentHint = null;
    _userEmote = null;
    _opponentEmote = null;
    _lastFeedbackMessage = null;
    _isLastFeedbackSuccess = true;

    SoundService.playTurnSwitch();
    notifyListeners();

    if (showBriefing) {
      _startBriefingTimer();
    } else {
      _startTurnTimer();
      _checkAndTriggerBotTurn();
    }
  }

  /// Süresi dolan oyuncu/takım raundu kaybeder, diğer taraf +1 puan alır
  void _handleTurnTimeout() {
    _timer?.cancel();
    _botEngine.stop();

    if (_round == null) return;

    if (_round!.isTeamMode) {
      final timedOutTeamId = _round!.currentTurnTeamId;
      final correctEntries = _round!.words.where((w) => w.isCorrect).toList();
      String winningTeamId;
      if (correctEntries.isNotEmpty) {
        final lastPlayerId = correctEntries.first.playerId;
        winningTeamId = _round!.playerTeamMap[lastPlayerId] ?? timedOutTeamId;
        if (winningTeamId == timedOutTeamId) {
          final otherTeamIds = _round!.teamScores.keys.where((t) => t != timedOutTeamId).toList();
          winningTeamId = otherTeamIds.isNotEmpty ? otherTeamIds.first : timedOutTeamId;
        }
      } else {
        final teamIds = _round!.teamScores.keys.toList();
        final nextIdx = (teamIds.indexOf(timedOutTeamId) + 1) % teamIds.length;
        winningTeamId = teamIds[nextIdx];
      }

      final updatedScores = Map<String, int>.from(_round!.teamScores);
      final newScore = (updatedScores[winningTeamId] ?? 0) + 1;
      updatedScores[winningTeamId] = newScore;

      final userTeamId = _round!.playerTeamMap[_round!.player1.id] ?? 'team_1';
      final winningTeamName = _round!.teamNames[winningTeamId] ?? 'Rakip Takım';

      if (newScore >= _round!.targetWins) {
        final isUserWinner = winningTeamId == userTeamId;
        if (isUserWinner) {
          SoundService.playVictory();
          _lastFeedbackMessage = 'Tebrikler! $winningTeamName maçı kazandı! 🏆';
          _isLastFeedbackSuccess = true;
        } else {
          SoundService.playDefeat();
          _lastFeedbackMessage = 'Maçı $winningTeamName kazandı! ⌛';
          _isLastFeedbackSuccess = false;
        }

        _round = _round!.copyWith(
          remainingTurnSeconds: 0,
          teamScores: updatedScores,
          status: RoundStatus.finished,
          defeatReason: 'timeout',
          winnerPlayerId: isUserWinner ? _round!.player1.id : _round!.player2.id,
        );

        notifyListeners();
        return;
      }

      // Maç bitmedi -> Yeni Raunt Brifingine Geçiş
      SoundService.playIncorrect();
      final nextRoundNumber = _round!.currentRoundNumber + 1;

      final otherCategories =
          sampleCategories.where((c) => c.id != _round!.category.id).toList();
      final nextCategory = otherCategories.isNotEmpty
          ? otherCategories[Random().nextInt(otherCategories.length)]
          : _round!.category;

      _round = _round!.copyWith(
        category: nextCategory,
        teamScores: updatedScores,
        currentRoundNumber: nextRoundNumber,
        currentTurnTeamId: timedOutTeamId,
        remainingTurnSeconds: _round!.turnDurationSeconds,
        currentTurnMaxSeconds: _round!.turnDurationSeconds,
        words: [],
        isShowingBriefing: true,
        briefingCountdown: 6,
        briefingMaxCountdown: 6,
        hasBriefingCategoryChanged: false,
      );

      _currentHint = null;
      notifyListeners();

      _startBriefingTimer();
      return;
    }

    // 1v1 Modu
    final timedOutPlayerId = _round!.currentTurnPlayerId;
    final isPlayer1TimedOut = timedOutPlayerId == _round!.player1.id;

    // Süresi bitmeyen oyuncu +1 raunt puanı kazanır
    final newP1Score = isPlayer1TimedOut
        ? _round!.player1RoundScore
        : _round!.player1RoundScore + 1;
    final newP2Score = isPlayer1TimedOut
        ? _round!.player2RoundScore + 1
        : _round!.player2RoundScore;

    final roundWinnerName =
        isPlayer1TimedOut ? _round!.player2.name : _round!.player1.name;

    // Hedef galibiyet kontrolü
    if (newP1Score >= _round!.targetWins || newP2Score >= _round!.targetWins) {
      final winnerPlayerId = newP1Score >= _round!.targetWins
          ? _round!.player1.id
          : _round!.player2.id;
      final isUserWinner = winnerPlayerId == _round!.player1.id;

      if (isUserWinner) {
        SoundService.playVictory();
        _lastFeedbackMessage =
            'Tebrikler! Maçı $newP1Score - $newP2Score kazandınız! 🏆';
        _isLastFeedbackSuccess = true;
      } else {
        SoundService.playDefeat();
        _lastFeedbackMessage =
            'Maçı rakip $newP2Score - $newP1Score kazandı! ⌛';
        _isLastFeedbackSuccess = false;
      }

      _round = _round!.copyWith(
        remainingTurnSeconds: 0,
        player1RoundScore: newP1Score,
        player2RoundScore: newP2Score,
        status: RoundStatus.finished,
        winnerPlayerId: winnerPlayerId,
        defeatReason: 'timeout',
      );

      notifyListeners();
      return;
    }

    // Maç bitmedi -> Yeni Raunt Düello Brifingi Açılır
    SoundService.playIncorrect();
    final nextRoundNumber = _round!.currentRoundNumber + 1;
    _lastFeedbackMessage =
        '$roundWinnerName raundu kazandı! Durum: $newP1Score - $newP2Score 🎯';
    _isLastFeedbackSuccess = !isPlayer1TimedOut;

    final otherCategories =
        sampleCategories.where((c) => c.id != _round!.category.id).toList();
    final nextCategory = otherCategories.isNotEmpty
        ? otherCategories[Random().nextInt(otherCategories.length)]
        : _round!.category;

    final nextStartingPlayerId = timedOutPlayerId;

    _round = _round!.copyWith(
      category: nextCategory,
      player1RoundScore: newP1Score,
      player2RoundScore: newP2Score,
      currentRoundNumber: nextRoundNumber,
      currentTurnPlayerId: nextStartingPlayerId,
      remainingTurnSeconds: _round!.turnDurationSeconds,
      currentTurnMaxSeconds: _round!.turnDurationSeconds,
      words: [],
      isShowingBriefing: true,
      briefingCountdown: 6,
      briefingMaxCountdown: 6,
      hasBriefingCategoryChanged: false,
    );

    _currentHint = null;
    notifyListeners();

    _startBriefingTimer();
  }

  /// Raunt arası brifing geri sayımı
  void _startBriefingTimer() {
    _timer?.cancel();
    _botEngine.stop();
    _briefingTimer?.cancel();

    _briefingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_round == null || !_round!.isShowingBriefing) {
        timer.cancel();
        return;
      }

      if (_round!.briefingCountdown <= 1) {
        timer.cancel();
        endBriefingAndStartNextRound();
      } else {
        _round = _round!.copyWith(
          briefingCountdown: _round!.briefingCountdown - 1,
        );
        notifyListeners();
      }
    });
  }

  void endBriefingAndStartNextRound() {
    _briefingTimer?.cancel();
    if (_round == null) return;

    _round = _round!.copyWith(
      isShowingBriefing: false,
      remainingTurnSeconds: _round!.turnDurationSeconds,
      currentTurnMaxSeconds: _round!.turnDurationSeconds,
      words: [],
    );

    SoundService.playTurnSwitch();
    notifyListeners();

    _startTurnTimer();
    _checkAndTriggerBotTurn();
  }

  /// Brifing ekranında 50 altın harcayarak soruyu değiştirir ve süre barını tekrar doldurur!
  bool changeBriefingCategory(dynamic profile) {
    if (_round == null || !_round!.isShowingBriefing || _round!.hasBriefingCategoryChanged) {
      return false;
    }

    if (profile.coins < 50) {
      return false;
    }

    final spent = profile.spendCoins(50);
    if (!spent) return false;

    final otherCategories =
        sampleCategories.where((c) => c.id != _round!.category.id).toList();
    final nextCategory = otherCategories.isNotEmpty
        ? otherCategories[Random().nextInt(otherCategories.length)]
        : _round!.category;

    // Soru değiştiğinde süre barı tekrar tam dolsun (briefingMaxCountdown)
    _round = _round!.copyWith(
      category: nextCategory,
      briefingCountdown: _round!.briefingMaxCountdown,
      hasBriefingCategoryChanged: true,
    );

    SoundService.playCorrect();
    notifyListeners();
    return true;
  }

  /// Brifing beklemeden hemen başlat
  void skipBriefingAndStart() {
    endBriefingAndStartNextRound();
  }

  /// Kullanıcı kelime gönderdiğinde (Yapay Zeka Hakemi & Kendini Geliştiren Havuz Destekli)
  Future<WordValidationResult> submitPlayerWord(String word) async {
    if (!isGameActive || _round == null) {
      return const WordValidationResult(
        status: WordValidationStatus.invalid,
        matchedWord: '',
        message: 'Oyun aktif değil!',
      );
    }

    if (!isUserTurn) {
      return const WordValidationResult(
        status: WordValidationStatus.invalid,
        matchedWord: '',
        message: 'Şu an sizin sıranız değil!',
      );
    }

    final rawWord = word.trim();
    if (rawWord.isEmpty) {
      return const WordValidationResult(
        status: WordValidationStatus.invalid,
        matchedWord: '',
        message: 'Lütfen bir kelime yazın!',
      );
    }

    final usedWords = _round!.words
        .where((w) => w.isCorrect)
        .map((w) => w.word)
        .toSet();

    // 1. Önce hızlı yerel kontrol ve ardından gerekiyorsa Yapay Zeka Hakemi & Havuz Öğrenme
    final result = await WordEngine.validateWordAsync(
      rawInput: rawWord,
      category: _round!.category,
      alreadyUsedWords: usedWords,
    );

    // Eğer o sırada oyun bittiyse veya raunt değiştiyse güvenli çıkış
    if (!isGameActive || _round == null) return result;

    if (result.isValid) {
      SoundService.playCorrect();
      setFeedbackMessage(result.message, true);

      final newEntry = WordEntry(
        word: result.matchedWord,
        playerId: _round!.player1.id,
        isCorrect: true,
        timestamp: DateTime.now(),
        originalTypo: result.originalInput,
        isAiApproved: result.isAiApproved,
        aiExplanation: result.aiExplanation,
      );

      final updatedWords = List<WordEntry>.from(_round!.words)..insert(0, newEntry);
      _round = _round!.copyWith(words: updatedWords);

      if (MultiplayerService.isInRoom) {
        MultiplayerService.broadcastWord(
          word: result.matchedWord,
          isCorrect: true,
          playerId: _round!.player1.id,
          originalTypo: result.originalInput,
        );
      }

      // Takım modunda da sırayı rakip takıma devreder!
      _switchTurn();
    } else {
      SoundService.playIncorrect();
      if (result.status == WordValidationStatus.alreadyUsed) {
        setFeedbackMessage('⚠️ "${result.matchedWord}" daha önceden yazıldı!', false);
      } else {
        setFeedbackMessage('${result.message} Tekrar dene!', false);
      }

      final newEntry = WordEntry(
        word: rawWord,
        playerId: _round!.player1.id,
        isCorrect: false,
        timestamp: DateTime.now(),
      );

      final updatedWords = List<WordEntry>.from(_round!.words)..insert(0, newEntry);
      _round = _round!.copyWith(words: updatedWords);

      if (MultiplayerService.isInRoom) {
        MultiplayerService.broadcastWord(
          word: rawWord,
          isCorrect: false,
          playerId: _round!.player1.id,
        );
      }

      notifyListeners();
    }

    return result;
  }

  /// Canlı Rakip veya Takım Arkadaşı (Realtime Network) kelimesini işle
  void submitRemoteWord({
    required String word,
    required bool isCorrect,
    required String playerId,
    String? originalTypo,
  }) {
    if (!isGameActive || _round == null) return;

    final newEntry = WordEntry(
      word: word,
      playerId: playerId,
      isCorrect: isCorrect,
      timestamp: DateTime.now(),
      originalTypo: originalTypo,
    );

    final updatedWords = List<WordEntry>.from(_round!.words)..insert(0, newEntry);
    _round = _round!.copyWith(words: updatedWords);

    if (isCorrect) {
      SoundService.playCorrect();
      _switchTurn();
    } else {
      SoundService.playIncorrect();
      notifyListeners();
    }
  }

  /// Canlı Rakip kelimesini işle (Geriye uyumluluk)
  void submitOpponentRemoteWord(String word, {required bool isCorrect}) {
    if (_round == null) return;
    submitRemoteWord(
      word: word,
      isCorrect: isCorrect,
      playerId: _round!.player2.id,
    );
  }

  /// Bot rakip kelimesini işle (1v1)
  void _submitOpponentBotWord(String word) {
    if (!isGameActive || _round == null) return;
    if (_round!.currentTurnPlayerId != _round!.player2.id) return;

    final usedWords = _round!.words
        .where((w) => w.isCorrect)
        .map((w) => w.word)
        .toSet();

    final result = WordEngine.validateWord(
      rawInput: word,
      category: _round!.category,
      alreadyUsedWords: usedWords,
    );

    if (result.isValid) {
      submitOpponentRemoteWord(result.matchedWord, isCorrect: true);
    } else {
      submitOpponentRemoteWord(word, isCorrect: false);
    }
  }

  /// Bot oyuncu kelimesi işle (Takımlı veya bireysel botlar)
  void _submitBotWordForPlayer(Player botPlayer, String word) {
    if (!isGameActive || _round == null) return;
    if (_round!.isTeamMode && _round!.playerTeamMap[botPlayer.id] != _round!.currentTurnTeamId) return;

    final usedWords = _round!.words
        .where((w) => w.isCorrect)
        .map((w) => w.word)
        .toSet();

    final result = WordEngine.validateWord(
      rawInput: word,
      category: _round!.category,
      alreadyUsedWords: usedWords,
    );

    final newEntry = WordEntry(
      word: result.isValid ? result.matchedWord : word,
      playerId: botPlayer.id,
      isCorrect: result.isValid,
      timestamp: DateTime.now(),
    );

    final updatedWords = List<WordEntry>.from(_round!.words)..insert(0, newEntry);
    _round = _round!.copyWith(words: updatedWords);

    if (result.isValid) {
      SoundService.playCorrect();
      _switchTurn();
    } else {
      SoundService.playIncorrect();
      notifyListeners();
    }
  }

  /// Bot sırasını denetler ve gerekirse bot hamlesini başlatır
  void _checkAndTriggerBotTurn() {
    if (_round == null || _round!.status != RoundStatus.active || _round!.isShowingBriefing) return;

    if (_round!.isTeamMode) {
      final currentTeam = _round!.currentTurnTeamId;
      final botsInCurrentTeam = _round!.allPlayers.where(
        (p) => p.isBot && _round!.playerTeamMap[p.id] == currentTeam,
      ).toList();

      if (botsInCurrentTeam.isNotEmpty) {
        final botPlayer = botsInCurrentTeam[Random().nextInt(botsInCurrentTeam.length)];
        _botEngine.playTurn(
          category: _round!.category,
          botPlayer: botPlayer,
          getAlreadyUsedWords: () {
            return _round?.words.where((w) => w.isCorrect).map((w) => w.word).toSet() ?? {};
          },
          onWordSelected: (word) {
            _submitBotWordForPlayer(botPlayer, word);
          },
          isGameActive: () => isGameActive && _round?.currentTurnTeamId == currentTeam,
        );
      }
    } else {
      if (_round!.currentTurnPlayerId == _round!.player2.id && _round!.player2.isBot) {
        _botEngine.playTurn(
          category: _round!.category,
          botPlayer: _round!.player2,
          getAlreadyUsedWords: () {
            return _round?.words.where((w) => w.isCorrect).map((w) => w.word).toSet() ?? {};
          },
          onWordSelected: (word) {
            _submitOpponentBotWord(word);
          },
          isGameActive: () => isGameActive && _round?.currentTurnPlayerId == _round?.player2.id,
        );
      }
    }
  }

  /// Sırayı diğer oyuncuya veya takıma devreder
  void _switchTurn() {
    if (_round == null || _round!.status != RoundStatus.active) return;

    if (_round!.isTeamMode) {
      final teamIds = _round!.teamScores.keys.toList();
      if (teamIds.isNotEmpty) {
        final currentIndex = teamIds.indexOf(_round!.currentTurnTeamId);
        final nextIndex = (currentIndex + 1) % teamIds.length;
        final nextTeamId = teamIds[nextIndex];

        final playersInNextTeam = _round!.allPlayers.where(
          (p) => _round!.playerTeamMap[p.id] == nextTeamId,
        ).toList();
        final nextPlayerId = playersInNextTeam.isNotEmpty
            ? playersInNextTeam.first.id
            : _round!.currentTurnPlayerId;

        _round = _round!.copyWith(
          currentTurnTeamId: nextTeamId,
          currentTurnPlayerId: nextPlayerId,
          remainingTurnSeconds: _round!.turnDurationSeconds,
          currentTurnMaxSeconds: _round!.turnDurationSeconds,
        );

        SoundService.playTurnSwitch();
        notifyListeners();

        _checkAndTriggerBotTurn();
        return;
      }
    }

    final nextTurnPlayerId = _round!.currentTurnPlayerId == _round!.player1.id
        ? _round!.player2.id
        : _round!.player1.id;

    _round = _round!.copyWith(
      currentTurnPlayerId: nextTurnPlayerId,
      remainingTurnSeconds: _round!.turnDurationSeconds,
      currentTurnMaxSeconds: _round!.turnDurationSeconds,
    );

    SoundService.playTurnSwitch();
    notifyListeners();

    _checkAndTriggerBotTurn();
  }

  /// Oyuncu teslim olduğunda / oyundan çıktığında hükmen yenilgi
  void surrenderMatch() {
    _timer?.cancel();
    _botEngine.stop();

    if (_round == null) return;

    SoundService.playDefeat();
    _round = _round!.copyWith(
      remainingTurnSeconds: 0,
      status: RoundStatus.finished,
      winnerPlayerId: _round!.player2.id,
      defeatReason: 'surrender',
    );
    _lastFeedbackMessage = 'Maçtan çekildiniz ve hükmen mağlup sayıldınız! 🏳️';
    _isLastFeedbackSuccess = false;
    notifyListeners();
  }

  /// Kullanıcı Emote Gönderdiğinde
  void sendUserEmote(String emoji) {
    _userEmote = emoji;
    notifyListeners();

    if (MultiplayerService.isInRoom && _round != null) {
      MultiplayerService.broadcastEmote(emoji: emoji, senderId: _round!.player1.id);
    }

    _userEmoteTimer?.cancel();
    _userEmoteTimer = Timer(const Duration(milliseconds: 2400), () {
      _userEmote = null;
      notifyListeners();
    });
  }

  /// Rakip Emote Gönderdiğinde
  void triggerRemoteEmote(String emoji) {
    _opponentEmote = emoji;
    notifyListeners();

    _opponentEmoteTimer?.cancel();
    _opponentEmoteTimer = Timer(const Duration(milliseconds: 2400), () {
      _opponentEmote = null;
      notifyListeners();
    });
  }

  /// Joker: +5 saniye
  void applyFreezeTime() {
    if (!isGameActive || _round == null) return;
    _round = _round!.copyWith(
      remainingTurnSeconds: _round!.remainingTurnSeconds + 5,
    );
    setFeedbackMessage('+5 Saniye Eklendi ❄️', true);
  }

  /// Joker: İpucu
  void applyHint() {
    if (!isGameActive || _round == null) return;
    final usedWords = _round!.words.where((w) => w.isCorrect).map((w) => w.word).toSet();
    final unplayed = _round!.category.acceptedWords.where((w) {
      final norm = TurkishStrings.toLowerCaseTr(w);
      return !usedWords.any((u) => TurkishStrings.toLowerCaseTr(u) == norm);
    }).toList();

    if (unplayed.isNotEmpty) {
      final hintWord = unplayed.first;
      final prefix = hintWord.length > 2 ? hintWord.substring(0, 2) : hintWord[0];
      final formatted = TurkishStrings.formatSentenceCase(prefix);
      _currentHint = '$formatted... (${hintWord.length} harf)';
      setFeedbackMessage('İpucu: $_currentHint 💡', true);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _briefingTimer?.cancel();
    _feedbackTimer?.cancel();
    _botEngine.stop();
    _userEmoteTimer?.cancel();
    _opponentEmoteTimer?.cancel();
    super.dispose();
  }
}
