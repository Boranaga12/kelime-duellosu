import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/bot_ai_engine.dart';
import '../models/custom_room.dart';
import '../models/player.dart';
import 'lan_discovery_service.dart';
import 'supabase_service.dart';

class MultiplayerService {
  static RealtimeChannel? _currentChannel;
  static String? _activeRoomCode;
  static CustomRoom? _activeCustomRoom;

  static String? get activeRoomCode => _activeRoomCode;
  static bool get isInRoom => _activeRoomCode != null;
  static CustomRoom? get activeCustomRoom => _activeCustomRoom;

  // Gerçek Aktif Odalar (Sahte/Test kullanıcısı barındırmaz, sadece gerçek odalar bulunur)
  static final List<CustomRoom> _activeRooms = [];

  static void Function(CustomRoom updatedRoom)? onRoomStateChanged;
  static void Function(String categoryId)? onGameStartedByHost;
  static void Function(Map<String, dynamic> payload)? onWordReceived;
  static void Function(String emoji, String senderId)? onEmoteReceived;
  static Timer? _quickMatchPollTimer;

  static const String _defaultHostUuid = '49dd1f11-f420-4201-9c4d-1ed6256cdc87';

  static bool _isValidUuid(String? id) {
    if (id == null) return false;
    final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    return uuidRegex.hasMatch(id);
  }

  /// 6 Haneli rastgele oda kodu üretir
  static String generateRoomCode() {
    final rand = Random();
    return (100000 + rand.nextInt(900000)).toString();
  }

