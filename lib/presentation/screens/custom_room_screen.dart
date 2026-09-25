import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/services/sound_service.dart';
import '../../core/theme/app_colors.dart';
import '../../data/categories_data.dart';
import '../../data/models/custom_room.dart';
import '../../data/models/player.dart';
import '../../data/services/multiplayer_service.dart';
import '../../data/services/supabase_service.dart';
import '../controllers/game_controller.dart';
import '../controllers/profile_controller.dart';
import '../widgets/avatar_badge.dart';
import '../widgets/player_profile_modal.dart';
import 'battle_arena_screen.dart';

class CustomRoomScreen extends StatefulWidget {
  const CustomRoomScreen({super.key});

  @override
  State<CustomRoomScreen> createState() => _CustomRoomScreenState();
}

class _CustomRoomScreenState extends State<CustomRoomScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _roomNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  List<CustomRoom> _publicRooms = [];
  bool _isLoadingRooms = false;
  CustomRoom? _currentLobbyRoom;
  Timer? _lobbyPollTimer;
  Timer? _roomsPollTimer;

  // Oda Kurma Ayarları
  bool _isLocked = false;
  int _maxPlayers = 4;
  bool _isTeamMode = true;
  int _teamCount = 2;
  int _targetWins = 2;

  final List<Color> _palette = const [
    Color(0xFFEF4444), // Kırmızı
    Color(0xFF0284C7), // Mavi
    Color(0xFF10B981), // Yeşil
    Color(0xFFF59E0B), // Sarı
    Color(0xFF8B5CF6), // Mor
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPublicRooms();

    // Supabase bağlantı durumunu kontrol et
    SupabaseService.checkConnection().then((_) {
      if (mounted) setState(() {});
    });

    // Açık odaları periyodik kontrol et (3.5s aralıkla, sadece lobi dışındayken)
    _roomsPollTimer = Timer.periodic(const Duration(milliseconds: 3500), (_) {
      if (mounted && _currentLobbyRoom == null && _tabController.index == 0) {
        _loadPublicRooms(silent: true);
      }
    });

    // Supabase Realtime oda olaylarını dinle
    MultiplayerService.onRoomStateChanged = (updatedRoom) {
      if (mounted) {
        setState(() {
          if (_currentLobbyRoom != null && _currentLobbyRoom!.roomCode == updatedRoom.roomCode) {
            _currentLobbyRoom = updatedRoom;
          }
        });
      }
    };

    // Oyun içi kelimeleri canlı dinle
    MultiplayerService.onWordReceived = (payload) {
      if (!mounted) return;
      final word = payload['word']?.toString() ?? '';
      final isCorrect = payload['is_correct'] == true;
      final playerId = payload['player_id']?.toString() ?? '';
      final originalTypo = payload['original_typo']?.toString();
      context.read<GameController>().submitRemoteWord(
            word: word,
            isCorrect: isCorrect,
            playerId: playerId,
            originalTypo: originalTypo,
          );
    };

    // Oyun içi canlı tepkileri dinle
    MultiplayerService.onEmoteReceived = (emoji, senderId) {
      if (!mounted) return;
      context.read<GameController>().triggerRemoteEmote(emoji);
    };

    MultiplayerService.onGameStartedByHost = (categoryId) {
      if (!mounted || _currentLobbyRoom == null) return;
      _lobbyPollTimer?.cancel();
      _lobbyPollTimer = null;
      final userPlayer = context.read<ProfileController>().player;
      final cat = sampleCategories.firstWhere(
        (c) => c.id == categoryId,
        orElse: () => sampleCategories.first,
      );
      context.read<GameController>().startTeamOrCustomGame(
            room: _currentLobbyRoom!,
            userPlayer: userPlayer,
            category: cat,
            showBriefing: true,
          );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const BattleArenaScreen()),
      );
    };
  }

  @override
  void dispose() {
    _lobbyPollTimer?.cancel();
    _lobbyPollTimer = null;
    _roomsPollTimer?.cancel();
    _roomsPollTimer = null;
    MultiplayerService.onRoomStateChanged = null;
    MultiplayerService.onGameStartedByHost = null;
    MultiplayerService.onWordReceived = null;
    MultiplayerService.onEmoteReceived = null;
    _tabController.dispose();
    _codeController.dispose();
    _roomNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _startLobbyPolling(String roomCode) {
    _lobbyPollTimer?.cancel();
    _lobbyPollTimer = Timer.periodic(const Duration(milliseconds: 1500), (t) async {
      if (!mounted || _currentLobbyRoom == null || _currentLobbyRoom!.roomCode != roomCode) {
        t.cancel();
        return;
      }
      final updated = await MultiplayerService.syncLobbyFromDatabase(roomCode);
      if (mounted && updated != null && _currentLobbyRoom != null) {
        setState(() {
          _currentLobbyRoom = updated;
        });
      }
    });
  }

  Future<void> _loadPublicRooms({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoadingRooms = true);
    }
    final rooms = await MultiplayerService.fetchPublicRooms();
    if (mounted) {
      setState(() {
        _publicRooms = rooms;
        _isLoadingRooms = false;
      });
    }
  }

  void _createRoom() async {
    final profile = context.read<ProfileController>();
    final roomName = _roomNameController.text.trim().isEmpty
        ? '${profile.player.name} Odası'
        : _roomNameController.text.trim();

    final teams = [
      TeamConfig(id: 'team_1', name: 'Kırmızı Takım', color: _palette[0]),
      TeamConfig(id: 'team_2', name: 'Mavi Takım', color: _palette[1]),
      if (_teamCount >= 3)
        TeamConfig(id: 'team_3', name: 'Yeşil Takım', color: _palette[2]),
    ];

    final room = await MultiplayerService.createAdvancedRoom(
      roomName: roomName,
      host: profile.player,
      isLocked: _isLocked,
      password: _isLocked ? _passwordController.text.trim() : null,
      maxPlayers: _maxPlayers,
      isTeamMode: _isTeamMode,
      teamCount: _teamCount,
      teams: teams,
      targetWins: _targetWins,
    );

    SoundService.playCorrect();
    setState(() {
      _currentLobbyRoom = room;
    });
    _startLobbyPolling(room.roomCode);
  }

  void _joinRoom(CustomRoom room) async {
    final profile = context.read<ProfileController>();

    String? inputPassword;
    if (room.isLocked) {
      final pwd = await _showPasswordDialog();
      if (pwd == null) return;
      inputPassword = pwd;
    }

    final result = await MultiplayerService.joinAdvancedRoom(
      roomCode: room.roomCode,
      player: profile.player,
      password: inputPassword,
    );

    if (result.success) {
      SoundService.playCorrect();
      if (mounted) {
        setState(() {
          _currentLobbyRoom = MultiplayerService.activeCustomRoom;
        });
        if (_currentLobbyRoom != null) {
          _startLobbyPolling(_currentLobbyRoom!.roomCode);
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${result.message} ⚠️'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _joinByCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    final profile = context.read<ProfileController>();
    final result = await MultiplayerService.joinAdvancedRoom(
      roomCode: code,
      player: profile.player,
    );

    if (result.success) {
      SoundService.playCorrect();
      if (mounted) {
        setState(() {
          _currentLobbyRoom = MultiplayerService.activeCustomRoom;
        });
        if (_currentLobbyRoom != null) {
          _startLobbyPolling(_currentLobbyRoom!.roomCode);
        }
      }
    } else {
      // Eğer şifreli odaya denk gelindiyse kullanıcıdan şifre iste
      if (result.message.toLowerCase().contains('şifre')) {
        final pwd = await _showPasswordDialog();
        if (pwd == null) return;

        final pwdResult = await MultiplayerService.joinAdvancedRoom(
          roomCode: code,
          player: profile.player,
          password: pwd,
        );

        if (pwdResult.success) {
          SoundService.playCorrect();
          if (mounted) {
            setState(() {
              _currentLobbyRoom = MultiplayerService.activeCustomRoom;
            });
            if (_currentLobbyRoom != null) {
              _startLobbyPolling(_currentLobbyRoom!.roomCode);
            }
          }
          return;
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${pwdResult.message} ❌'),
                backgroundColor: const Color(0xFFEF4444),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          }
          return;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${result.message} ⚠️'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<String?> _showPasswordDialog() async {
    final textController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Oda Şifresi',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
        ),
        content: TextField(
          controller: textController,
          obscureText: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Şifreyi giriniz...',
            hintStyle: const TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: const Color(0xFF0F172A),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('İptal', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
            onPressed: () => Navigator.of(ctx).pop(textController.text.trim()),
            child: const Text('Giriş Yap', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _addBot() {
    MultiplayerService.addBotToRoom();
    setState(() {
      _currentLobbyRoom = MultiplayerService.activeCustomRoom;
    });
    SoundService.playCorrect();
  }

  void _leaveLobby() async {
    _lobbyPollTimer?.cancel();
    _lobbyPollTimer = null;
    final profile = context.read<ProfileController>();
    await MultiplayerService.leaveAdvancedRoom(playerId: profile.player.id);
    if (mounted) {
      setState(() {
        _currentLobbyRoom = null;
      });
      _loadPublicRooms();
    }
  }

  void _launchGame() {
    if (_currentLobbyRoom == null) return;
    final room = _currentLobbyRoom!;

    if (room.players.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Oyunu başlatmak için en az 2 oyuncu olmalı! "+ Bot Ekle" butonunu kullanabilirsiniz. 🤖'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    _lobbyPollTimer?.cancel();
    _lobbyPollTimer = null;

    final userPlayer = context.read<ProfileController>().player;
    final randomCategory = sampleCategories[DateTime.now().millisecond % sampleCategories.length];

    // Tüm katılımcılara Realtime ile oyunu başlat bildirimi gönder
    MultiplayerService.broadcastGameStart(randomCategory.id);

    context.read<GameController>().startTeamOrCustomGame(
          room: room,
          userPlayer: userPlayer,
          category: randomCategory,
          showBriefing: true,
        );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const BattleArenaScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentLobbyRoom == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_currentLobbyRoom != null) {
          _leaveLobby();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E293B),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () {
              if (_currentLobbyRoom != null) {
                _leaveLobby();
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          title: Text(
            _currentLobbyRoom != null ? '⚔️ ODA LOBİSİ' : '⚔️ ÖZEL ODALAR (2-6 KİŞİ)',
            style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900, color: Colors.white),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(
                SupabaseService.isReachable
                    ? Icons.cloud_done_rounded
                    : Icons.cloud_off_rounded,
                color: SupabaseService.isReachable
                    ? const Color(0xFF10B981)
                    : const Color(0xFFEF4444),
                size: 22,
              ),
              tooltip: SupabaseService.isReachable
                  ? 'Çevrimiçi Sunucu Aktif'
                  : 'Sunucu Bağlantı Hatası',
              onPressed: _showServerSettingsDialog,
            ),
          ],
          bottom: _currentLobbyRoom == null
              ? TabBar(
                  controller: _tabController,
                  indicatorColor: const Color(0xFF8B5CF6),
                  indicatorWeight: 3.5,
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.textMuted,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                  tabs: const [
                    Tab(text: 'ODALARA KATIL'),
                    Tab(text: 'ODA KUR & YÖNET'),
                  ],
                )
              : null,
        ),
        body: _currentLobbyRoom != null
            ? _buildLobbyView(_currentLobbyRoom!)
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildJoinTab(),
                  _buildCreateTab(),
                ],
              ),
      ),
    );
  }

  /// 1. SEKME: Odalara Katıl (Kodla & Açık Oda Listesi)
  Widget _buildJoinTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await SupabaseService.checkConnection();
        await _loadPublicRooms();
      },
      color: const Color(0xFF8B5CF6),
      backgroundColor: const Color(0xFF1E293B),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Çevrimiçi Sunucu Durum Uyarısı (Eğer bağlanılamıyorsa)
            if (!SupabaseService.isReachable)
              _buildOfflineWarningBanner(),

            // 3D Kod Girişi Kartı
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(color: Color(0xFF0F172A), offset: Offset(0, 5)),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 2),
                    decoration: InputDecoration(
                      hintText: '6 Haneli Oda Kodu...',
                      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13, letterSpacing: 0),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _joinByCode,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(color: Color(0xFF6D28D9), offset: Offset(0, 4)),
                        ],
                      ),
                      child: const Text(
                        'Katıl',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Başlık ve Yenile Butonu
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'AKTİF AÇIK ODALAR',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                  color: AppColors.textMuted,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Color(0xFF8B5CF6), size: 22),
                onPressed: _loadPublicRooms,
                tooltip: 'Odaları Yenile',
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Odalar Listesi
          if (_isLoadingRooms)
            const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
          else if (_publicRooms.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Şu an açık oda bulunmuyor. İlk odayı siz kurun!',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
                ),
              ),
            )
          else
            ..._publicRooms.map((room) => _buildRoomCard(room)),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomCard(CustomRoom room) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0xFF0F172A), offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                room.isLocked ? '🔒' : (room.isTeamMode ? '🛡️' : '⚔️'),
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        room.roomName,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (room.isLocked) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.lock_rounded, size: 14, color: Color(0xFFF59E0B)),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Kurucu: ${room.hostName} • ${room.isTeamMode ? "${room.teamCount} Takım" : "Bireysel"} • İlk ${room.targetWins} Olan',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Katıl Butonu & Kapasite
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${room.players.length}/${room.maxPlayers} Kişi',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: room.players.length >= room.maxPlayers ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                ),
              ),
              const SizedBox(height: 6),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: Size.zero,
                ),
                onPressed: () => _joinRoom(room),
                child: const Text('Katıl', style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 2. SEKME: Oda Kur & Ayarları Seç
  Widget _buildCreateTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Oda Adı
          const Text('ODA ADI', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: AppColors.textMuted)),
          const SizedBox(height: 6),
          TextField(
            controller: _roomNameController,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              hintText: 'Örn: Şampiyonlar Arenası',
              hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
              filled: true,
              fillColor: const Color(0xFF1E293B),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 18),

          // Gizlilik: Açık / Kilitli
          Row(
            children: [
              Expanded(
                child: _buildChoiceButton(
                  title: 'Açık Oda 🌐',
                  isSelected: !_isLocked,
                  onTap: () => setState(() => _isLocked = false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildChoiceButton(
                  title: 'Şifreli Oda 🔒',
                  isSelected: _isLocked,
                  onTap: () => setState(() => _isLocked = true),
                ),
              ),
            ],
          ),
          if (_isLocked) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _passwordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Oda Şifresi Belirleyin...',
                hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
          ],
          const SizedBox(height: 18),

          // Oyuncu Kapasitesi (2, 3, 4, 5, 6)
          const Text('OYUNCU SAYISI KAPASİTESİ', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: AppColors.textMuted)),
          const SizedBox(height: 8),
          Row(
            children: [2, 3, 4, 5, 6].map((count) {
              final isSelected = _maxPlayers == count;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: _buildChoiceButton(
                    title: '$count',
                    isSelected: isSelected,
                    onTap: () => setState(() => _maxPlayers = count),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),

          // Oyun Modu: Takımlı vs Bireysel
          const Text('OYUN MODU', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: AppColors.textMuted)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildChoiceButton(
                  title: 'Takımlı Savaş 🛡️',
                  isSelected: _isTeamMode,
                  onTap: () => setState(() => _isTeamMode = true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildChoiceButton(
                  title: 'Bireysel (Tek) ⚔️',
                  isSelected: !_isTeamMode,
                  onTap: () => setState(() => _isTeamMode = false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Takım Sayısı (Eğer Takımlı ise: 2, 3, 4, 5 Takım)
          if (_isTeamMode) ...[
            const Text('TAKIM SAYISI', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: AppColors.textMuted)),
            const SizedBox(height: 8),
            Row(
              children: [2, 3, 4, 5].map((tc) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _buildChoiceButton(
                      title: '$tc',
                      isSelected: _teamCount == tc,
                      onTap: () {
                        setState(() {
                          _teamCount = tc;
                          if (_maxPlayers < tc) {
                            _maxPlayers = tc;
                          }
                        });
                      },
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
          ],

          // Hedef Galibiyet (2, 3, 5)
          const Text('KAZANMA HEDEFİ', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: AppColors.textMuted)),
          const SizedBox(height: 8),
          Row(
            children: [2, 3, 5].map((target) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _buildChoiceButton(
                    title: 'İlk $target Galibiyet',
                    isSelected: _targetWins == target,
                    onTap: () => setState(() => _targetWins = target),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),

          // Odayı Oluştur Butonu (3D Tok)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _createRoom,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(color: Color(0xFF6D28D9), offset: Offset(0, 5)),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'Odayı Oluştur & Lobiye Geç 🚀',
                    style: TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceButton({required String title, required bool isSelected, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF8B5CF6) : const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? const Color(0xFFA78BFA) : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : AppColors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 3. ODA LOBİSİ (Oyuncular, Takım Yönetimi, Bot Ekleme, Başlatma)
  Widget _buildLobbyView(CustomRoom room) {
    final profile = context.watch<ProfileController>();
    final isHost = room.hostId == profile.player.id;

    return Column(
      children: [
        // Lobi Üst Bilgi Başlığı (3D Kart)
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(color: Color(0xFF0F172A), offset: Offset(0, 5)),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          room.roomName,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Oda Sahibi: ${room.hostName} • ${room.isTeamMode ? "${room.teamCount} Takımlı Mod" : "Bireysel Mod"}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),

                  // Oda Kodu & Kopyalama
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: room.roomCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Oda kodu kopyalandı: ${room.roomCode} 📋'),
                          backgroundColor: const Color(0xFF10B981),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Text(
                            room.roomCode,
                            style: const TextStyle(
                              color: Color(0xFFF59E0B),
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.copy_rounded, color: AppColors.textMuted, size: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Host Kontrol Butonları (+ Bot Ekle)
              if (isHost)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.smart_toy_rounded, size: 18),
                        label: const Text('Bot Ekle 🤖'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF334155),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: room.players.length < room.maxPlayers ? _addBot : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        '${room.players.length}/${room.maxPlayers} Oyuncu',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),

        // Oyuncu & Takım Listesi
        Expanded(
          child: room.isTeamMode
              ? _buildTeamRosterView(room, isHost)
              : _buildIndividualRosterView(room, isHost),
        ),

        // Alt Çubuk: Odadan Ayrıl & Maçı Başlat
        Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFF1E293B),
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFEF4444)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _leaveLobby,
                  child: const Text('Ayrıl', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: isHost ? _launchGame : null,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: isHost ? const Color(0xFF10B981) : const Color(0xFF334155),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          if (isHost)
                            const BoxShadow(color: Color(0xFF047857), offset: Offset(0, 4)),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          isHost ? 'Maçı Başlat ⚔️' : 'Başlatılması Bekleniyor ⏳',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14.5),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Takımlı Görünüm (Kaptanlık, Renk Seçimi & Dokunarak Takım Değiştirme)
  Widget _buildTeamRosterView(CustomRoom room, bool isHost) {
    final currentUserId = context.read<ProfileController>().player.id;
    final myPlayer = room.players.firstWhere(
      (p) => p.id == currentUserId,
      orElse: () => const RoomPlayer(id: '', name: '', avatarEmoji: ''),
    );
    final myTeamId = myPlayer.teamId;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: room.teams.length,
      itemBuilder: (context, index) {
        final team = room.teams[index];
        final teamPlayers = room.players.where((p) => p.teamId == team.id).toList();
        final teamCaptain = teamPlayers.isNotEmpty ? teamPlayers.first : null;
        final isUserCaptainOfThisTeam = teamCaptain != null && teamCaptain.id == currentUserId;
        final isUserInThisTeam = myTeamId == team.id;

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isUserInThisTeam ? team.color : team.color.withValues(alpha: 0.4),
              width: isUserInThisTeam ? 2 : 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(color: team.color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        team.name,
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: team.color),
                      ),
                      if (isUserInThisTeam) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: team.color.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: team.color.withValues(alpha: 0.5)),
                          ),
                          child: const Text('TAKIMINIZ', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
                        ),
                      ],
                    ],
                  ),

                  Row(
                    children: [
                      // Takım Kaptanı Renk Değiştirme Butonu
                      if (isUserCaptainOfThisTeam)
                        IconButton(
                          icon: const Icon(Icons.palette_outlined, size: 18, color: Colors.white),
                          tooltip: 'Takım Rengini Değiştir (Kaptan)',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _showTeamColorPicker(team.id),
                        ),
                      const SizedBox(width: 8),

                      // Bu Takıma Geç Butonu (Kullanıcı bu takımda değilse)
                      if (!isUserInThisTeam)
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            backgroundColor: team.color.withValues(alpha: 0.15),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            MultiplayerService.switchPlayerTeam(currentUserId, team.id);
                            setState(() {
                              _currentLobbyRoom = MultiplayerService.activeCustomRoom;
                            });
                          },
                          icon: Icon(Icons.login_rounded, size: 13, color: team.color),
                          label: Text(
                            'Bu Takıma Geç',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: team.color),
                          ),
                        )
                      else
                        Text(
                          '${teamPlayers.length} Oyuncu',
                          style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (teamPlayers.isEmpty)
                InkWell(
                  onTap: () {
                    MultiplayerService.switchPlayerTeam(currentUserId, team.id);
                    setState(() {
                      _currentLobbyRoom = MultiplayerService.activeCustomRoom;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Bu takımda henüz oyuncu yok. Katılmak için dokunun!',
                      style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4), fontStyle: FontStyle.italic),
                    ),
                  ),
                )
              else
                ...teamPlayers.map((player) {
                  final isCaptain = teamCaptain?.id == player.id;
                  return _buildPlayerTile(player, room, isHost, isCaptain: isCaptain);
                }),
            ],
          ),
        );
      },
    );
  }

  /// Takım Kaptanının Rengi Değiştirebilmesi için Renk Seçici Modalı
  void _showTeamColorPicker(String teamId) {
    const palette = [
      Color(0xFFEF4444), // Kırmızı
      Color(0xFF0284C7), // Mavi
      Color(0xFF10B981), // Yeşil
      Color(0xFFF59E0B), // Turuncu / Amber
      Color(0xFF8B5CF6), // Mor
      Color(0xFFEC4899), // Pembe
      Color(0xFF14B8A6), // Teal
      Color(0xFFEAB308), // Sarı
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Takım Rengini Seç 🎨', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: palette.map((col) {
            return InkWell(
              onTap: () {
                MultiplayerService.updateTeamColor(teamId, col);
                setState(() {
                  _currentLobbyRoom = MultiplayerService.activeCustomRoom;
                });
                Navigator.of(ctx).pop();
              },
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: col,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(color: col.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 3)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Bireysel Görünüm
  Widget _buildIndividualRosterView(CustomRoom room, bool isHost) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: room.players.length,
      itemBuilder: (context, index) {
        final player = room.players[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
          ),
          child: _buildPlayerTile(player, room, isHost),
        );
      },
    );
  }

  Widget _buildPlayerTile(RoomPlayer player, CustomRoom room, bool isHost, {bool isCaptain = false}) {
    final currentUserId = context.read<ProfileController>().player.id;
    final playerObj = Player(
      id: player.id,
      name: player.name,
      avatarEmoji: player.avatarEmoji,
      avatarUrl: player.avatarUrl,
      tag: player.tag.startsWith('#BOT-')
          ? '#KW-${player.tag.replaceFirst('#BOT-', '')}'
          : player.tag,
      level: player.level,
      trophies: player.trophies,
      title: 'Kelime Ustası',
      isBot: player.isBot,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () {
                PlayerProfileModal.show(context, playerObj);
              },
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                child: Row(
                  children: [
                    AvatarBadge(
                      player: playerObj,
                      size: 36,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                player.name,
                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Colors.white),
                              ),
                              if (isCaptain) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(6)),
                                  child: const Text('👑 KAPTAN', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.black)),
                                ),
                              ],
                              if (player.isHost) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(6)),
                                  child: const Text('HOST', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.black)),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            '${player.trophies} Kupa • Sv. ${player.level}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bireysel Modda Oyuncu Renk Seçimi
          if (!room.isTeamMode) ...[
            InkWell(
              onTap: (player.id == currentUserId || (isHost && player.isBot))
                  ? () => _showPlayerColorPicker(player.id)
                  : null,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: player.effectiveColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: player.effectiveColor, width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: player.effectiveColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (player.id == currentUserId || (isHost && player.isBot)) ...[
                      const SizedBox(width: 5),
                      const Icon(Icons.palette_rounded, size: 13, color: Colors.white70),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Host için Oyuncuyu Çıkarma (Host diğerlerinin takımını zorla değiştiremez)
          if (isHost && !player.isHost) ...[
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Color(0xFFEF4444), size: 18),
              onPressed: () {
                MultiplayerService.removePlayerFromRoom(player.id);
                setState(() {
                  _currentLobbyRoom = MultiplayerService.activeCustomRoom;
                });
              },
              tooltip: 'Odadan At',
            ),
          ],
        ],
      ),
    );
  }

  /// Bireysel Modda Oyuncunun Kendi Rengini Seçmesi için Renk Seçici Modalı
  void _showPlayerColorPicker(String playerId) {
    const palette = [
      Color(0xFF10B981), // Yeşil
      Color(0xFFEF4444), // Kırmızı
      Color(0xFF0284C7), // Mavi
      Color(0xFFF59E0B), // Turuncu
      Color(0xFF8B5CF6), // Mor
      Color(0xFFEC4899), // Pembe
      Color(0xFF14B8A6), // Teal
      Color(0xFFEAB308), // Sarı
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Rengini Seç 🎨', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: palette.map((col) {
            return InkWell(
              onTap: () {
                MultiplayerService.updatePlayerColor(playerId, col);
                setState(() {
                  _currentLobbyRoom = MultiplayerService.activeCustomRoom;
                });
                Navigator.of(ctx).pop();
              },
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: col,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(color: col.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 3)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildOfflineWarningBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_off_rounded, color: Color(0xFFEF4444), size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Çevrimiçi Sunucu Bağlantısı Sağlanamadı!',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            SupabaseService.connectionError ?? 'Sunucuyla iletişim kurulamıyor. Supabase projeniz duraklatılmış (paused) olabilir.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11.5, height: 1.3),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              InkWell(
                onTap: () async {
                  final ok = await SupabaseService.checkConnection();
                  if (mounted) {
                    setState(() {});
                    if (ok) {
                      _loadPublicRooms();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Sunucu bağlantısı sağlandı! ✅'), backgroundColor: Color(0xFF10B981)),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Bağlanılamadı: ${SupabaseService.connectionError} ❌'), backgroundColor: const Color(0xFFEF4444)),
                      );
                    }
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh_rounded, size: 14, color: Colors.white),
                      SizedBox(width: 4),
                      Text('Bağlantıyı Yenile', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _showServerSettingsDialog,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.settings_rounded, size: 14, color: Colors.white),
                      SizedBox(width: 4),
                      Text('Sunucu Ayarı', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showServerSettingsDialog() {
    final urlController = TextEditingController(text: SupabaseService.supabaseUrl);
    final keyController = TextEditingController(text: SupabaseService.supabaseAnonKey);
    bool isTesting = false;
    String? testResult = SupabaseService.connectionError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(
                  SupabaseService.isReachable ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                  color: SupabaseService.isReachable ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Sunucu Bağlantısı',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: SupabaseService.isReachable
                          ? const Color(0xFF065F46).withValues(alpha: 0.3)
                          : const Color(0xFF991B1B).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: SupabaseService.isReachable ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      ),
                    ),
                    child: Text(
                      SupabaseService.isReachable
                          ? '✅ Çevrimiçi sunucuya başarıyla bağlı! Canlı odalar ve eşleşme aktif.'
                          : '⚠️ Sunucu Durumu: ${SupabaseService.connectionError ?? "Bağlantı kurulamadı."}\n\nİpucu: Supabase paneline (supabase.com) girip projenizi "Restore / Unpause" yapınız veya yeni proje bilgilerinizi giriniz.',
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Supabase Project URL:', style: TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: urlController,
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Supabase Publishable / Anon Key:', style: TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: keyController,
                    obscureText: true,
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                  if (testResult != null) ...[
                    const SizedBox(height: 10),
                    Text(testResult!, style: const TextStyle(fontSize: 11, color: Color(0xFFF59E0B))),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Kapat', style: TextStyle(color: AppColors.textMuted)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
                onPressed: isTesting
                    ? null
                    : () async {
                        setDialogState(() => isTesting = true);
                        final success = await SupabaseService.updateCredentials(
                          newUrl: urlController.text.trim(),
                          newKey: keyController.text.trim(),
                        );
                        if (mounted) setState(() {});
                        setDialogState(() {
                          isTesting = false;
                          testResult = success ? '✅ Bağlantı başarılı!' : SupabaseService.connectionError;
                        });
                        if (success) {
                          _loadPublicRooms();
                        }
                      },
                child: isTesting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Test Et & Kaydet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ],
          );
        },
      ),
    );
  }
}

