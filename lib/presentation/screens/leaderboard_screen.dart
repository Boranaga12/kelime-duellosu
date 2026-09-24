import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/leaderboard_entry.dart';
import '../../data/models/player.dart';
import '../controllers/friends_controller.dart';
import '../controllers/leaderboard_controller.dart';
import '../controllers/profile_controller.dart';
import '../widgets/player_profile_modal.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = context.read<ProfileController>();
      final friends = context.read<FriendsController>();
      context.read<LeaderboardController>().loadLeaderboard(
            currentPlayer: profile.player,
            friends: friends.friends,
          );
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ldr = context.watch<LeaderboardController>();
    final profile = context.watch<ProfileController>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          'Liderlik Tablosu',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textLight),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.textLight),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorWeight: 2.5,
          labelColor: AppColors.primaryLight,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: '🌍 Global (Dünya)'),
            Tab(text: '👥 Arkadaşlarım'),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildRankingList(ldr.globalEntries, ldr.isLoading),
              _buildRankingList(ldr.friendEntries, ldr.isLoading),
            ],
          ),

          // Alt Sabit Kullanıcı Sıralama Çubuğu
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildCurrentUserBar(profile),
          ),
        ],
      ),
    );
  }

  Widget _buildRankingList(List<LeaderboardEntry> entries, bool isLoading) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (entries.isEmpty) {
      return const Center(
        child: Text('Henüz sıralama bulunamadı.', style: TextStyle(color: AppColors.textMuted)),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(top: 14, left: 16, right: 16, bottom: 85),
      children: [
        // İlk 3 Podyumu (Eğer en az 3 kişi varsa)
        if (entries.length >= 3) ...[
          _buildPodium(entries.sublist(0, 3)),
          const SizedBox(height: 18),
        ],

        // 4. sıradan sonrakiler
        ...entries.skip(entries.length >= 3 ? 3 : 0).map((entry) => _buildEntryTile(entry)),
      ],
    );
  }

  Widget _buildPodium(List<LeaderboardEntry> top3) {
    final first = top3[0];
    final second = top3[1];
    final third = top3[2];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2. Sıra (Gümüş)
          _buildPodiumSpot(second, '🥈', AppColors.textMuted, 80),

          // 1. Sıra (Altın / Şampiyon)
          _buildPodiumSpot(first, '🥇', AppColors.primaryLight, 105),

          // 3. Sıra (Bronz)
          _buildPodiumSpot(third, '🥉', const Color(0xFFCD7F32), 65),
        ],
      ),
    );
  }

  void _openPlayerProfile(BuildContext context, LeaderboardEntry entry) {
    final profile = context.read<ProfileController>();
    if (entry.username == profile.player.name) {
      PlayerProfileModal.show(context, profile.player);
      return;
    }

    final targetPlayer = Player(
      id: 'ldr_${entry.username}',
      name: entry.username,
      tag: entry.tag,
      avatarEmoji: entry.avatarEmoji,
      title: entry.league,
      trophies: entry.trophies,
      level: (entry.trophies / 300).clamp(1, 20).toInt(),
      isBot: false,
    );

    PlayerProfileModal.show(context, targetPlayer);
  }

  Widget _buildPodiumSpot(LeaderboardEntry entry, String medal, Color color, double height) {
    return InkWell(
      onTap: () => _openPlayerProfile(context, entry),
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(entry.avatarEmoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 4),
          Text(
            entry.username,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textLight),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '🏆 ${entry.trophies}',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(height: 6),
          Container(
            width: 76,
            height: height,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.5), width: 1.2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(medal, style: const TextStyle(fontSize: 22)),
                Text(
                  '#${entry.rank}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryTile(LeaderboardEntry entry) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openPlayerProfile(context, entry),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  '#${entry.rank}',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textMuted),
                ),
              ),
              Text(entry.avatarEmoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.username,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textLight),
                    ),
                    Text(
                      entry.league,
                      style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              Text(
                '🏆 ${entry.trophies}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primaryLight),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentUserBar(ProfileController profile) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => PlayerProfileModal.show(context, profile.player),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: const Border(top: BorderSide(color: AppColors.cardBorderActive, width: 1.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Text(profile.player.avatarEmoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${profile.player.name} (Sen)',
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textLight),
                    ),
                    Text(
                      'Lig: ${LeaderboardEntry.getLeagueForTrophies(profile.player.trophies)}',
                      style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '🏆 ${profile.player.trophies}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primaryLight),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
