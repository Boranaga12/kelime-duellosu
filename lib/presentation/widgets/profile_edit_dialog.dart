import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/cross_game_auth_service.dart';
import '../controllers/friends_controller.dart';
import '../controllers/profile_controller.dart';
import 'auth_dialog.dart';

class ProfileEditDialog extends StatefulWidget {
  const ProfileEditDialog({super.key});

  @override
  State<ProfileEditDialog> createState() => _ProfileEditDialogState();
}

class _ProfileEditDialogState extends State<ProfileEditDialog> {
  late TextEditingController _nameController;
  late TextEditingController _titleController;
  late TextEditingController _emailController;
  late TextEditingController _otpController;
  late String _selectedEmoji;

  bool _isOtpSent = false;
  String? _generatedOtpForTest;
  String? _emailError;
  bool _isEmailProcessing = false;
  bool _isChangingEmail = false;

  final List<String> _availableAvatars = [
    '👑', '⚔️', '🦊', '🦅', '🦁', '🐺', '⚡', '🎯', '🔥', '🛡️', '💎', '🚀',
  ];

  final List<String> _availableTitles = [
    'Çaylak Düellocu',
    'Kelime Ustası',
    'Sözlük Savaşçısı',
    'Hızlı Parmaklar',
    'Taktisyen',
    'Kelime Avcısı',
    'Efsane Düellocu',
  ];

  @override
  void initState() {
    super.initState();
    final profile = context.read<ProfileController>();
    _nameController = TextEditingController(text: profile.player.name);
    _titleController = TextEditingController(text: profile.player.title);
    _emailController = TextEditingController(text: profile.player.email ?? '');
    _otpController = TextEditingController();
    _selectedEmoji = profile.player.avatarEmoji;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _titleController.dispose();
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _saveProfile() {
    final name = _nameController.text.trim();
    final title = _titleController.text.trim();
    if (name.isEmpty) return;

    context.read<ProfileController>().updateProfile(
          name: name,
          avatarEmoji: _selectedEmoji,
          title: title.isEmpty ? 'Çaylak Düellocu' : title,
        );

    Navigator.of(context).pop();
  }

  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();
    if (!CrossGameAuthService.isValidEmail(email)) {
      setState(() => _emailError = 'Lütfen geçerli bir e-posta adresi girin.');
      return;
    }

    setState(() {
      _isEmailProcessing = true;
      _emailError = null;
    });

    final code = await CrossGameAuthService.sendVerificationCode(email);

    if (!mounted) return;
    setState(() {
      _isEmailProcessing = false;
      if (code != null) {
        _isOtpSent = true;
        _generatedOtpForTest = code;
      } else {
        _emailError = 'Doğrulama kodu gönderilemedi. Lütfen tekrar deneyin.';
      }
    });
  }

