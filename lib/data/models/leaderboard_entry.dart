class LeaderboardEntry {
  final int rank;
  final String username;
  final String tag;
  final String avatarEmoji;
  final int trophies;
  final String league;

  const LeaderboardEntry({
    required this.rank,
    required this.username,
    required this.tag,
    required this.avatarEmoji,
    required this.trophies,
    required this.league,
  });

  static String getLeagueForTrophies(int trophies) {
    if (trophies >= 1800) return '👑 Usta Ligi';
    if (trophies >= 1600) return '💎 Elmas Ligi';
    if (trophies >= 1400) return '🥇 Altın Ligi';
    if (trophies >= 1200) return '🥈 Gümüş Ligi';
    return '🥉 Bronz Ligi';
  }
}
