class Player {
  final String id;
  final String name;
  final String tag; // Örn: #KW-4921
  final String avatarEmoji;
  final String? avatarUrl;
  final String title;
  final int trophies;
  final int level;
  final bool isBot;
  final List<String>? botWrongAnswers;
  final String? email;
  final bool isEmailVerified;

  const Player({
    required this.id,
    required this.name,
    this.tag = '#KW-1001',
    required this.avatarEmoji,
    this.avatarUrl,
    this.title = 'Kelime Ustası',
    this.trophies = 1200,
    this.level = 5,
    this.isBot = false,
    this.botWrongAnswers,
    this.email,
    this.isEmailVerified = false,
  });

  Player copyWith({
    String? id,
    String? name,
    String? tag,
    String? avatarEmoji,
    String? avatarUrl,
    String? title,
    int? trophies,
    int? level,
    bool? isBot,
    List<String>? botWrongAnswers,
    String? email,
    bool? isEmailVerified,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      tag: tag ?? this.tag,
      avatarEmoji: avatarEmoji ?? this.avatarEmoji,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      title: title ?? this.title,
      trophies: trophies ?? this.trophies,
      level: level ?? this.level,
      isBot: isBot ?? this.isBot,
      botWrongAnswers: botWrongAnswers ?? this.botWrongAnswers,
      email: email ?? this.email,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
    );
  }
}
