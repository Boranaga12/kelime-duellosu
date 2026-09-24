import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/categories_data.dart';
import '../../data/models/friend.dart';
import '../../data/models/player.dart';
import '../controllers/friends_controller.dart';
import '../controllers/game_controller.dart';
import '../controllers/profile_controller.dart';
import '../widgets/auth_dialog.dart';
import '../widgets/player_profile_modal.dart';
import 'battle_arena_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = context.read<ProfileController>();
      if (profile.isLoggedIn) {
        context.read<FriendsController>().syncFriendsFromSupabase(profile.player.id);
      }
    });
  }

  void _showAddFriendDialog(BuildContext context) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Arkadaş Ekle', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textLight)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Arkadaşınızın oyuncu etiketini (#KW-XXXX) veya adını girin:',
              style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(14),
              ),
              child: TextField(
                controller: textController,
                autofocus: true,
                style: const TextStyle(color: AppColors.textLight, fontWeight: FontWeight.w700),
                decoration: const InputDecoration(
                  hintText: '#KW-7482',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('İptal', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final query = textController.text.trim();
              if (query.isNotEmpty) {
                final userPlayer = context.read<ProfileController>().player;
                if (query.toLowerCase() == userPlayer.tag.toLowerCase() ||
                    query.toLowerCase() == userPlayer.name.toLowerCase() ||
                    query.toLowerCase() == userPlayer.id.toLowerCase()) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: Color(0xFFEF4444),
                      content: Text(
                        'Kendinizi arkadaş olarak ekleyemezsiniz! 😊',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                  );
                  return;
                }

                final success = context.read<FriendsController>().addFriendByTag(
                      query,
                      currentUserId: userPlayer.id,
                      currentUserName: userPlayer.name,
                      currentUserTag: userPlayer.tag,
                    );
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    content: Text(
                      success ? 'Arkadaşlık isteği iletildi! 🤝' : 'Bu kişi zaten listenizde veya bulunamadı.',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                );
              }
            },
            child: const Text('Ekle', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _startDuelWithFriend(BuildContext context, Friend friend) {
    final userPlayer = context.read<ProfileController>().player;
    final randomCategory = sampleCategories[Random().nextInt(sampleCategories.length)];

    final friendPlayer = Player(
      id: friend.id,
      name: friend.name,
      tag: friend.tag,
      avatarEmoji: friend.avatarEmoji,
      title: friend.title,
      trophies: friend.trophies,
      level: friend.level,
      isBot: false,
    );

    context.read<GameController>().startNewGame(
          category: randomCategory,
          userPlayer: userPlayer,
          opponentPlayer: friendPlayer,
        );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const BattleArenaScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileController>();
    final friendsCtrl = context.watch<FriendsController>();
    final friends = friendsCtrl.friends;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: const Text(
          'Arkadaşlar & Düello',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textLight),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.textLight),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (profile.isLoggedIn)
            IconButton(
              icon: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFFF59E0B)),
              onPressed: () => _showAddFriendDialog(context),
              tooltip: 'Arkadaş Ekle',
            ),
        ],
      ),
      body: SafeArea(
        child: !profile.isLoggedIn
            ? _buildNotLoggedInView(context)
            : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ARKADAŞLARIN',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Text(
                        '${friendsCtrl.onlineCount} Çevrimiçi',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (friends.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                      alignment: Alignment.center,
                      child: Column(
                        children: [
                          const Icon(Icons.group_outlined, size: 48, color: AppColors.textMuted),
                          const SizedBox(height: 12),
                          const Text(
                            'Henüz arkadaşınız yok.',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textLight),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Sağ üstteki butona dokunarak arkadaşınızın oyuncu etiketini (#KW-XXXX) girip ekleyebilirsiniz.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: () => _showAddFriendDialog(context),
                            icon: const Icon(Icons.person_add_rounded, size: 18, color: Colors.white),
                            label: const Text('Arkadaş Ekle', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
                          ),
                        ],
                      ),
                    )
                  else
                    ...friends.map((friend) => _buildFriendCard(context, friend)),
                ],
              ),
      ),
    );
  }

  /// Giriş Yapılmamışsa Gösterilecek Bilgilendirme ve Yönlendirme Paneli
  Widget _buildNotLoggedInView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(color: Color(0xFF0F172A), offset: Offset(0, 6)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF0F172A),
                ),
                child: const Center(
                  child: Icon(Icons.lock_person_rounded, size: 36, color: Color(0xFFF59E0B)),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Arkadaş Sistemi İçin Giriş Yapmalısınız',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textLight,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tüm oyunlarınız arasında ortak arkadaşlık sistemi oluşturmak, arkadaşlarınıza meydan okumak ve çevrimiçi durumlarını görmek için Supabase hesabınızla giriş yapın.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.35),
              ),
              const SizedBox(height: 24),

              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => const AuthDialog(),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(color: Color(0xFF047857), offset: Offset(0, 4)),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.login_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Giriş Yap veya Kayıt Ol',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFriendCard(BuildContext context, Friend friend) {
    final friendPlayer = Player(
      id: friend.id,
      name: friend.name,
      tag: friend.tag,
      avatarEmoji: friend.avatarEmoji,
      title: friend.title,
      trophies: friend.trophies,
      level: friend.level,
      isBot: false,
    );

    final profile = context.read<ProfileController>();
    final isSelfFriend = friend.id == profile.player.id ||
        (friend.tag.isNotEmpty && friend.tag.toLowerCase() == profile.player.tag.toLowerCase()) ||
        (friend.name.isNotEmpty && friend.name.toLowerCase() == profile.player.name.toLowerCase());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0xFF0F172A), offset: Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => PlayerProfileModal.show(context, friendPlayer),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF0F172A),
                      ),
                      child: Center(
                        child: Text(friend.avatarEmoji, style: const TextStyle(fontSize: 22)),
                      ),
                    ),
                    if (friend.isOnline)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF1E293B), width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        friend.name,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textLight,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '🏆 ${friend.trophies} • ${friend.title}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                if (!isSelfFriend)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _startDuelWithFriend(context, friend),
                    child: const Text('Meydan Oku', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