  /// 1. Oda Kurma (Host) - 2 Kişilik Hızlı Oda
  static Future<String?> createRoom({
    required Player host,
    required void Function(Player guest) onGuestJoined,
    required void Function(Map<String, dynamic> payload) onWordReceived,
    required void Function(String emoji, String senderId) onEmoteReceived,
  }) async {
    final roomCode = generateRoomCode();
    _activeRoomCode = roomCode;

    try {
      if (SupabaseService.isInitialized && SupabaseService.client != null) {
        final safeHostUserId = _isValidUuid(host.id) ? host.id : _defaultHostUuid;
        // game_rooms tablosuna ekle
        await SupabaseService.client!.from('game_rooms').insert({
          'room_code': roomCode,
          'room_name': '${host.name} Odası',
          'host_user_id': safeHostUserId,
          'host_username': host.name,
          'host_display_name': host.name,
          'status': 'waiting',
          'game_mode': 'classic',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        // Realtime kanalına abone ol
        _currentChannel = SupabaseService.client!.channel('room_$roomCode');

        _currentChannel!
            .onBroadcast(
              event: 'guest_joined',
              callback: (payload) {
                final guest = Player(
                  id: payload['id']?.toString() ?? 'guest',
                  name: payload['name']?.toString() ?? 'Misafir',
                  tag: payload['tag']?.toString() ?? '#KW-0000',
                  avatarEmoji: payload['avatar']?.toString() ?? '🎮',
                  trophies: (payload['trophies'] as num?)?.toInt() ?? 1200,
                  level: (payload['level'] as num?)?.toInt() ?? 5,
                );
                onGuestJoined(guest);
              },
            )
            .onBroadcast(
              event: 'word_played',
              callback: (payload) => onWordReceived(payload),
            )
            .onBroadcast(
              event: 'emote_sent',
              callback: (payload) => onEmoteReceived(
                payload['emoji']?.toString() ?? '🤔',
                payload['sender_id']?.toString() ?? '',
              ),
            )
            .subscribe();
      }
    } catch (e) {
      debugPrint('Create room Supabase hatası: $e');
    }

    return roomCode;
  }

  /// 2. Odaya Katılma (Guest) - 2 Kişilik Hızlı Oda
  static Future<bool> joinRoom({
    required String roomCode,
    required Player guest,
    required void Function(Map<String, dynamic> payload) onWordReceived,
    required void Function(String emoji, String senderId) onEmoteReceived,
  }) async {
    _activeRoomCode = roomCode;

    try {
      if (SupabaseService.isInitialized && SupabaseService.client != null) {
        // game_rooms tablosunu güncelle
        final updateMap = <String, dynamic>{
          'guest_display_name': guest.name,
          'guest_username': guest.name,
          'status': 'in_progress',
          'updated_at': DateTime.now().toIso8601String(),
        };
        if (_isValidUuid(guest.id)) {
          updateMap['guest_user_id'] = guest.id;
        }

        await SupabaseService.client!
            .from('game_rooms')
            .update(updateMap)
            .eq('room_code', roomCode);

        // Realtime kanalına abone ol
        _currentChannel = SupabaseService.client!.channel('room_$roomCode');

        _currentChannel!
            .onBroadcast(
              event: 'word_played',
              callback: (payload) => onWordReceived(payload),
            )
            .onBroadcast(
              event: 'emote_sent',
              callback: (payload) => onEmoteReceived(
                payload['emoji']?.toString() ?? '🤔',
                payload['sender_id']?.toString() ?? '',
              ),
            )
            .subscribe((status, error) {
              if (status == RealtimeSubscribeStatus.subscribed) {
                // Host'a odaya katıldığımızı bildir
                _currentChannel?.sendBroadcastMessage(
                  event: 'guest_joined',
                  payload: {
                    'id': guest.id,
                    'name': guest.name,
                    'tag': guest.tag,
                    'avatar': guest.avatarEmoji,
                    'trophies': guest.trophies,
                    'level': guest.level,
                  },
                );
              }
            });

        return true;
      }
    } catch (e) {
      debugPrint('Join room Supabase hatası: $e');
    }

    return true; // Test edilebilir mock modu
  }

  /// 3. Kelime Gönderme Yayınla
  static void broadcastWord({
    required String word,
    required bool isCorrect,
    required String playerId,
    String? originalTypo,
  }) {
    _currentChannel?.sendBroadcastMessage(
      event: 'word_played',
      payload: {
        'word': word,
        'is_correct': isCorrect,
        'player_id': playerId,
        'original_typo': originalTypo,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// 4. Emote Gönderme Yayınla
  static void broadcastEmote({
    required String emoji,
    required String senderId,
  }) {
    _currentChannel?.sendBroadcastMessage(
      event: 'emote_sent',
      payload: {
        'emoji': emoji,
        'sender_id': senderId,
      },
    );
  }

  /// 5. Odadan Ayrılma & Temizleme
  static void leaveRoom() {
    LanDiscoveryService.stopBroadcasting();
    LanDiscoveryService.stopListening();
    if (_currentChannel != null) {
      _currentChannel?.unsubscribe();
      _currentChannel = null;
    }
    _activeRoomCode = null;
  }

  /// 6. Hızlı Düello için gerçek odası bulur veya yeni oda açıp bekler
  static Future<void> findOrCreateQuickMatch({
    required Player currentPlayer,
    required void Function(Player opponent, bool isHost, String roomCode) onMatchFound,
    required void Function(Map<String, dynamic> payload) onWordReceived,
    required void Function(String emoji, String senderId) onEmoteReceived,
  }) async {
    if (!SupabaseService.isInitialized || SupabaseService.client == null) {
      return;
    }

    try {
      // 1. Bekleyen aktif bir oda var mı ara
      final rooms = await SupabaseService.client!
          .from('game_rooms')
          .select()
          .eq('status', 'waiting')
          .neq('host_username', currentPlayer.name)
          .order('created_at', ascending: false)
          .limit(1);

      if (rooms.isNotEmpty) {
        final room = rooms.first;
        final roomCode = room['room_code'].toString();
        final hostOpponent = Player(
          id: room['host_user_id']?.toString() ?? 'host_player',
          name: room['host_display_name']?.toString() ?? room['host_username']?.toString() ?? 'Düellocu',
          tag: '#KW-${1000 + Random().nextInt(9000)}',
          avatarEmoji: '⚡',
          trophies: 1200,
          level: 5,
        );

        await joinRoom(
          roomCode: roomCode,
          guest: currentPlayer,
          onWordReceived: onWordReceived,
          onEmoteReceived: onEmoteReceived,
        );

        onMatchFound(hostOpponent, false, roomCode);
        return;
      }

      // 2. Yoksa kendimiz oda kuralım ve bekleyelim
      await createRoom(
        host: currentPlayer,
        onGuestJoined: (guest) {
          _quickMatchPollTimer?.cancel();
          _quickMatchPollTimer = null;
          onMatchFound(guest, true, _activeRoomCode ?? '');
        },
        onWordReceived: onWordReceived,
        onEmoteReceived: onEmoteReceived,
      );

      // Yedek Yoklama: Broadcast paketi ağda düşerse veritabanından misafir oyuncuyu yakala (1.5s aralıkla)
      _quickMatchPollTimer?.cancel();
      _quickMatchPollTimer = Timer.periodic(const Duration(milliseconds: 1500), (t) async {
        if (_activeRoomCode == null || !SupabaseService.isInitialized || SupabaseService.client == null) {
          t.cancel();
          return;
        }
        try {
          final res = await SupabaseService.client!
              .from('game_rooms')
              .select()
              .eq('room_code', _activeRoomCode!)
              .maybeSingle();

          if (res != null && (res['guest_display_name'] != null || res['guest_user_id'] != null)) {
            t.cancel();
            _quickMatchPollTimer = null;
            final guest = Player(
              id: res['guest_user_id']?.toString() ?? 'guest_${DateTime.now().millisecondsSinceEpoch}',
              name: res['guest_display_name']?.toString() ?? res['guest_username']?.toString() ?? 'Misafir',
              tag: '#KW-${1000 + Random().nextInt(9000)}',
              avatarEmoji: '🎮',
              trophies: 1200,
              level: 5,
            );
            onMatchFound(guest, true, _activeRoomCode ?? '');
          }
        } catch (_) {}
      });
    } catch (e) {
      debugPrint('findOrCreateQuickMatch hatası: $e');
    }
  }

  /// Hızlı arama iptal edildiğinde kurulan odayı sil
  static Future<void> cancelQuickMatch() async {
    _quickMatchPollTimer?.cancel();
    _quickMatchPollTimer = null;
    if (_activeRoomCode != null && SupabaseService.isInitialized && SupabaseService.client != null) {
      try {
        await SupabaseService.client!
            .from('game_rooms')
            .delete()
            .eq('room_code', _activeRoomCode!);
      } catch (_) {}
    }
    leaveRoom();
  }

  static Map<String, dynamic>? _parseJsonMap(dynamic data) {
    if (data == null) return null;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return null;
  }

  // ==========================================
  // GELİŞMİŞ ÖZEL ODA SİSTEMİ (2-6 Kişi & Takımlı - Sadece Gerçek Veriler)
  // ==========================================

  /// Realtime kanalına abone olur ve oda olaylarını dinler (Lobi + Oyun İçi Kelimeler & Tepkiler)
  static void _subscribeToCustomRoomChannel(String roomCode) {
    if (!SupabaseService.isInitialized || SupabaseService.client == null) return;

    try {
      if (_currentChannel != null) {
        _currentChannel?.unsubscribe();
      }

      _currentChannel = SupabaseService.client!.channel('custom_room_$roomCode');

      _currentChannel!
          .onBroadcast(
            event: 'room_updated',
            callback: (payload) {
              final roomData = _parseJsonMap(payload['room']);
              if (roomData != null) {
                final updatedRoom = CustomRoom.fromJson(roomData);
                _activeCustomRoom = updatedRoom;
                final idx = _activeRooms.indexWhere((r) => r.roomCode == updatedRoom.roomCode);
                if (idx != -1) {
                  _activeRooms[idx] = updatedRoom;
                } else {
                  _activeRooms.add(updatedRoom);
                }
                onRoomStateChanged?.call(updatedRoom);
              }
            },
          )
          .onBroadcast(
            event: 'game_started',
            callback: (payload) {
              final catId = payload['category_id']?.toString() ?? '';
              onGameStartedByHost?.call(catId);
            },
          )
          .onBroadcast(
            event: 'word_played',
            callback: (payload) {
              onWordReceived?.call(payload);
            },
          )
          .onBroadcast(
            event: 'emote_sent',
            callback: (payload) {
              onEmoteReceived?.call(
                payload['emoji']?.toString() ?? '🤔',
                payload['sender_id']?.toString() ?? '',
              );
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Realtime custom room abonelik hatası: $e');
    }
  }

  /// Veritabanından odayı doğrudan eşitler (Broadcast kaçarsa yedek senkronizasyon mekanizması)
  static Future<CustomRoom?> syncLobbyFromDatabase(String roomCode) async {
    if (!SupabaseService.isInitialized || SupabaseService.client == null) {
      return _activeCustomRoom;
    }

    try {
      final res = await SupabaseService.client!
          .from('game_rooms')
          .select()
          .eq('room_code', roomCode)
          .maybeSingle()
          .timeout(const Duration(milliseconds: 2000));

      if (res != null && res['board_state'] != null) {
        final parsedMap = _parseJsonMap(res['board_state']);
        if (parsedMap != null) {
          final serverRoom = CustomRoom.fromJson(parsedMap);
          _activeCustomRoom = serverRoom;
          final idx = _activeRooms.indexWhere((r) => r.roomCode == roomCode);
          if (idx != -1) {
            _activeRooms[idx] = serverRoom;
          } else {
            _activeRooms.add(serverRoom);
          }
          onRoomStateChanged?.call(serverRoom);
          return serverRoom;
        }
      }
    } catch (e) {
      debugPrint('syncLobbyFromDatabase hatası: $e');
    }
    return _activeCustomRoom;
  }

  /// Oda güncellemesini Realtime ile tüm katılımcılara yayınlar
  static void _broadcastRoomUpdate(CustomRoom room) {
    _currentChannel?.sendBroadcastMessage(
      event: 'room_updated',
      payload: {'room': room.toJson()},
    );
  }

  /// Mevcut açık gerçek odaları listeler (Sahte/Mock oda ASLA eklenmez)
  static Future<List<CustomRoom>> fetchPublicRooms() async {
    // 1. Önce yerel ağdaki (LAN/Wi-Fi) odaları dinlemeye başla
    LanDiscoveryService.startListening(
      onRoomDiscovered: (lanRoom) {
        final idx = _activeRooms.indexWhere((r) => r.roomCode == lanRoom.roomCode);
        if (idx == -1) {
          _activeRooms.add(lanRoom);
        } else {
          _activeRooms[idx] = lanRoom;
        }
        onRoomStateChanged?.call(lanRoom);
      },
    );

    // 2. Bulut sunucudan (Supabase) beklemedeki gerçek odaları çek
    if (SupabaseService.isInitialized && SupabaseService.client != null) {
      try {
        final response = await SupabaseService.client!
            .from('game_rooms')
            .select()
            .eq('status', 'waiting')
            .order('created_at', ascending: false)
            .timeout(const Duration(milliseconds: 3000));

        final List<CustomRoom> serverRooms = [];
        for (final row in (response as List)) {
          if (row['board_state'] != null) {
            try {
              final parsedMap = _parseJsonMap(row['board_state']);
              if (parsedMap != null) {
                final r = CustomRoom.fromJson(parsedMap);
                final humanPlayers = r.players.where((p) => !p.isBot).toList();
                if (humanPlayers.isNotEmpty) {
                  serverRooms.add(r);
                } else {
                  // Sadece bot kalmış veya boş odaları temizle
                  try {
                    SupabaseService.client!.from('game_rooms').delete().eq('room_code', r.roomCode);
                  } catch (_) {}
                }
              }
            } catch (_) {}
          } else {
            final hostName = row['host_display_name']?.toString() ?? row['host_username']?.toString() ?? 'Kurucu';
            serverRooms.add(CustomRoom(
              id: row['id']?.toString() ?? row['room_code'].toString(),
              roomCode: row['room_code'].toString(),
              roomName: row['room_name']?.toString() ?? '$hostName Odası',
              hostId: row['host_user_id']?.toString() ?? '',
              hostName: hostName,
              players: [
                RoomPlayer(
                  id: row['host_user_id']?.toString() ?? '',
                  name: hostName,
                  avatarEmoji: '👑',
                  isHost: true,
                ),
              ],
            ));
          }
        }

        // Yerel listeyle senkronize et
        for (final sr in serverRooms) {
          final idx = _activeRooms.indexWhere((r) => r.roomCode == sr.roomCode);
          if (idx == -1) {
            _activeRooms.add(sr);
          } else {
            _activeRooms[idx] = sr;
          }
        }
      } catch (e) {
        debugPrint('fetchPublicRooms Supabase hatası: $e');
      }
    }

    // Yalnızca geçerli, beklemede olan ve oyuncusu olan gerçek odaları döndür
    return _activeRooms.where((r) => r.status == 'waiting' && r.players.isNotEmpty).toList();
  }

  /// Gelişmiş Özel Oda Oluşturur (2 - 5 Takım)
  static Future<CustomRoom> createAdvancedRoom({
    required String roomName,
    required Player host,
    bool isLocked = false,
    String? password,
    int maxPlayers = 4,
    bool isTeamMode = true,
    int teamCount = 2,
    List<TeamConfig>? teams,
    int targetWins = 2,
  }) async {
    final roomCode = generateRoomCode();
    _activeRoomCode = roomCode;

    final defaultTeams = teams ?? [
      const TeamConfig(id: 'team_1', name: 'Kırmızı Takım', color: Color(0xFFEF4444)),
      const TeamConfig(id: 'team_2', name: 'Mavi Takım', color: Color(0xFF0284C7)),
      if (teamCount >= 3)
        const TeamConfig(id: 'team_3', name: 'Yeşil Takım', color: Color(0xFF10B981)),
      if (teamCount >= 4)
        const TeamConfig(id: 'team_4', name: 'Turuncu Takım', color: Color(0xFFF59E0B)),
      if (teamCount >= 5)
        const TeamConfig(id: 'team_5', name: 'Mor Takım', color: Color(0xFF8B5CF6)),
    ];

    final hostPlayer = RoomPlayer(
      id: host.id,
      name: host.name,
      avatarEmoji: host.avatarEmoji,
      tag: host.tag,
      level: host.level,
      trophies: host.trophies,
      teamId: 'team_1',
      isHost: true,
      isBot: false,
      colorValue: const Color(0xFF10B981).toARGB32(),
    );

    final newRoom = CustomRoom(
      id: 'room_$roomCode',
      roomCode: roomCode,
      roomName: roomName.trim().isEmpty ? '${host.name} Odası' : roomName.trim(),
      hostId: host.id,
      hostName: host.name,
      isLocked: isLocked,
      password: (isLocked && password != null && password.trim().isNotEmpty) ? password.trim() : null,
      maxPlayers: maxPlayers,
      isTeamMode: isTeamMode,
      teamCount: teamCount,
      teams: defaultTeams,
      targetWins: targetWins,
      players: [hostPlayer],
      status: 'waiting',
    );

    _activeCustomRoom = newRoom;
    _activeRooms.removeWhere((r) => r.roomCode == roomCode);
    _activeRooms.insert(0, newRoom);

    // Supabase kaydı (Doğru sütunlar ve UUID ile)
    if (SupabaseService.isInitialized && SupabaseService.client != null) {
      final safeHostUserId = _isValidUuid(host.id) ? host.id : _defaultHostUuid;
      try {
        await SupabaseService.client!.from('game_rooms').insert({
          'room_code': roomCode,
          'room_name': newRoom.roomName,
          'host_user_id': safeHostUserId,
          'host_username': host.name,
          'host_display_name': host.name,
          'status': 'waiting',
          'game_mode': isTeamMode ? 'team' : 'classic',
          'board_state': newRoom.toJson(),
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint('createAdvancedRoom Supabase hatası: $e');
      }
    }

    // Yerel Wi-Fi / Hotspot üzerinden de yayın yap
    unawaited(LanDiscoveryService.startBroadcasting(newRoom));

    _subscribeToCustomRoomChannel(roomCode);

    return newRoom;
  }

  /// Gelişmiş Özel Odaya Katılma (Çift girmeyi ve slot işgalini kesin engeller)
  static Future<JoinRoomResult> joinAdvancedRoom({
    required String roomCode,
    required Player player,
    String? password,
  }) async {
    final cleanCode = roomCode.trim();

    // 1. Odayı bul (Önce yerel liste / LAN, sonra Supabase)
    CustomRoom? targetRoom;
    final localIndex = _activeRooms.indexWhere((r) => r.roomCode == cleanCode);
    if (localIndex != -1) {
      targetRoom = _activeRooms[localIndex];
    } else if (SupabaseService.isInitialized && SupabaseService.client != null) {
      try {
        final res = await SupabaseService.client!
            .from('game_rooms')
            .select()
            .eq('room_code', cleanCode)
            .maybeSingle();

        if (res != null) {
          final parsedMap = _parseJsonMap(res['board_state']);
          if (parsedMap != null) {
            targetRoom = CustomRoom.fromJson(parsedMap);
          } else {
            final hName = res['host_display_name']?.toString() ?? res['host_username']?.toString() ?? 'Kurucu';
            targetRoom = CustomRoom(
              id: res['id']?.toString() ?? cleanCode,
              roomCode: cleanCode,
              roomName: res['room_name']?.toString() ?? '$hName Odası',
              hostId: res['host_user_id']?.toString() ?? '',
              hostName: hName,
              players: [
                RoomPlayer(
                  id: res['host_user_id']?.toString() ?? '',
                  name: hName,
                  avatarEmoji: '👑',
                  isHost: true,
                ),
              ],
            );
          }
          _activeRooms.add(targetRoom);
        }
      } catch (e) {
        debugPrint('joinAdvancedRoom sorgu hatası: $e');
      }
    }

    if (targetRoom == null) {
      return const JoinRoomResult(success: false, message: 'Oda bulunamadı! Lütfen kodu kontrol edin.');
    }

    if (targetRoom.isLocked && targetRoom.password != password) {
      return const JoinRoomResult(success: false, message: 'Hatalı oda şifresi!');
    }

    if (targetRoom.status != 'waiting') {
      return const JoinRoomResult(success: false, message: 'Bu odada oyun zaten başlamış!');
    }

    // 2. ÇİFT GİRİŞ KONTROLÜ: Oyuncu zaten bu odada varsa TEKRAR EKLEME!
    final alreadyInRoom = targetRoom.players.any((p) => p.id == player.id);
    if (alreadyInRoom) {
      _activeCustomRoom = targetRoom;
      _activeRoomCode = cleanCode;
      _subscribeToCustomRoomChannel(cleanCode);
      return const JoinRoomResult(success: true, message: 'Odaya tekrar katıldınız.');
    }

    // 3. Kapasite kontrolü
    if (targetRoom.players.length >= targetRoom.maxPlayers) {
      return JoinRoomResult(success: false, message: 'Oda dolu! (Maksimum ${targetRoom.maxPlayers} kişi)');
    }

    // 4. Takım ataması
    String assignedTeam = 'team_1';
    if (targetRoom.isTeamMode && targetRoom.teams.isNotEmpty) {
      final teamCounts = <String, int>{for (var t in targetRoom.teams) t.id: 0};
      for (var p in targetRoom.players) {
        teamCounts[p.teamId] = (teamCounts[p.teamId] ?? 0) + 1;
      }
      assignedTeam = teamCounts.entries
          .reduce((a, b) => a.value <= b.value ? a : b)
          .key;
    }

    const playerPalette = [
      Color(0xFF10B981), // Yeşil
      Color(0xFFEF4444), // Kırmızı
      Color(0xFF0284C7), // Mavi
      Color(0xFFF59E0B), // Turuncu
      Color(0xFF8B5CF6), // Mor
      Color(0xFFEC4899), // Pembe
    ];
    final colorIdx = targetRoom.players.length % playerPalette.length;

    final newRoomPlayer = RoomPlayer(
      id: player.id,
      name: player.name,
      avatarEmoji: player.avatarEmoji,
      tag: player.tag,
      level: player.level,
      trophies: player.trophies,
      teamId: assignedTeam,
      isHost: false,
      isBot: false,
      colorValue: playerPalette[colorIdx].toARGB32(),
    );

    final updatedPlayers = List<RoomPlayer>.from(targetRoom.players)..add(newRoomPlayer);
    final updatedRoom = targetRoom.copyWith(players: updatedPlayers);

    final idx = _activeRooms.indexWhere((r) => r.roomCode == cleanCode);
    if (idx != -1) {
      _activeRooms[idx] = updatedRoom;
    } else {
      _activeRooms.add(updatedRoom);
    }
    _activeCustomRoom = updatedRoom;
    _activeRoomCode = cleanCode;

    _subscribeToCustomRoomChannel(cleanCode);
    _broadcastRoomUpdate(updatedRoom);

    // Supabase senkronizasyonu
    if (SupabaseService.isInitialized && SupabaseService.client != null) {
      try {
        final updateMap = <String, dynamic>{
          'board_state': updatedRoom.toJson(),
          'guest_display_name': player.name,
          'guest_username': player.name,
          'updated_at': DateTime.now().toIso8601String(),
        };
        if (_isValidUuid(player.id)) {
          updateMap['guest_user_id'] = player.id;
        }
        await SupabaseService.client!
            .from('game_rooms')
            .update(updateMap)
            .eq('room_code', cleanCode);
      } catch (e) {
        debugPrint('joinAdvancedRoom Supabase update hatası: $e');
      }
    }

    return const JoinRoomResult(success: true, message: 'Odaya başarıyla katıldınız.');
  }

  /// Oda Ayarlarını Güncelle (Sadece Host)
  static Future<void> updateRoomSettings(CustomRoom updatedRoom) async {
    _activeCustomRoom = updatedRoom;
    final index = _activeRooms.indexWhere((r) => r.roomCode == updatedRoom.roomCode);
    if (index != -1) {
      _activeRooms[index] = updatedRoom;
    }

    _broadcastRoomUpdate(updatedRoom);
    LanDiscoveryService.updateBroadcastingRoom(updatedRoom);

    if (SupabaseService.isInitialized && SupabaseService.client != null) {
      try {
        await SupabaseService.client!
            .from('game_rooms')
            .update({
              'board_state': updatedRoom.toJson(),
              'room_name': updatedRoom.roomName,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('room_code', updatedRoom.roomCode);
      } catch (_) {}
    }
  }

  /// Odaya Bot Oyuncu Ekle (Test & Tek Başına Oynayabilmek için)
  static void addBotToRoom() {
    if (_activeCustomRoom == null) return;
    if (_activeCustomRoom!.players.length >= _activeCustomRoom!.maxPlayers) return;

    final existingNames = _activeCustomRoom!.players.map((p) => p.name).toList();
    final generatedBot = BotAiEngine.generateBotPlayer(existingNames: existingNames);

    String assignedTeam = 'team_1';
    if (_activeCustomRoom!.isTeamMode && _activeCustomRoom!.teams.isNotEmpty) {
      final teamCounts = <String, int>{for (var t in _activeCustomRoom!.teams) t.id: 0};
      for (var p in _activeCustomRoom!.players) {
        teamCounts[p.teamId] = (teamCounts[p.teamId] ?? 0) + 1;
      }
      assignedTeam = teamCounts.entries
          .reduce((a, b) => a.value <= b.value ? a : b)
          .key;
    }

    const playerPalette = [
      Color(0xFF10B981),
      Color(0xFFEF4444),
      Color(0xFF0284C7),
      Color(0xFFF59E0B),
      Color(0xFF8B5CF6),
      Color(0xFFEC4899),
    ];
    final botColorIdx = _activeCustomRoom!.players.length % playerPalette.length;

    final botPlayer = RoomPlayer(
      id: generatedBot.id,
      name: generatedBot.name,
      avatarEmoji: generatedBot.avatarEmoji,
      avatarUrl: generatedBot.avatarUrl,
      tag: '#KW-${Random().nextInt(9000) + 1000}',
      level: generatedBot.level,
      trophies: generatedBot.trophies,
      teamId: assignedTeam,
      isHost: false,
      isBot: true,
      colorValue: playerPalette[botColorIdx].toARGB32(),
    );

    final updatedPlayers = List<RoomPlayer>.from(_activeCustomRoom!.players)..add(botPlayer);
    final updatedRoom = _activeCustomRoom!.copyWith(players: updatedPlayers);
    updateRoomSettings(updatedRoom);
  }

  /// Oyuncuyu Odadan Çıkar (Host Kicking veya oyuncu ayrılışı)
  static void removePlayerFromRoom(String playerId) {
    if (_activeCustomRoom == null) return;
    final updatedPlayers = _activeCustomRoom!.players.where((p) => p.id != playerId).toList();
    final remainingHumans = updatedPlayers.where((p) => !p.isBot).toList();

    // Eğer odada sadece botlar kaldıysa veya oda boşaldıysa odayı sil
    if (updatedPlayers.isEmpty || remainingHumans.isEmpty) {
      final code = _activeCustomRoom!.roomCode;
      _activeRooms.removeWhere((r) => r.roomCode == code);
      _activeCustomRoom = null;
      LanDiscoveryService.stopBroadcasting();

      if (SupabaseService.isInitialized && SupabaseService.client != null) {
        try {
          SupabaseService.client!.from('game_rooms').delete().eq('room_code', code);
        } catch (_) {}
      }
      return;
    }

    final updatedRoom = _activeCustomRoom!.copyWith(players: updatedPlayers);
    updateRoomSettings(updatedRoom);
  }

  /// Bireysel modda oyuncu rengini güncelle
  static void updatePlayerColor(String playerId, Color newColor) {
    if (_activeCustomRoom == null) return;
    final updatedPlayers = _activeCustomRoom!.players.map((p) {
      if (p.id == playerId) {
        return p.copyWith(colorValue: newColor.toARGB32());
      }
      return p;
    }).toList();
    final updatedRoom = _activeCustomRoom!.copyWith(players: updatedPlayers);
    updateRoomSettings(updatedRoom);
  }

  /// Oyuncunun Takımını Değiştir (Host Yönetimi)
  static void changePlayerTeam(String playerId, String newTeamId) {
    if (_activeCustomRoom == null) return;
    final updatedPlayers = _activeCustomRoom!.players.map((p) {
      if (p.id == playerId) {
        return p.copyWith(teamId: newTeamId);
      }
      return p;
    }).toList();
    final updatedRoom = _activeCustomRoom!.copyWith(players: updatedPlayers);
    updateRoomSettings(updatedRoom);
  }

  /// Takım rengini güncelle (Takım Sahibi / Kaptanı)
  static void updateTeamColor(String teamId, Color newColor) {
    if (_activeCustomRoom == null) return;
    final updatedTeams = _activeCustomRoom!.teams.map((t) {
      if (t.id == teamId) {
        return t.copyWith(color: newColor);
      }
      return t;
    }).toList();
    final updatedRoom = _activeCustomRoom!.copyWith(teams: updatedTeams);
    updateRoomSettings(updatedRoom);
  }

  /// Oyuncunun kendi takımını değiştirmesi (Kendi isteğiyle tıklayarak)
  static void switchPlayerTeam(String playerId, String newTeamId) {
    if (_activeCustomRoom == null) return;
    final updatedPlayers = _activeCustomRoom!.players.map((p) {
      if (p.id == playerId) {
        return p.copyWith(teamId: newTeamId);
      }
      return p;
    }).toList();
    final updatedRoom = _activeCustomRoom!.copyWith(players: updatedPlayers);
    updateRoomSettings(updatedRoom);
  }

  /// Özel Odadan Ayrıl (Oyuncuyu gerçekten odadan siler, çift kayıt ve slot işgalini önler)
  static Future<void> leaveAdvancedRoom({required String playerId}) async {
    if (_activeCustomRoom == null) {
      leaveRoom();
      return;
    }

    final room = _activeCustomRoom!;
    final roomCode = room.roomCode;
    final isHost = room.hostId == playerId;

    // Oyuncuyu odadan çıkar
    final remainingPlayers = room.players.where((p) => p.id != playerId).toList();

    // Eğer odada hiç insan oyuncu kalmadıysa odayı tamamen sil
    final remainingHumans = remainingPlayers.where((p) => !p.isBot).toList();

    if (remainingPlayers.isEmpty || remainingHumans.isEmpty) {
      _activeRooms.removeWhere((r) => r.roomCode == roomCode);
      _activeCustomRoom = null;
      LanDiscoveryService.stopBroadcasting();

      if (SupabaseService.isInitialized && SupabaseService.client != null) {
        try {
          await SupabaseService.client!
              .from('game_rooms')
              .delete()
              .eq('room_code', roomCode);
        } catch (_) {}
      }
    } else {
      // Kurucu çıktıysa ve başka insan oyuncu varsa host devret
      String newHostId = room.hostId;
      String newHostName = room.hostName;

      List<RoomPlayer> updatedPlayers = remainingPlayers;
      if (isHost && remainingHumans.isNotEmpty) {
        final nextHost = remainingHumans.first;
        newHostId = nextHost.id;
        newHostName = nextHost.name;
        updatedPlayers = remainingPlayers.map((p) {
          if (p.id == nextHost.id) {
            return p.copyWith(isHost: true);
          }
          return p;
        }).toList();
      }

      final updatedRoom = room.copyWith(
        hostId: newHostId,
        hostName: newHostName,
        players: updatedPlayers,
      );

      final idx = _activeRooms.indexWhere((r) => r.roomCode == roomCode);
      if (idx != -1) {
        _activeRooms[idx] = updatedRoom;
      }
      _broadcastRoomUpdate(updatedRoom);
      LanDiscoveryService.updateBroadcastingRoom(updatedRoom);

      if (SupabaseService.isInitialized && SupabaseService.client != null) {
        try {
          final updateMap = <String, dynamic>{
            'board_state': updatedRoom.toJson(),
            'host_display_name': newHostName,
            'host_username': newHostName,
            'updated_at': DateTime.now().toIso8601String(),
          };
          if (_isValidUuid(newHostId)) {
            updateMap['host_user_id'] = newHostId;
          }
          await SupabaseService.client!
              .from('game_rooms')
              .update(updateMap)
              .eq('room_code', roomCode);
        } catch (_) {}
      }
    }

    _activeCustomRoom = null;
    leaveRoom();
  }

  /// Host maçı başlattığında tüm katılımcılara bildir
  static Future<void> broadcastGameStart(String categoryId) async {
    LanDiscoveryService.stopBroadcasting();

    _currentChannel?.sendBroadcastMessage(
      event: 'game_started',
      payload: {'category_id': categoryId},
    );

    if (_activeRoomCode != null && SupabaseService.isInitialized && SupabaseService.client != null) {
      try {
        final updateMap = <String, dynamic>{
          'status': 'in_progress',
          'updated_at': DateTime.now().toIso8601String(),
        };
        if (_activeCustomRoom != null) {
          final updatedRoom = _activeCustomRoom!.copyWith(status: 'in_progress');
          _activeCustomRoom = updatedRoom;
          updateMap['board_state'] = updatedRoom.toJson();
        }
        await SupabaseService.client!
            .from('game_rooms')
            .update(updateMap)
            .eq('room_code', _activeRoomCode!);
      } catch (_) {}
    }
  }
}

/// Odaya Katılma Sonucu Modeli
class JoinRoomResult {
  final bool success;
  final String message;

  const JoinRoomResult({
    required this.success,
    required this.message,
  });
}
