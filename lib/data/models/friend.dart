class Friend {
  final String id;
  final String name;
  final String tag;
  final String avatarEmoji;
  final String title;
  final int trophies;
  final int level;
  final bool isOnline;

  const Friend({
    required this.id,
    required this.name,
    required this.tag,
    required this.avatarEmoji,
    this.title = 'Sözlük Savaşçısı',
    required this.trophies,
    required this.level,
    this.isOnline = false,
  });

  Friend copyWith({
    String? id,
    String? name,
    String? tag,
    String? avatarEmoji,
    String? title,
    int? trophies,
    int? level,
    bool? isOnline,
  }) {
    return Friend(
      id: id ?? this.id,
      name: name ?? this.name,
      tag: tag ?? this.tag,
      avatarEmoji: avatarEmoji ?? this.avatarEmoji,
      title: title ?? this.title,
      trophies: trophies ?? this.trophies,
      level: level ?? this.level,
      isOnline: isOnline ?? this.isOnline,
    );
  }
}
