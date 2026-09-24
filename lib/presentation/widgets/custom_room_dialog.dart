import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/categories_data.dart';
import '../../data/models/player.dart';
import '../../data/services/multiplayer_service.dart';
import '../controllers/game_controller.dart';
import '../controllers/profile_controller.dart';
import '../screens/battle_arena_screen.dart';

class CustomRoomDialog extends StatefulWidget {
  const CustomRoomDialog({super.key});

  @override
  State<CustomRoomDialog> createState() => _CustomRoomDialogState();
}

class _CustomRoomDialogState extends State<CustomRoomDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _joinCodeController = TextEditingController();

  String? _createdRoomCode;
  bool _isCreating = false;
  bool _isJoining = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _joinCodeController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateRoom() async {
    setState(() {
      _isCreating = true;
      _errorMessage = null;
    });

    final profile = context.read<ProfileController>();
    final game = context.read<GameController>();

    final code = await MultiplayerService.createRoom(
      host: profile.player,
      onGuestJoined: (guest) {
        if (!mounted) return;
        Navigator.of(context).pop();

        // Rastgele kategori ile maçı başlat
        final defaultCat = sampleCategories.first;
        game.startNewGame(
          category: defaultCat,
          userPlayer: profile.player,
          opponentPlayer: guest,
        );

        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const BattleArenaScreen()),
        );
      },
      onWordReceived: (payload) {
        // Realtime kelime geldiğinde GameController'a ilet
        final isCorrect = payload['is_correct'] as bool? ?? false;
        final word = payload['word']?.toString() ?? '';
        if (isCorrect) {
          game.submitOpponentRemoteWord(word, isCorrect: true);
        } else {
          game.submitOpponentRemoteWord(word, isCorrect: false);
        }
      },
      onEmoteReceived: (emoji, senderId) {
        game.triggerRemoteEmote(emoji);
      },
    );

    if (mounted) {
      setState(() {
        _createdRoomCode = code;
        _isCreating = false;
      });
    }
  }

  Future<void> _handleJoinRoom() async {
    final code = _joinCodeController.text.trim();
    if (code.length < 6) {
      setState(() => _errorMessage = 'Lütfen 6 haneli oda kodunu girin.');
      return;
    }

    setState(() {
      _isJoining = true;
      _errorMessage = null;
    });

    final profile = context.read<ProfileController>();
    final game = context.read<GameController>();

    final success = await MultiplayerService.joinRoom(
      roomCode: code,
      guest: profile.player,
      onWordReceived: (payload) {
        final isCorrect = payload['is_correct'] as bool? ?? false;
        final word = payload['word']?.toString() ?? '';
        game.submitOpponentRemoteWord(word, isCorrect: isCorrect);
      },
      onEmoteReceived: (emoji, senderId) {
        game.triggerRemoteEmote(emoji);
      },
    );

    if (!mounted) return;
    setState(() => _isJoining = false);

    if (success) {
      Navigator.of(context).pop();

      // Host oyuncusu (Oda kurucusu)
      const hostMock = Player(
        id: 'host_player',
        name: 'Oda Kurucusu',
        avatarEmoji: '👑',
        trophies: 1300,
        level: 6,
      );

      game.startNewGame(
        category: sampleCategories.first,
        userPlayer: profile.player,
        opponentPlayer: hostMock,
      );

      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const BattleArenaScreen()),
      );
    } else {
      setState(() => _errorMessage = 'Oda bulunamadı veya dolmuş olabilir.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Özel 1v1 Düello Odası',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textLight,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textMuted, size: 20),
                  onPressed: () {
                    MultiplayerService.leaveRoom();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primary,
              indicatorWeight: 2,
              labelColor: AppColors.primaryLight,
              unselectedLabelColor: AppColors.textMuted,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              tabs: const [
                Tab(text: 'Oda Kur'),
                Tab(text: 'Odaya Katıl'),
              ],
            ),
            const SizedBox(height: 18),

            SizedBox(
              height: 210,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildCreateRoomTab(),
                  _buildJoinRoomTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateRoomTab() {
    if (_isCreating) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_createdRoomCode == null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Arkadaşınızla canlı oynamak için 6 haneli özel bir oda kodu oluşturun.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _handleCreateRoom,
            icon: const Icon(Icons.add_circle_outline, size: 18),
            label: const Text('Oda Oluştur'),
          ),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'ODA KODUNUZ',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1, color: AppColors.textMuted),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _createdRoomCode!,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                  color: AppColors.primaryLight,
                ),
              ),
              const SizedBox(width: 14),
              IconButton(
                icon: const Icon(Icons.copy_rounded, color: AppColors.primaryLight, size: 20),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _createdRoomCode!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Oda kodu panoya kopyalandı!'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                tooltip: 'Kodu Kopyala',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            ),
            SizedBox(width: 8),
            Text(
              'Arkadaşınız bekleniyor...',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildJoinRoomTab() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: AppColors.opponentColor, fontSize: 11.5),
            ),
          ),
        TextField(
          controller: _joinCodeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 4,
            color: AppColors.textLight,
          ),
          decoration: const InputDecoration(
            hintText: '6 Haneli Kod',
            counterText: '',
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isJoining ? null : _handleJoinRoom,
            child: _isJoining
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textDark),
                  )
                : const Text('Odaya Bağlan ve Başla'),
          ),
        ),
      ],
    );
  }
}
