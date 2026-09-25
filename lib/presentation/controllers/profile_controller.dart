import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/player.dart';
import '../../data/services/cross_game_auth_service.dart';
import '../../data/services/supabase_service.dart';

class ProfileController extends ChangeNotifier {
  static const List<String> _guestPrefixes = [
    'Düellocu', 'KelimeAvcısı', 'SözlükKurdu', 'HarfBükücü',
    'ZihinUstası', 'SözUstası', 'YıldızOyuncu', 'KelimeSavaşçısı',
    'HızlıKalem', 'GizliDeha', 'SonKelimeci', 'AkılKüpü'
  ];

  static const List<String> _coolAvatars = [
    '👑', '⚡', '🦁', '🦊', '🦅', '🎯', '🔥', '🚀', '🐺', '🐉', '⚔️', '🌟'
  ];

  static Player _createInitialGuestPlayer() {
    final rand = Random();
    final randomNum = 100 + rand.nextInt(900);
    final prefix = _guestPrefixes[rand.nextInt(_guestPrefixes.length)];
    final avatar = _coolAvatars[rand.nextInt(_coolAvatars.length)];
    return Player(
      id: 'guest_${DateTime.now().millisecondsSinceEpoch}_$randomNum',
      name: '$prefix$randomNum',
      tag: '#KD-${1000 + rand.nextInt(9000)}',
      avatarEmoji: avatar,
      title: 'Çaylak Düellocu',
      trophies: 1200,
      level: 1,
      isBot: false,
      email: null,
      isEmailVerified: false,
    );
  }

  late Player _player;
  int _coins = 200;
  int _freezeJokers = 3;
  int _hintJokers = 3;
  int _wins = 0;
  int _losses = 0;
  bool _isLoggedIn = false;

  ProfileController() {
    _player = _createInitialGuestPlayer();
    loadSavedProfile();
  }

  Player get player => _player;
  int get coins => _coins;
  int get freezeJokers => _freezeJokers;
  int get hintJokers => _hintJokers;
  int get wins => _wins;
  int get losses => _losses;
  bool get isLoggedIn => _isLoggedIn;

  /// Cihaz hafızasındaki (SharedPreferences) benzersiz oyuncu profilini yükler
  Future<void> loadSavedProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final isLoggedIn = prefs.getBool('auth_is_logged_in') ?? false;
      if (isLoggedIn) {
        final authId = prefs.getString('auth_user_id');
        final authName = prefs.getString('auth_user_name');
        final authTag = prefs.getString('auth_user_tag');
        final authAvatar = prefs.getString('auth_user_avatar');
        final authTitle = prefs.getString('auth_user_title');
        final authEmail = prefs.getString('auth_user_email');
        final authTrophies = prefs.getInt('auth_trophies') ?? 1200;
        final authLevel = prefs.getInt('auth_level') ?? 5;

        if (authId != null && authName != null) {
          _isLoggedIn = true;
          _player = Player(
            id: authId,
            name: authName,
            tag: authTag ?? '#KD-1000',
            avatarEmoji: authAvatar ?? '👑',
            title: authTitle ?? 'Kelime Ustası',
            trophies: authTrophies,
            level: authLevel,
            email: authEmail,
            isEmailVerified: true,
          );
          _coins = prefs.getInt('user_coins') ?? 200;
          _freezeJokers = prefs.getInt('user_freeze_jokers') ?? 3;
          _hintJokers = prefs.getInt('user_hint_jokers') ?? 3;
          _wins = prefs.getInt('user_wins') ?? 0;
          _losses = prefs.getInt('user_losses') ?? 0;
          notifyListeners();
          return;
        }
      }

      // Misafir profili kontrolü
      String? guestId = prefs.getString('guest_player_id');
      String? guestName = prefs.getString('guest_player_name');
      String? guestTag = prefs.getString('guest_player_tag');
      String? guestAvatar = prefs.getString('guest_player_avatar');
      String? guestTitle = prefs.getString('guest_player_title');
      int? guestTrophies = prefs.getInt('guest_trophies');
      int? guestLevel = prefs.getInt('guest_level');
      int? coins = prefs.getInt('guest_coins');
      int? freezeJokers = prefs.getInt('guest_freeze_jokers');
      int? hintJokers = prefs.getInt('guest_hint_jokers');
      int? wins = prefs.getInt('guest_wins');
      int? losses = prefs.getInt('guest_losses');

