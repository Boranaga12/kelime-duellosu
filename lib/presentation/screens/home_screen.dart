import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/supabase_service.dart';
import '../controllers/profile_controller.dart';
import '../widgets/avatar_badge.dart';
import '../widgets/player_profile_modal.dart';
import 'custom_room_screen.dart';
import 'friends_screen.dart';
import 'leaderboard_screen.dart';
import 'matchmaking_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime? _lastBackPressTime;

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileController>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text('Çıkmak için tekrar basınız', style: TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
              backgroundColor: const Color(0xFF1E293B),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
          return;
        }
        SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Üst Bar: Profil, Bakiye ve Liderlik (Kelime Ustası ve Arkadaşlar butonu kaldırıldı)
              _buildTopBar(context, profile),
              if (!SupabaseService.isReachable) ...[
                const SizedBox(height: 12),
                _buildOfflineNoticeBanner(context),
              ],
              const SizedBox(height: 24),

              // 2. Oyun Modları Başlığı
              const Text(
                'DÜELLO MODLARI',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 14),

              // 1. HIZLI DÜELLO (1v1 CANLI GERÇEK OYUNCU) - 3D Altın Kart
              _build3DGameCard(
                title: 'Hızlı Düello (1v1 Canlı)',
                subtitle: 'Supabase üzerinden gerçek bir rakiple canlı kelime savaşı',
                badge: 'CANLI 1v1',
                icon: Icons.flash_on_rounded,
                cardColor: const Color(0xFFF59E0B),
                shadowColor: const Color(0xFFB45309),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MatchmakingScreen(isPracticeBot: false),
                    ),
                  );
                },
              ).animate().fadeIn(duration: 250.ms),

              const SizedBox(height: 14),

              // 2. BOT İLE ALIŞTIRMA - 3D Mavi Kart (Hızlı Düello ile tamamen aynı aşamalar, ama Bot)
              _build3DGameCard(
                title: 'Bot ile Alıştırma',
                subtitle: 'Aynı arama ve brifing aşamalarıyla yapay zekaya karşı pratik yap',
                badge: 'ALIŞTIRMA',
                icon: Icons.smart_toy_rounded,
                cardColor: const Color(0xFF0284C7),
                shadowColor: const Color(0xFF0369A1),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MatchmakingScreen(isPracticeBot: true),
                    ),
                  );
                },
              ).animate().fadeIn(delay: 60.ms),

              const SizedBox(height: 14),

              // 3. ÖZEL ODA (2-6 KİŞİ & TAKIMLI) - 3D Mor Kart
              _build3DGameCard(
                title: 'Özel Oda (2-6 Kişi & Takımlı)',
                subtitle: 'Oda kur, takımları yönet veya açık odalara katıl',
                badge: 'ÖZEL ODA',
                icon: Icons.meeting_room_rounded,
                cardColor: const Color(0xFF8B5CF6),
                shadowColor: const Color(0xFF6D28D9),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CustomRoomScreen()),
                  );
                },
              ).animate().fadeIn(delay: 120.ms),

              const SizedBox(height: 14),

              // 4. ARKADAŞLAR & SOSYAL - 3D Zümrüt Kart
              _build3DGameCard(
                title: 'Arkadaşlar & Sosyal',
                subtitle: profile.isLoggedIn
                    ? 'Arkadaşlarına meydan oku ve durumlarını gör'
                    : 'Arkadaş sistemi için giriş yapmalısınız',
                badge: 'SOSYAL',
                icon: Icons.people_alt_rounded,
                cardColor: const Color(0xFF10B981),
                shadowColor: const Color(0xFF047857),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const FriendsScreen()),
                  );
                },
              ).animate().fadeIn(delay: 180.ms),

              const SizedBox(height: 28),

              // 3. Kariyer İstatistikleri (3D Tok Panel)
              _buildStatsSection(profile).animate().fadeIn(delay: 240.ms),
            ],
          ),
        ),
      ),
    ),
  );
  }

  /// 1. Üst Bar: Profil Kartı (Tıklayınca açılır ve ID / Giriş içindedir), Altın ve Liderlik
  Widget _buildTopBar(BuildContext context, ProfileController profile) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Profil Avatar ve İsim Rozeti (Tıklanınca Profil Düzenleme Açılır)
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              PlayerProfileModal.show(context, profile.player);
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: Color(0xFF0F172A), offset: Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  AvatarBadge(player: profile.player, size: 40),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        profile.player.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textLight,
                        ),
                      ),
                      Row(
                        children: [
                          const Text('🏆 ', style: TextStyle(fontSize: 11)),
                          Text(
                            '${profile.player.trophies} Kupa',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFF59E0B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMuted, size: 18),
                ],
              ),
            ),
          ),
        ),

        // Sağ Taraf: Altın ve Liderlik Butonu
        Row(
          children: [
            // Altın Rozeti (3D Tok)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Color(0xFF0F172A), offset: Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  const Text('🪙 ', style: TextStyle(fontSize: 14)),
                  Text(
                    '${profile.coins}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Liderlik Butonu (3D Tok)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(color: Color(0xFF0F172A), offset: Offset(0, 4)),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.leaderboard_rounded, color: Color(0xFFF59E0B), size: 22),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 3D Tok Oyun Kartı (İnce neon çizgiler yerine 4px koyu derinlik bevel)
  Widget _build3DGameCard({
    required String title,
    required String subtitle,
    required String badge,
    required IconData icon,
    required Color cardColor,
    required Color shadowColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                offset: const Offset(0, 5),
                blurRadius: 0, // Tok 3D katman
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  /// 3D Tok Kariyer İstatistikleri
  Widget _buildStatsSection(ProfileController profile) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Color(0xFF0F172A), offset: Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'KARİYER PERFORMANSI',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Kupa', '${profile.player.trophies}', '🏆', const Color(0xFFF59E0B)),
              Container(width: 1, height: 36, color: const Color(0xFF334155)),
              _buildStatItem('Galibiyet', '${profile.wins}', '⚔️', const Color(0xFF10B981)),
              Container(width: 1, height: 36, color: const Color(0xFF334155)),
              _buildStatItem('Mağlubiyet', '${profile.losses}', '🛡️', const Color(0xFFEF4444)),
              Container(width: 1, height: 36, color: const Color(0xFF334155)),
              _buildStatItem('Seviye', '${profile.player.level}', '⭐', const Color(0xFF38BDF8)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, String icon, Color color) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildOfflineNoticeBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: Color(0xFFEF4444), size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Çevrimiçi sunucu kapalı / duraklatılmış (paused)',
              style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
          ),
          InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CustomRoomScreen()),
              );
            },
            child: const Text(
              'Ayarlar ⚙️',
              style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 11.5, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