  Future<void> _verifyOtp() async {
    final email = _emailController.text.trim();
    final code = _otpController.text.trim();

    if (code.length != 6) {
      setState(() => _emailError = 'Lütfen 6 haneli kodu eksiksiz girin.');
      return;
    }

    if (!CrossGameAuthService.verifyCode(email, code)) {
      setState(() => _emailError = 'Geçersiz veya süresi dolmuş kod!');
      return;
    }

    setState(() {
      _isEmailProcessing = true;
      _emailError = null;
    });

    final success = await context.read<ProfileController>().attachEmail(email: email);

    if (!mounted) return;
    setState(() {
      _isEmailProcessing = false;
      if (success) {
        _isOtpSent = false;
        _isChangingEmail = false;
        _generatedOtpForTest = null;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF10B981),
            content: Text('E-posta başarıyla doğrulandı ve hesabınıza bağlandı! ✓', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        );
      } else {
        _emailError = 'E-posta kaydedilirken bir hata oluştu.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileController>();
    final player = profile.player;

    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık ve ID Gösterimi
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Profili Düzenle',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textLight,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Oyuncu Kodu: ${player.tag}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 22),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Giriş Durumu ve Butonu (Profilin İçinde)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: profile.isLoggedIn
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.cloud_done_rounded, color: Color(0xFF10B981), size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Çevrimiçi Hesap Bağlı',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: () {
                              profile.logout();
                              context.read<FriendsController>().clear();
                            },
                            child: const Text(
                              'Çıkış Yap',
                              style: TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Misafir Modundasınız',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textLight,
                                ),
                              ),
                              Text(
                                'İlerlemeyi kaydet & arkadaş ekle',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              Navigator.of(context).pop();
                              showDialog(
                                context: context,
                                builder: (_) => const AuthDialog(),
                              );
                            },
                            icon: const Icon(Icons.login_rounded, size: 16, color: Colors.white),
                            label: const Text(
                              'Giriş Yap',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 18),

              // Avatar Seçimi
              const Text(
                'AVATAR SEÇ',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _availableAvatars.map((emoji) {
                  final isSelected = _selectedEmoji == emoji;
                  return InkWell(
                    onTap: () => setState(() => _selectedEmoji = emoji),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF2D3B55) : const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: isSelected ? const Color(0xFFF59E0B) : Colors.transparent,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(emoji, style: const TextStyle(fontSize: 22)),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 18),

              // İsim Alanı
              const Text(
                'OYUNCU ADI',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  controller: _nameController,
                  style: const TextStyle(color: AppColors.textLight, fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(
                    hintText: 'Adınızı girin',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Unvan Alanı
              const Text(
                'UNVAN SEÇ',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _availableTitles.contains(_titleController.text)
                        ? _titleController.text
                        : _availableTitles.first,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: AppColors.textLight, fontWeight: FontWeight.w700),
                    items: _availableTitles.map((t) {
                      return DropdownMenuItem(value: t, child: Text(t));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _titleController.text = val);
                      }
                    },
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ==========================================
              // E-POSTA BÖLÜMÜ (MİSAFİR MODUNDA EKLENEMEZ)
              // ==========================================
              const Text(
                'E-POSTA DOĞRULAMA & BAĞLAMA',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 8),

              // 1. Durum: Misafir Modunda E-posta Eklenemez
              if (!profile.isLoggedIn) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline_rounded, color: Color(0xFFF59E0B), size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Misafir Modunda E-posta Eklenemez',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFF59E0B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Hesabınıza e-posta tanımlamak ve tüm cihazlarda kullanmak için lütfen önce giriş yapın veya kayıt olun.',
                              style: TextStyle(fontSize: 10.5, color: AppColors.textMuted, height: 1.3),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () {
                                Navigator.of(context).pop();
                                showDialog(context: context, builder: (_) => const AuthDialog());
                              },
                              child: const Text(
                                'Giriş Yap veya Kayıt Ol →',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ]
              // 2. Durum: Kullanıcı Giriş Yapmış & Zaten Onaylı E-postası Var
              else if (player.isEmailVerified && (player.email != null && player.email!.isNotEmpty) && !_isChangingEmail) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              player.email!,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textLight),
                            ),
                            const Text(
                              'Doğrulanmış E-posta ✓',
                              style: TextStyle(fontSize: 10, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _isChangingEmail = true),
                        child: const Text('Değiştir', style: TextStyle(fontSize: 11.5, color: Color(0xFFF59E0B), fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              ]
              // 3. Durum: Kullanıcı Giriş Yapmış ve E-posta Ekliyor / Değiştiriyor (OTP Doğrulama)
              else ...[
                if (_emailError != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _emailError!,
                      style: const TextStyle(fontSize: 11, color: Color(0xFFEF4444), fontWeight: FontWeight.w600),
                    ),
                  ),

                if (!_isOtpSent) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: AppColors.textLight, fontWeight: FontWeight.w700, fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'ornek@eposta.com',
                        hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                        prefixIcon: Icon(Icons.email_outlined, color: AppColors.textMuted, size: 18),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isEmailProcessing ? null : _sendOtp,
                    child: _isEmailProcessing
                        ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Doğrulama Kodu Gönder', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kod şuraya gönderildi: ${_emailController.text}',
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF10B981), fontWeight: FontWeight.w700),
                        ),
                        if (_generatedOtpForTest != null)
                          Text(
                            'Test Kodu: $_generatedOtpForTest',
                            style: const TextStyle(fontSize: 11, color: Color(0xFFF59E0B), fontWeight: FontWeight.w800),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      style: const TextStyle(color: AppColors.textLight, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 4),
                      decoration: const InputDecoration(
                        counterText: '',
                        hintText: '000000',
                        hintStyle: TextStyle(color: AppColors.textMuted, letterSpacing: 4),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _isEmailProcessing ? null : _verifyOtp,
                          child: const Text('Kodu Onayla & Kaydet', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => setState(() => _isOtpSent = false),
                        child: const Text('Geri', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                      ),
                    ],
                  ),
                ],
              ],

              const SizedBox(height: 24),

              // 3D Kaydet Butonu
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _saveProfile,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(color: Color(0xFF047857), offset: Offset(0, 4)),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'Kaydet ve Güncelle',
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