      // Eğer daha önce kaydedilmemişse veya eski 'guest_user' / 'Misafir Oyuncu' şablonundaysa:
      if (guestId == null || guestId == 'guest_user' || guestName == null || guestName == 'Misafir Oyuncu') {
        final rand = Random();
        final randomNum = 100 + rand.nextInt(900);
        final prefix = _guestPrefixes[rand.nextInt(_guestPrefixes.length)];
        guestId = 'guest_${DateTime.now().millisecondsSinceEpoch}_$randomNum';
        guestName = '$prefix$randomNum';
        guestTag = '#KD-${1000 + rand.nextInt(9000)}';
        guestAvatar = _coolAvatars[rand.nextInt(_coolAvatars.length)];
        guestTitle = 'Çaylak Düellocu';
        guestTrophies = 1200;
        guestLevel = 1;
        coins = 200;
        freezeJokers = 3;
        hintJokers = 3;
        wins = 0;
        losses = 0;

        await prefs.setString('guest_player_id', guestId);
        await prefs.setString('guest_player_name', guestName);
        await prefs.setString('guest_player_tag', guestTag);
        await prefs.setString('guest_player_avatar', guestAvatar);
        await prefs.setString('guest_player_title', guestTitle);
        await prefs.setInt('guest_trophies', guestTrophies);
        await prefs.setInt('guest_level', guestLevel);
        await prefs.setInt('guest_coins', coins);
        await prefs.setInt('guest_freeze_jokers', freezeJokers);
        await prefs.setInt('guest_hint_jokers', hintJokers);
        await prefs.setInt('guest_wins', wins);
        await prefs.setInt('guest_losses', losses);
      }

