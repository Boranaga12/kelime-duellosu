class Category {
  final String id;
  final String title;
  final String description;
  final String iconEmoji;
  final List<String> acceptedWords;
  final int difficulty; // 1: Kolay, 2: Orta, 3: Zor

  const Category({
    required this.id,
    required this.title,
    required this.description,
    required this.iconEmoji,
    required this.acceptedWords,
    this.difficulty = 1,
  });

  /// Yapay zeka veya oyuncular tarafından yeni öğrenilen kelimeyi soru havuzuna ekler
  void addAcceptedWord(String word) {
    final clean = word.trim().toLowerCase();
    if (clean.isNotEmpty && !acceptedWords.any((w) => w.trim().toLowerCase() == clean)) {
      acceptedWords.add(clean);
    }
  }
}
