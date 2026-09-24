import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/categories_data.dart';
import '../../data/models/player.dart';
import '../controllers/friends_controller.dart';
import '../controllers/game_controller.dart';
import '../controllers/profile_controller.dart';
import '../screens/battle_arena_screen.dart';
import 'profile_edit_dialog.dart';

/// Tüm ekranlardan (Ana Menü, Liderlik Tablosu, Arkadaşlar Listesi) açılabilen
/// 3D Dokunsal Oyuncu Profili Modalı.
/// Kullanıcı ID'si (#KW-XXXX) YALNIZCA bu modal içinde görünür.
class PlayerProfileModal extends StatefulWidget {
  final Player player;

  const PlayerProfileModal({super.key, required this.player});

  static void show(BuildContext context, Player player) {
    showDialog(
      context: context,
      builder: (_) => PlayerProfileModal(player: player),
    );
  }

  @override
  State<PlayerProfileModal> createState() => _PlayerProfileModalState();
}

class _PlayerProfileModalState extends State<PlayerProfileModal> {
  bool _isCopied = false;

  void _copyTag(String tag) {
    Clipboard.setData(ClipboardData(text: tag));
    setState(() => _isCopied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isCopied = false);
    });
  }

  void _startDuelWithPlayer(BuildContext context, Player targetPlayer) {
    Navigator.of(context).pop(); // Modalı kapat

    final userPlayer = context.read<ProfileController>().player;
    final randomCategory = sampleCategories[DateTime.now().second % sampleCategories.length];

    context.read<GameController>().startNewGame(
          category: randomCategory,
          userPlayer: userPlayer,
          opponentPlayer: targetPlayer,
        );

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BattleArenaScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileController>();
    final friendsCtrl = context.watch<FriendsController>();
    final isSelf = widget.player.id == profile.player.id ||
        (widget.player.tag.isNotEmpty &&
            widget.player.tag.toLowerCase() == profile.player.tag.toLowerCase()) ||
        (widget.player.name.trim().isNotEmpty &&
            widget.player.name.trim().toLowerCase() ==
                profile.player.name.trim().toLowerCase());
    final activePlayer = isSelf ? profile.player : widget.player;
    final isFriend = friendsCtrl.friends.any((f) => f.tag == activePlayer.tag || f.id == activePlayer.id);

    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Üst Kısım: Başlık ve Kapat
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isSelf ? 'Profilim' : 'Oyuncu Detayı',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textLight),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 22),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Büyük Avatar
              Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF0F172A),
                      border: Border.all(color: const Color(0xFFF59E0B), width: 2.5),
                      boxShadow: const [
                        BoxShadow(color: Color(0xFF0F172A), offset: Offset(0, 6), blurRadius: 6),
                      ],
                    ),
                    child: ClipOval(
                      child: (activePlayer.avatarUrl != null && activePlayer.avatarUrl!.isNotEmpty)
                          ? Image.network(
                              activePlayer.avatarUrl!,
                              width: 76,
                              height: 76,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Center(
                                child: Text(activePlayer.avatarEmoji, style: const TextStyle(fontSize: 38)),
                              ),
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return Center(
                                  child: Text(activePlayer.avatarEmoji, style: const TextStyle(fontSize: 38)),
                                );
                              },
                            )
                          : Center(
                              child: Text(activePlayer.avatarEmoji, style: const TextStyle(fontSize: 38)),
                            ),
                    ),
                  ),
                  Positioned(
                    bottom: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Seviye ${activePlayer.level}',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // İsim ve Unvan
              Text(
                activePlayer.name,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textLight),
              ),
              const SizedBox(height: 2),
              Text(
                activePlayer.title,
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),

              // OYUNCU ID'Sİ (YALNIZCA BURADA GÖRÜNÜR)
              InkWell(
                onTap: () => _copyTag(
                  activePlayer.tag.startsWith('#BOT-')
                      ? '#KW-${activePlayer.tag.replaceFirst('#BOT-', '')}'
                      : activePlayer.tag,
                ),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF334155), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Oyuncu Kodu: ',
                        style: TextStyle(fontSize: 11.5, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        activePlayer.tag.startsWith('#BOT-')
                            ? '#KW-${activePlayer.tag.replaceFirst('#BOT-', '')}'
                            : activePlayer.tag,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFFF59E0B)),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _isCopied ? Icons.check_circle_rounded : Icons.copy_rounded,
                        size: 15,
                        color: _isCopied ? const Color(0xFF10B981) : AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // İstatistikler (Kupa & Galibiyet Panelleri)
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const Text('🏆 Kupa', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          const SizedBox(height: 4),
                          Text(
                            '${activePlayer.trophies}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFFF59E0B)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const Text('⚔️ Galibiyet', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          const SizedBox(height: 4),
                          Text(
                            isSelf
                                ? '${profile.wins}'
                                : '${(activePlayer.trophies / 28).clamp(14, 180).round()}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF10B981)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // KULLANICININ KENDİ PROFİLİ İSE E-POSTA & HESAP YÖNETİMİ
              if (isSelf) ...[
                // E-posta Bilgi Kutusu (Sadece bilgilendirme - ekleme Düzenle kısmında)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        activePlayer.isEmailVerified
                            ? Icons.verified_user_rounded
                            : (profile.isLoggedIn ? Icons.mail_outline_rounded : Icons.person_outline_rounded),
                        size: 20,
                        color: activePlayer.isEmailVerified
                            ? const Color(0xFF10B981)
                            : (profile.isLoggedIn ? const Color(0xFFF59E0B) : AppColors.textMuted),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activePlayer.email != null && activePlayer.email!.isNotEmpty
                                  ? activePlayer.email!
                                  : (profile.isLoggedIn ? 'E-posta Tanımlı Değil' : 'Misafir Modundasınız'),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textLight),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              activePlayer.isEmailVerified
                                  ? 'E-posta Onaylandı ✓'
                                  : (profile.isLoggedIn
                                      ? 'E-posta eklemek için "Düzenle" butonuna dokunun'
                                      : 'Misafir Hesabı'),
                              style: TextStyle(
                                fontSize: 10,
                                color: activePlayer.isEmailVerified ? const Color(0xFF10B981) : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Profili Düzenle & Giriş/Çıkış Butonları
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          showDialog(
                            context: context,
                            builder: (_) => const ProfileEditDialog(),
                          );
                        },
                        icon: const Icon(Icons.edit_rounded, size: 16, color: Colors.white),
                        label: const Text('Düzenle', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white)),
                      ),
                    ),
                    if (profile.isLoggedIn) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () {
                            profile.logout();
                            context.read<FriendsController>().clear();
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.logout_rounded, size: 16, color: Colors.white),
                          label: const Text(
                            'Çıkış Yap',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ] else ...[
                // BAŞKA OYUNCU İSE MEYDAN OKU & ARKADAŞ EKLE BUTONLARI
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () => _startDuelWithPlayer(context, activePlayer),
                        icon: const Icon(Icons.flash_on_rounded, size: 18, color: Colors.white),
                        label: const Text('Meydan Oku', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFriend ? const Color(0xFF334155) : const Color(0xFF10B981),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: isFriend
                            ? null
                            : () {
                                final success = friendsCtrl.addFriendByTag(activePlayer.tag, currentUserId: profile.player.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                    content: Text(
                                      success ? 'Arkadaşlık isteği gönderildi! 🤝' : 'İstek gönderilemedi.',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                );
                              },
                        icon: Icon(isFriend ? Icons.check_circle_rounded : Icons.person_add_rounded, size: 17, color: Colors.white),
                        label: Text(
                          isFriend ? 'Arkadaşsınız' : 'Arkadaş Ekle',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