      _player = Player(
        id: guestId,
        name: guestName,
        tag: guestTag ?? '#KD-1001',
        avatarEmoji: guestAvatar ?? '👑',
        title: guestTitle ?? 'Çaylak Düellocu',
        trophies: guestTrophies ?? 1200,
        level: guestLevel ?? 1,
        isBot: false,
      );
      _coins = coins ?? 200;
      _freezeJokers = freezeJokers ?? 3;
      _hintJokers = hintJokers ?? 3;
      _wins = wins ?? 0;
      _losses = losses ?? 0;
      _isLoggedIn = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Profile load hatası: $e');
    }
  }

  /// Profil bilgilerini güncelle ve kalıcı olarak kaydet
  Future<void> updateProfile({String? name, String? avatarEmoji, String? title}) async {
    _player = _player.copyWith(
      name: name ?? _player.name,
      avatarEmoji: avatarEmoji ?? _player.avatarEmoji,
      title: title ?? _player.title,
    );
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      if (_isLoggedIn) {
        await prefs.setString('auth_user_name', _player.name);
        await prefs.setString('auth_user_avatar', _player.avatarEmoji);
        await prefs.setString('auth_user_title', _player.title);
      } else {
        await prefs.setString('guest_player_name', _player.name);
        await prefs.setString('guest_player_avatar', _player.avatarEmoji);
        await prefs.setString('guest_player_title', _player.title);
      }
    } catch (_) {}
  }

  /// Çevrimiçi kullanıcı girişi
  Future<AuthResult> loginWithAuth({
    required String identifier,
    required String password,
  }) async {
    final result = await CrossGameAuthService.loginUser(
      identifier: identifier,
      password: password,
    );

    if (result.success && result.player != null) {
      _player = result.player!;
      _isLoggedIn = true;
      notifyListeners();

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('auth_is_logged_in', true);
        await prefs.setString('auth_user_id', _player.id);
        await prefs.setString('auth_user_name', _player.name);
        await prefs.setString('auth_user_tag', _player.tag);
        await prefs.setString('auth_user_avatar', _player.avatarEmoji);
        await prefs.setString('auth_user_title', _player.title);
        if (_player.email != null) {
          await prefs.setString('auth_user_email', _player.email!);
        }
        await prefs.setInt('auth_trophies', _player.trophies);
        await prefs.setInt('auth_level', _player.level);
      } catch (_) {}
    }
    return result;
  }

  /// Geriye dönük uyumluluk için login
  Future<bool> loginWithSupabase({
    required String username,
    required String password,
  }) async {
    final res = await loginWithAuth(identifier: username, password: password);
    return res.success;
  }

  /// Çıkış yap (Cihazın kendi misafir profiline geri döner)
  Future<void> logout() async {
    _isLoggedIn = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auth_is_logged_in', false);
      await prefs.remove('auth_user_id');
      await prefs.remove('auth_user_name');
      await prefs.remove('auth_user_tag');
      await prefs.remove('auth_user_avatar');
      await prefs.remove('auth_user_title');
      await prefs.remove('auth_user_email');
    } catch (_) {}

    await loadSavedProfile();
  }

  /// Yeni hesap kaydı
  Future<AuthResult> registerWithAuth({
    required String username,
    required String password,
    required String confirmPassword,
    String? email,
    bool isEmailVerified = false,
    String avatarEmoji = '👑',
  }) async {
    final result = await CrossGameAuthService.registerUser(
      username: username,
      password: password,
      confirmPassword: confirmPassword,
      email: email,
      isEmailVerified: isEmailVerified,
      avatarEmoji: avatarEmoji,
    );

    if (result.success && result.player != null) {
      _player = result.player!;
      _isLoggedIn = true;
      _wins = 0;
      _losses = 0;
      _coins = 200;
      notifyListeners();

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('auth_is_logged_in', true);
        await prefs.setString('auth_user_id', _player.id);
        await prefs.setString('auth_user_name', _player.name);
        await prefs.setString('auth_user_tag', _player.tag);
        await prefs.setString('auth_user_avatar', _player.avatarEmoji);
        await prefs.setString('auth_user_title', _player.title);
        if (_player.email != null) {
          await prefs.setString('auth_user_email', _player.email!);
        }
        await prefs.setInt('auth_trophies', _player.trophies);
        await prefs.setInt('auth_level', _player.level);
      } catch (_) {}
    }
    return result;
  }

  /// Geriye dönük uyumluluk için register
  Future<bool> registerWithSupabase({
    required String username,
    required String password,
    String avatarEmoji = '👑',
  }) async {
    final res = await registerWithAuth(
      username: username,
      password: password,
      confirmPassword: password,
      avatarEmoji: avatarEmoji,
    );
    return res.success;
  }

  /// Giriş yaptıktan sonra e-posta ekleme ve doğrulama
  Future<bool> attachEmail({required String email}) async {
    final success = await CrossGameAuthService.attachEmailToUser(
      userId: _player.id,
      email: email,
    );
    if (success) {
      _player = _player.copyWith(
        email: email,
        isEmailVerified: true,
      );
      notifyListeners();
    }
    return success;
  }

  bool useFreezeJoker() {
    if (_freezeJokers > 0) {
      _freezeJokers--;
      _saveJokersAndCoins();
      notifyListeners();
      return true;
    }
    return false;
  }

  bool useHintJoker() {
    if (_hintJokers > 0) {
      _hintJokers--;
      _saveJokersAndCoins();
      notifyListeners();
      return true;
    }
    return false;
  }

  bool spendCoins(int amount) {
    if (_coins >= amount) {
      _coins -= amount;
      _saveJokersAndCoins();
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> _saveJokersAndCoins() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefix = _isLoggedIn ? 'auth' : 'guest';
      await prefs.setInt('${prefix}_coins', _coins);
      await prefs.setInt('${prefix}_freeze_jokers', _freezeJokers);
      await prefs.setInt('${prefix}_hint_jokers', _hintJokers);
    } catch (_) {}
  }

  Future<void> recordMatchResult({required bool won}) async {
    if (won) {
      _wins++;
      _coins += 100;
      _player = _player.copyWith(
        trophies: _player.trophies + 30,
      );
    } else {
      _losses++;
      _coins += 25;
      _player = _player.copyWith(
        trophies: (_player.trophies - 15).clamp(0, 99999),
      );
    }

    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final prefix = _isLoggedIn ? 'auth' : 'guest';
      await prefs.setInt('${prefix}_trophies', _player.trophies);
      await prefs.setInt('${prefix}_wins', _wins);
      await prefs.setInt('${prefix}_losses', _losses);
      await prefs.setInt('${prefix}_coins', _coins);
    } catch (_) {}

    if (_isLoggedIn) {
      SupabaseService.syncPlayerProgress(
        userId: _player.id,
        trophies: _player.trophies,
        wins: _wins,
        losses: _losses,
      );
    }
  }
}
