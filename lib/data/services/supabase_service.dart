import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/friend.dart';
import '../models/player.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://qntrnqstskglkmonemym.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_Lq14ZJIaBsrDf1n2Ce5dAA_iqX82Hpz';

  static SupabaseClient? _client;
  static bool _isInitialized = false;

  static SupabaseClient? get client => _client;
  static bool get isInitialized => _isInitialized;

  /// Supabase istemcisini başlatır (Hata durumunda offline moda düşer, çökmez)
  static Future<void> initialize() async {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseAnonKey,
      );
      _client = Supabase.instance.client;
      _isInitialized = true;
      debugPrint('Supabase başarıyla bağlandı: $supabaseUrl');
    } catch (e) {
      debugPrint('Supabase başlatma uyarısı (Offline modda çalışılıyor): $e');
      _isInitialized = false;
    }
  }

  /// Şifre hashleme (SHA-256)
  static String hashPassword(String password) {
    final bytes = utf8.encode(password.trim());
    return sha256.convert(bytes).toString();
  }

  /// 1. Kullanıcı Girişi (app_users tablosu üzerinden)
  static Future<Player?> login({
    required String username,
    required String password,
  }) async {
    if (!_isInitialized || _client == null) return null;

    try {
      final cleanUsername = username.trim().toLowerCase();
      final passwordHash = hashPassword(password);

      final response = await _client!
          .from('app_users')
          .select()
          .ilike('username', cleanUsername)
          .maybeSingle();

      if (response == null) return null;

      // Şifre hash kontrolü (veya düz metin kontrolü)
      final storedHash = response['password_hash'] ?? response['password'];
      if (storedHash != null && storedHash != passwordHash && storedHash != password) {
        return null;
      }

      // progress_data JSONB'den Kelime Savaşı verilerini çek
      final progressData = response['progress_data'] as Map<String, dynamic>? ?? {};
      final ksData = progressData['kelime_savasi'] as Map<String, dynamic>? ?? {};

      return Player(
        id: response['id']?.toString() ?? 'usr_${DateTime.now().millisecondsSinceEpoch}',
        name: response['username']?.toString() ?? username,
        tag: response['tag']?.toString() ?? '#KW-${1000 + Random().nextInt(9000)}',
        avatarEmoji: response['avatar']?.toString() ?? '👑',
        title: response['title']?.toString() ?? 'Sözlük Savaşçısı',
        trophies: (ksData['trophies'] as num?)?.toInt() ?? (response['trophies'] as num?)?.toInt() ?? 1200,
        level: (ksData['level'] as num?)?.toInt() ?? 5,
        isBot: false,
        email: response['email']?.toString(),
        isEmailVerified: response['email_verified'] == true,
      );
    } catch (e) {
      debugPrint('Login hatası: $e');
      return null;
    }
  }

  /// 2. Yeni Kullanıcı Kaydı (app_users tablosuna kayıt)
  static Future<Player?> register({
    required String username,
    required String password,
    String? email,
    bool isEmailVerified = false,
    String avatarEmoji = '👑',
  }) async {
    if (!_isInitialized || _client == null) return null;

    try {
      final cleanUsername = username.trim();
      final passwordHash = hashPassword(password);
      final tag = '#KW-${1000 + Random().nextInt(9000)}';

      final initialProgressData = {
        'kelime_savasi': {
          'trophies': 1200,
          'level': 1,
          'wins': 0,
          'losses': 0,
        }
      };

      final insertData = {
        'username': cleanUsername,
        'password_hash': passwordHash,
        'tag': tag,
        'avatar': avatarEmoji,
        'email': (email != null && email.isNotEmpty) ? email : null,
        'email_verified': isEmailVerified,
        'progress_data': initialProgressData,
      };

      final response = await _client!
          .from('app_users')
          .insert(insertData)
          .select()
          .single();

      return Player(
        id: response['id']?.toString() ?? 'usr_${DateTime.now().millisecondsSinceEpoch}',
        name: cleanUsername,
        tag: tag,
        avatarEmoji: avatarEmoji,
        title: 'Çaylak Düellocu',
        trophies: 1200,
        level: 1,
        isBot: false,
        email: email,
        isEmailVerified: isEmailVerified,
      );
    } catch (e) {
      debugPrint('Register hatası: $e');
      return null;
    }
  }

  /// 3. Oyun İlerlemesini app_users -> progress_data JSONB içine senkronize et
  static Future<void> syncPlayerProgress({
    required String userId,
    required int trophies,
    required int wins,
    required int losses,
  }) async {
    if (!_isInitialized || _client == null) return;

    try {
      // Mevcut progress_data'yı al
      final userRow = await _client!
          .from('app_users')
          .select('progress_data')
          .eq('id', userId)
          .maybeSingle();

      Map<String, dynamic> progressData = {};
      if (userRow != null && userRow['progress_data'] != null) {
        progressData = Map<String, dynamic>.from(userRow['progress_data'] as Map);
      }

      progressData['kelime_savasi'] = {
        'trophies': trophies,
        'wins': wins,
        'losses': losses,
        'last_active': DateTime.now().toIso8601String(),
      };

      await _client!
          .from('app_users')
          .update({'progress_data': progressData})
          .eq('id', userId);
    } catch (e) {
      debugPrint('Progress sync hatası: $e');
    }
  }

  /// 4. Genel Arkadaş Listesini Çekme (app_friends tablosu - Hızlı & Toplu Sorgu)
  static Future<List<Friend>> fetchFriends({required String userId}) async {
    if (!_isInitialized || _client == null) return [];

    try {
      // app_friends tablosunda kullanıcıya ait ilişkileri çek (2s zaman aşımı)
      final rows = await _client!
          .from('app_friends')
          .select()
          .or('user_id.eq.$userId,friend_id.eq.$userId')
          .timeout(const Duration(milliseconds: 2000));

      final targetIds = <String>{};
      for (final r in (rows as List)) {
        final targetId = r['user_id'] == userId ? r['friend_id'] : r['user_id'];
        if (targetId != null && targetId.toString().isNotEmpty) {
          targetIds.add(targetId.toString());
        }
      }

      if (targetIds.isEmpty) return [];

      // N+1 sorgu yerine TEK toplu sorgu ile tüm arkadaş profillerini anında çek
      final users = await _client!
          .from('app_users')
          .select('id, username, tag, avatar, title, trophies, progress_data')
          .inFilter('id', targetIds.toList())
          .timeout(const Duration(milliseconds: 2000));

      final List<Friend> friendsList = [];
      for (final friendUser in (users as List)) {
        final progress = friendUser['progress_data'] as Map<String, dynamic>? ?? {};
        final ks = progress['kelime_savasi'] as Map<String, dynamic>? ?? {};

        friendsList.add(
          Friend(
            id: friendUser['id']?.toString() ?? '',
            name: friendUser['username']?.toString() ?? 'Oyuncu',
            tag: friendUser['tag']?.toString() ?? '#KW-0000',
            avatarEmoji: friendUser['avatar']?.toString() ?? '🎮',
            title: friendUser['title']?.toString() ?? 'Sözlük Savaşçısı',
            trophies: (ks['trophies'] as num?)?.toInt() ?? (friendUser['trophies'] as num?)?.toInt() ?? 1200,
            level: (ks['level'] as num?)?.toInt() ?? 5,
            isOnline: true,
          ),
        );
      }

      return friendsList;
    } catch (e) {
      debugPrint('Fetch friends hatası: $e');
      return [];
    }
  }

  /// 5. Arkadaş Ekleme (app_friends tablosuna karşılıklı ilişki ekleme)
  static Future<bool> addFriend({
    required String currentUserId,
    required String targetTagOrUsername,
  }) async {
    if (!_isInitialized || _client == null) return false;

    try {
      final clean = targetTagOrUsername.trim();

      // Hedef kullanıcıyı bul
      final targetUser = await _client!
          .from('app_users')
          .select('id')
          .or('tag.eq.$clean,username.ilike.$clean')
          .maybeSingle();

      if (targetUser == null) return false;
      final targetId = targetUser['id'];

      if (targetId == currentUserId) return false;

      // app_friends tablosuna ekle
      await _client!.from('app_friends').insert({
        'user_id': currentUserId,
        'friend_id': targetId,
        'status': 'accepted',
      });

      return true;
    } catch (e) {
      debugPrint('Add friend hatası: $e');
      return false;
    }
  }
}
