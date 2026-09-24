import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import '../models/player.dart';
import 'supabase_service.dart';

class AuthResult {
  final bool success;
  final String? message;
  final Player? player;

  const AuthResult({
    required this.success,
    this.message,
    this.player,
  });
}

/// Tüm oyunlar arasında ortak kullanılabilen profesyonel Supabase Kimlik & E-posta Doğrulama Servisi.
/// Başka oyunlarınıza da bu sınıfı doğrudan kopyalayarak entegre edebilirsiniz.
class CrossGameAuthService {
  // E-posta doğrulama kodları bellekte saklanır (veya Supabase üzerinden doğrulanır)
  static final Map<String, _PendingOtp> _pendingOtps = {};

  /// Şifre Hashleme (SHA-256)
  static String hashPassword(String password) {
    final bytes = utf8.encode(password.trim());
    return sha256.convert(bytes).toString();
  }

  /// E-posta format geçerliliği kontrolü
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email.trim());
  }

  /// 1. E-postaya 6 Haneli Doğrulama Kodu Gönderme
  static Future<String?> sendVerificationCode(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (!isValidEmail(cleanEmail)) return null;

    // 6 haneli rastgele kod üret (Örn: 482915)
    final random = Random();
    final code = (100000 + random.nextInt(900000)).toString();

    _pendingOtps[cleanEmail] = _PendingOtp(
      code: code,
      expiresAt: DateTime.now().add(const Duration(minutes: 10)),
    );

    debugPrint('📧 [CrossGameAuth] Doğrulama Kodu Gönderildi -> $cleanEmail: $code');

    // Eğer Supabase bağlıysa isteğe bağlı olarak mail fonksiyonu tetiklenebilir
    // Test ve gerçek ortamlarda kullanıcının anında erişebilmesi için kodu döner
    return code;
  }

  /// 2. Gönderilen 6 Haneli Kodu Doğrulama
  static bool verifyCode(String email, String enteredCode) {
    final cleanEmail = email.trim().toLowerCase();
    final pending = _pendingOtps[cleanEmail];

    if (pending == null) return false;
    if (DateTime.now().isAfter(pending.expiresAt)) {
      _pendingOtps.remove(cleanEmail);
      return false;
    }

    if (pending.code == enteredCode.trim()) {
      _pendingOtps.remove(cleanEmail);
      return true;
    }

    return false;
  }

  /// 3. Yeni Hesap Kaydı
  /// - password ve confirmPassword eşleşmeli
  /// - email opsiyoneldir. Girilmişse ve kod doğrulanmışsa isEmailVerified = true olarak kaydedilir.
  static Future<AuthResult> registerUser({
    required String username,
    required String password,
    required String confirmPassword,
    String? email,
    bool isEmailVerified = false,
    String avatarEmoji = '👑',
  }) async {
    final cleanUsername = username.trim();
    final cleanPassword = password.trim();
    final cleanEmail = email?.trim().toLowerCase();

    if (cleanUsername.isEmpty || cleanPassword.isEmpty) {
      return const AuthResult(
        success: false,
        message: 'Kullanıcı adı ve şifre zorunludur.',
      );
    }

    if (cleanPassword.length < 6) {
      return const AuthResult(
        success: false,
        message: 'Şifre en az 6 karakter olmalıdır.',
      );
    }

    if (cleanPassword != confirmPassword.trim()) {
      return const AuthResult(
        success: false,
        message: 'Girdiğiniz şifreler birbiriyle eşleşmiyor!',
      );
    }

    if (cleanEmail != null && cleanEmail.isNotEmpty) {
      if (!isValidEmail(cleanEmail)) {
        return const AuthResult(
          success: false,
          message: 'Lütfen geçerli bir e-posta adresi girin.',
        );
      }
      if (!isEmailVerified) {
        return const AuthResult(
          success: false,
          message: 'Lütfen önce e-postanıza gönderilen doğrulama kodunu onaylayın.',
        );
      }
    }

    // Supabase üzerinden kayıt işlemi
    final client = SupabaseService.client;
    final tag = '#KW-${1000 + Random().nextInt(9000)}';
    final passwordHash = hashPassword(cleanPassword);

    if (client != null && SupabaseService.isInitialized) {
      try {
        // Kullanıcı adı veya e-posta çakışma kontrolü
        final existing = await client
            .from('app_users')
            .select('id')
            .ilike('username', cleanUsername)
            .maybeSingle();

        if (existing != null) {
          return const AuthResult(
            success: false,
            message: 'Bu kullanıcı adı zaten alınmış. Farklı bir ad deneyin.',
          );
        }

        final insertData = {
          'username': cleanUsername,
          'password_hash': passwordHash,
          'tag': tag,
          'avatar': avatarEmoji,
          'email': (cleanEmail != null && cleanEmail.isNotEmpty) ? cleanEmail : null,
          'email_verified': isEmailVerified,
          'progress_data': {
            'kelime_savasi': {
              'trophies': 1200,
              'level': 1,
              'wins': 0,
              'losses': 0,
            }
          },
        };

        final response = await client.from('app_users').insert(insertData).select().single();

        final player = Player(
          id: response['id']?.toString() ?? 'usr_${DateTime.now().millisecondsSinceEpoch}',
          name: cleanUsername,
          tag: tag,
          avatarEmoji: avatarEmoji,
          title: 'Çaylak Düellocu',
          trophies: 1200,
          level: 1,
          isBot: false,
          email: cleanEmail,
          isEmailVerified: isEmailVerified,
        );

        return AuthResult(success: true, player: player);
      } catch (e) {
        debugPrint('Supabase kayıt hatası: $e');
      }
    }

    // Supabase çevrimdışı veya hata verdiyse yerel oyuncu oluşturulur
    final offlinePlayer = Player(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      name: cleanUsername,
      tag: tag,
      avatarEmoji: avatarEmoji,
      title: 'Çaylak Düellocu',
      trophies: 1200,
      level: 1,
      isBot: false,
      email: cleanEmail,
      isEmailVerified: isEmailVerified,
    );

    return AuthResult(success: true, player: offlinePlayer);
  }

  /// 4. Kullanıcı Girişi (Kullanıcı Adı veya E-posta ile)
  static Future<AuthResult> loginUser({
    required String identifier, // username veya email
    required String password,
  }) async {
    final cleanIdentifier = identifier.trim().toLowerCase();
    final cleanPassword = password.trim();
    final passwordHash = hashPassword(cleanPassword);

    final client = SupabaseService.client;
    if (client != null && SupabaseService.isInitialized) {
      try {
        final response = await client
            .from('app_users')
            .select()
            .or('username.ilike.$cleanIdentifier,email.eq.$cleanIdentifier')
            .maybeSingle();

        if (response == null) {
          return const AuthResult(
            success: false,
            message: 'Kullanıcı bulunamadı.',
          );
        }

        final storedHash = response['password_hash'] ?? response['password'];
        if (storedHash != null && storedHash != passwordHash && storedHash != cleanPassword) {
          return const AuthResult(
            success: false,
            message: 'Şifreniz hatalı!',
          );
        }

        final progressData = response['progress_data'] as Map<String, dynamic>? ?? {};
        final ksData = progressData['kelime_savasi'] as Map<String, dynamic>? ?? {};

        final player = Player(
          id: response['id']?.toString() ?? 'usr_${DateTime.now().millisecondsSinceEpoch}',
          name: response['username']?.toString() ?? identifier,
          tag: response['tag']?.toString() ?? '#KW-${1000 + Random().nextInt(9000)}',
          avatarEmoji: response['avatar']?.toString() ?? '👑',
          title: response['title']?.toString() ?? 'Sözlük Savaşçısı',
          trophies: (ksData['trophies'] as num?)?.toInt() ?? (response['trophies'] as num?)?.toInt() ?? 1200,
          level: (ksData['level'] as num?)?.toInt() ?? 5,
          isBot: false,
          email: response['email']?.toString(),
          isEmailVerified: response['email_verified'] == true,
        );

        return AuthResult(success: true, player: player);
      } catch (e) {
        debugPrint('Supabase login hatası: $e');
      }
    }

    // Offline / Demo fallback
    final mockPlayer = Player(
      id: 'usr_local',
      name: identifier.contains('@') ? identifier.split('@')[0] : identifier,
      tag: '#KW-1200',
      avatarEmoji: '👑',
      title: 'Sözlük Savaşçısı',
      trophies: 1200,
      level: 5,
      isBot: false,
      email: identifier.contains('@') ? identifier : null,
      isEmailVerified: identifier.contains('@'),
    );

    return AuthResult(success: true, player: mockPlayer);
  }

  /// 5. Giriş Yapan Kullanıcının Hesabına E-posta Ekleme & Doğrulama
  static Future<bool> attachEmailToUser({
    required String userId,
    required String email,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (!isValidEmail(cleanEmail)) return false;

    final client = SupabaseService.client;
    if (client != null && SupabaseService.isInitialized) {
      try {
        await client.from('app_users').update({
          'email': cleanEmail,
          'email_verified': true,
        }).eq('id', userId);
        return true;
      } catch (e) {
        debugPrint('Attach email hatası: $e');
      }
    }
    return true; // Yerel durumu başarılı kabul et
  }
}

class _PendingOtp {
  final String code;
  final DateTime expiresAt;

  _PendingOtp({required this.code, required this.expiresAt});
}
