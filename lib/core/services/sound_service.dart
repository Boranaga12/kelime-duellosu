import 'package:flutter/services.dart';

class SoundService {
  static bool _isMuted = false;

  static bool get isMuted => _isMuted;

  static void toggleMute() {
    _isMuted = !_isMuted;
  }

  /// Doğru kelime tınısı
  static void playCorrect() {
    if (_isMuted) return;
    try {
      SystemSound.play(SystemSoundType.click);
      HapticFeedback.lightImpact();
    } catch (_) {}
  }

  /// Yanlış kelime uyarısı & titreşim
  static void playIncorrect() {
    if (_isMuted) return;
    try {
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Sıra oyuncuya geçtiğinde
  static void playTurnSwitch() {
    if (_isMuted) return;
    try {
      SystemSound.play(SystemSoundType.click);
      HapticFeedback.selectionClick();
    } catch (_) {}
  }

  /// Son saniyeler (Kritik geri sayım)
  static void playUrgentTick() {
    if (_isMuted) return;
    try {
      SystemSound.play(SystemSoundType.click);
      HapticFeedback.selectionClick();
    } catch (_) {}
  }

  /// Zafer kutlaması
  static void playVictory() {
    if (_isMuted) return;
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Yenilgi
  static void playDefeat() {
    if (_isMuted) return;
    try {
      HapticFeedback.vibrate();
    } catch (_) {}
  }
}
