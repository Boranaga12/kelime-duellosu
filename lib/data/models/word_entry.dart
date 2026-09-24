class WordEntry {
  final String word;
  final String playerId;
  final bool isCorrect;
  final DateTime timestamp;
  final String? originalTypo;
  final bool isAiApproved;
  final String? aiExplanation;

  const WordEntry({
    required this.word,
    required this.playerId,
    required this.isCorrect,
    required this.timestamp,
    this.originalTypo,
    this.isAiApproved = false,
    this.aiExplanation,
  });
}
