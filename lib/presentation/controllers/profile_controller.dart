import 'package:flutter/foundation.dart';
import '../../data/models/player.dart';
import '../../data/services/cross_game_auth_service.dart';
import '../../data/services/supabase_service.dart';

class ProfileController extends ChangeNotifier {
  Player _player = const Player(
    id: 'guest_user',
    name: 'Misafir Oyuncu',
    tag: '#KW-0000',
    avatarEmoji: '👑',
    title: 'Çaylak Düellocu',
    trophies: 0,
    level: 1,
    isBot: false,
    email: null,
    isEmailVerified: false,
  );

  int _coins = 200;
  int _freezeJokers = 3;
  int _hintJokers = 3;
  int _wins = 0;
  int _losses = 0;
  bool _isLoggedIn = false;

  Player get player => _player;
  int get coins => _coins;
  int get freezeJokers => _freezeJokers;
  int get hintJokers => _hintJokers;
  int get wins => _wins;
  int get losses => _losses;
  bool get isLoggedIn => _isLoggedIn;

  /// Supabase üzerinden kullanıcı adı veya e-posta ile giriş
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

  /// Çıkış yap (Misafir moduna geri döner)
  void logout() {
    _player = const Player(
      id: 'guest_user',
      name: 'Misafir Oyuncu',
      tag: '#KW-0000',
      avatarEmoji: '👑',
      title: 'Çaylak Düellocu',
      trophies: 0,
      level: 1,
      isBot: false,
      email: null,
      isEmailVerified: false,
    );
    _wins = 0;
    _losses = 0;
    _coins = 200;
    _isLoggedIn = false;
    notifyListeners();
  }

  /// Yeni hesap kaydı (Şifre doğrulamalı ve opsiyonel e-postalı)
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

  void updateProfile({String? name, String? avatarEmoji, String? title}) {
    _player = _player.copyWith(
      name: name ?? _player.name,
      avatarEmoji: avatarEmoji ?? _player.avatarEmoji,
      title: title ?? _player.title,
    );
    notifyListeners();
  }

  bool useFreezeJoker() {
    if (_freezeJokers > 0) {
      _freezeJokers--;
      notifyListeners();
      return true;
    }
    return false;
  }

  bool useHintJoker() {
    if (_hintJokers > 0) {
      _hintJokers--;
      notifyListeners();
      return true;
    }
    return false;
  }

  bool spendCoins(int amount) {
    if (_coins >= amount) {
      _coins -= amount;
      notifyListeners();
      return true;
    }
    return false;
  }

  void recordMatchResult({required bool won}) {
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

    if (_isLoggedIn) {
      SupabaseService.syncPlayerProgress(
        userId: _player.id,
        trophies: _player.trophies,
        wins: _wins,
        losses: _losses,
      );
    }

    notifyListeners();
  }
}
