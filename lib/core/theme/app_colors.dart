import 'package:flutter/material.dart';

class AppColors {
  // Asil ve tok koyu zemin renkleri
  static const Color background = Color(0xFF0D1117);
  static const Color surface = Color(0xFF161B22);
  static const Color surfaceLight = Color(0xFF21262D);
  static const Color cardBorder = Color(0xFF30363D);
  static const Color cardBorderActive = Color(0xFF484F58);

  // Tok ve şık vurgu renkleri (Şampanya altını & bronz tonları)
  static const Color primary = Color(0xFFD4AF37);
  static const Color primaryLight = Color(0xFFE5C07B);
  static const Color primaryDark = Color(0xFFA68020);

  // Oyuncu & Rakip Renkleri (Göz yormayan tok tonlar)
  static const Color playerColor = Color(0xFF38B2AC); // Mat Turkuaz / Çamur Yeşili
  static const Color opponentColor = Color(0xFFE57373); // Mat Kiremit Kırmızısı

  // Yardımcı / Durum Renkleri
  static const Color accentGreen = Color(0xFF48BB78);
  static const Color accentYellow = Color(0xFFF6AD55);
  static const Color accentRed = Color(0xFFE53E3E);
  static const Color accentBlue = Color(0xFF4A90E2);

  // Metin Renkleri
  static const Color textLight = Color(0xFFF0F6FC);
  static const Color textMuted = Color(0xFF8B949E);
  static const Color textDark = Color(0xFF161B22);

  // Sofistike Gradyanlar (Aşırı parlamayan tok gradyanlar)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFE5C07B), Color(0xFFB89347)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF161B22), Color(0xFF1C222B)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient defeatGradient = LinearGradient(
    colors: [Color(0xFF2D181A), Color(0xFF1F1214)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient victoryGradient = LinearGradient(
    colors: [Color(0xFF152A20), Color(0xFF101D17)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
