import 'package:flutter/foundation.dart';
import '../../data/models/friend.dart';
import '../../data/models/leaderboard_entry.dart';
import '../../data/models/player.dart';
import '../../data/services/supabase_service.dart';

class LeaderboardController extends ChangeNotifier {
  List<LeaderboardEntry> _globalEntries = [];
  List<LeaderboardEntry> _friendEntries = [];
  bool _isLoading = false;

  List<LeaderboardEntry> get globalEntries => _globalEntries;
  List<LeaderboardEntry> get friendEntries => _friendEntries;
  bool get isLoading => _isLoading;

  LeaderboardController() {
    loadLeaderboard();
  }

  Future<void> loadLeaderboard({Player? currentPlayer, List<Friend>? friends}) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Supabase üzerinden çekmeyi dene (2s timeout)
      if (SupabaseService.isInitialized && SupabaseService.client != null) {
        final rows = await SupabaseService.client!
            .from('leaderboards')
            .select()
            .order('score', ascending: false)
            .limit(50)
            .timeout(const Duration(milliseconds: 2000));

        if ((rows as List).isNotEmpty) {
          _globalEntries = [];
          int rank = 1;
          for (final r in rows) {
            final trophies = (r['score'] as num?)?.toInt() ?? 1200;
            _globalEntries.add(
              LeaderboardEntry(
                rank: rank++,
                username: r['player_name']?.toString() ?? 'Oyuncu',
                tag: '#KW-${1000 + rank}',
                avatarEmoji: '👑',
                trophies: trophies,
                league: LeaderboardEntry.getLeagueForTrophies(trophies),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Leaderboard Supabase hatası: $e');
    }

    // Eğer leaderboards tablosu boşsa doğrudan app_users tablosundan gerçek kullanıcıları çek
    if (_globalEntries.isEmpty && SupabaseService.isInitialized && SupabaseService.client != null) {
      try {
        final users = await SupabaseService.client!
            .from('app_users')
            .select('username, tag, avatar, trophies, progress_data')
            .limit(30)
            .timeout(const Duration(milliseconds: 2000));

        final List<LeaderboardEntry> userEntries = [];
        for (final u in (users as List)) {
          final progress = u['progress_data'] as Map<String, dynamic>? ?? {};
          final ks = progress['kelime_savasi'] as Map<String, dynamic>? ?? {};
          final trophies = (ks['trophies'] as num?)?.toInt() ?? (u['trophies'] as num?)?.toInt() ?? 0;

          userEntries.add(
            LeaderboardEntry(
              rank: 1,
              username: u['username']?.toString() ?? 'Oyuncu',
              tag: u['tag']?.toString() ?? '#KW-0000',
              avatarEmoji: u['avatar']?.toString() ?? '👑',
              trophies: trophies,
              league: LeaderboardEntry.getLeagueForTrophies(trophies),
            ),
          );
        }

        userEntries.sort((a, b) => b.trophies.compareTo(a.trophies));
        _globalEntries = [];
        for (int i = 0; i < userEntries.length; i++) {
          _globalEntries.add(
            LeaderboardEntry(
              rank: i + 1,
              username: userEntries[i].username,
              tag: userEntries[i].tag,
              avatarEmoji: userEntries[i].avatarEmoji,
              trophies: userEntries[i].trophies,
              league: userEntries[i].league,
            ),
          );
        }
      } catch (e) {
        debugPrint('app_users leaderboard hatası: $e');
      }
    }

    // Çevrimdışı / İlk açılışta mevcut oyuncu varsa listeye ekle
    if (_globalEntries.isEmpty && currentPlayer != null) {
      _globalEntries.add(
        LeaderboardEntry(
          rank: 1,
          username: '${currentPlayer.name} (Sen)',
          tag: currentPlayer.tag,
          avatarEmoji: currentPlayer.avatarEmoji,
          trophies: currentPlayer.trophies,
          league: LeaderboardEntry.getLeagueForTrophies(currentPlayer.trophies),
        ),
      );
    }

    // 2. Arkadaşlar Sıralaması
    _buildFriendsLeaderboard(currentPlayer, friends);

    _isLoading = false;
    notifyListeners();
  }

  void _buildFriendsLeaderboard(Player? currentPlayer, List<Friend>? friends) {
    final list = <LeaderboardEntry>[];

    if (currentPlayer != null) {
      list.add(
        LeaderboardEntry(
          rank: 1,
          username: '${currentPlayer.name} (Sen)',
          tag: currentPlayer.tag,
          avatarEmoji: currentPlayer.avatarEmoji,
          trophies: currentPlayer.trophies,
          league: LeaderboardEntry.getLeagueForTrophies(currentPlayer.trophies),
        ),
      );
    }

    if (friends != null) {
      for (final f in friends) {
        list.add(
          LeaderboardEntry(
            rank: 1,
            username: f.name,
            tag: f.tag,
            avatarEmoji: f.avatarEmoji,
            trophies: f.trophies,
            league: LeaderboardEntry.getLeagueForTrophies(f.trophies),
          ),
        );
      }
    }

    // Kupaya göre sırala
    list.sort((a, b) => b.trophies.compareTo(a.trophies));

    // Sıra numaralarını ata
    _friendEntries = [];
    for (int i = 0; i < list.length; i++) {
      final item = list[i];
      _friendEntries.add(
        LeaderboardEntry(
          rank: i + 1,
          username: item.username,
          tag: item.tag,
          avatarEmoji: item.avatarEmoji,
          trophies: item.trophies,
          league: item.league,
        ),
      );
    }
  }

  /// Kullanıcının kupasını Supabase leaderboards tablosuna kaydeder
  Future<void> syncScoreToSupabase({required String username, required int trophies}) async {
    if (!SupabaseService.isInitialized || SupabaseService.client == null) return;

    try {
      await SupabaseService.client!.from('leaderboards').upsert({
        'player_name': username,
        'score': trophies,
        'theme': 'kelime_savasi',
      });
    } catch (e) {
      debugPrint('Sync score to leaderboard hatası: $e');
    }
  }
}
