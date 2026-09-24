import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/cross_game_auth_service.dart';
import '../controllers/friends_controller.dart';
import '../controllers/profile_controller.dart';

class AuthDialog extends StatefulWidget {
  const AuthDialog({super.key});

  @override
  State<AuthDialog> createState() => _AuthDialogState();
}

class _AuthDialogState extends State<AuthDialog> {
  bool _isLogin = true;
  bool _isOtpVerificationStage = false;

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  String? _generatedOtpForTest;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final identifier = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (identifier.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Lütfen kullanıcı adı / e-posta ve şifrenizi girin.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final profile = context.read<ProfileController>();
    final friends = context.read<FriendsController>();

    final result = await profile.loginWithAuth(identifier: identifier, password: password);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      friends.syncFriendsFromSupabase(profile.player.id);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF10B981),
          content: Text(
            'Hoş geldin, ${profile.player.name}! 👑',
            style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ),
      );
    } else {
      setState(() {
        _errorMessage = result.message ?? 'Giriş yapılamadı. Bilgilerinizi kontrol edin.';
      });
    }
  }

  Future<void> _handleRegisterStart() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    final email = _emailController.text.trim();

    if (username.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      setState(() => _errorMessage = 'Lütfen kullanıcı adı, şifre ve şifre tekrarını doldurun.');
      return;
    }

    if (password.length < 6) {
      setState(() => _errorMessage = 'Şifre en az 6 karakter olmalıdır.');
      return;
    }

    if (password != confirmPassword) {
      setState(() => _errorMessage = 'Girdiğiniz şifreler eşleşmiyor!');
      return;
    }

    // E-posta girilmişse doğrulama kodu sürecine geç
    if (email.isNotEmpty) {
      if (!CrossGameAuthService.isValidEmail(email)) {
        setState(() => _errorMessage = 'Lütfen geçerli bir e-posta formatı girin.');
        return;
      }

      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final code = await CrossGameAuthService.sendVerificationCode(email);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (code != null) {
          _isOtpVerificationStage = true;
          _generatedOtpForTest = code;
        } else {
          _errorMessage = 'Doğrulama kodu gönderilemedi. Lütfen tekrar deneyin.';
        }
      });
      return;
    }

    // E-posta girilmediyse doğrudan kaydı tamamla
    await _completeRegistration(email: null, isEmailVerified: false);
  }

  Future<void> _handleVerifyOtpAndRegister() async {
    final email = _emailController.text.trim();
    final enteredOtp = _otpController.text.trim();

    if (enteredOtp.length != 6) {
      setState(() => _errorMessage = 'Lütfen 6 haneli doğrulama kodunu eksiksiz girin.');
      return;
    }

    final isValid = CrossGameAuthService.verifyCode(email, enteredOtp);
    if (!isValid) {
      setState(() => _errorMessage = 'Geçersiz veya süresi dolmuş kod!');
      return;
    }

    await _completeRegistration(email: email, isEmailVerified: true);
  }

  Future<void> _completeRegistration({required String? email, required bool isEmailVerified}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final profile = context.read<ProfileController>();
    final friends = context.read<FriendsController>();

    final result = await profile.registerWithAuth(
      username: _usernameController.text.trim(),
      password: _passwordController.text.trim(),
      confirmPassword: _confirmPasswordController.text.trim(),
      email: email,
      isEmailVerified: isEmailVerified,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      friends.syncFriendsFromSupabase(profile.player.id);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF10B981),
          content: Text(
            'Hesabınız başarıyla oluşturuldu! Hoş geldin, ${profile.player.name}! 🚀',
            style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ),
      );
    } else {
      setState(() {
        _errorMessage = result.message ?? 'Kayıt işlemi gerçekleştirilemedi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
              // Üst Başlık ve Kapatma
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isOtpVerificationStage
                        ? 'E-posta Doğrulama'
                        : _isLogin
                            ? 'Giriş Yap'
                            : 'Yeni Hesap Aç',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textLight,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 22),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _isOtpVerificationStage
                    ? 'E-postanıza gönderilen 6 haneli kodu girerek hesabınızı güvenceye alın.'
                    : 'Tüm oyunlarınızda tek bir hesapla ilerlemenizi ve arkadaşlarınızı ortak kullanın.',
                style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.3),
              ),
              const SizedBox(height: 16),

              // Hata Kutusu
              if (_errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),

              // 1. AŞAMA: E-POSTA KOD DOĞRULAMA (OTP)
              if (_isOtpVerificationStage) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kod Şuraya Gönderildi: ${_emailController.text}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF10B981)),
                      ),
                      if (_generatedOtpForTest != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Test Doğrulama Kodu: $_generatedOtpForTest',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFFF59E0B)),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // OTP Giriş Alanı
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 6,
                      color: AppColors.textLight,
                    ),
                    decoration: const InputDecoration(
                      counterText: '',
                      hintText: '000000',
                      hintStyle: TextStyle(color: AppColors.textMuted, letterSpacing: 6),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 3D Kodu Onayla ve Hesabı Aç Butonu
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isLoading ? null : _handleVerifyOtpAndRegister,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(color: Color(0xFF047857), offset: Offset(0, 4)),
                        ],
                      ),
                      child: Center(
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text(
                                'Kodu Onayla ve Hesabı Aç',
                                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: Colors.white),
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _isOtpVerificationStage = false;
                        _errorMessage = null;
                      });
                    },
                    child: const Text('Geri Dön ve Bilgileri Düzenle', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ),
                ),
              ]
              // 2. AŞAMA: GİRİŞ FORMU
              else if (_isLogin) ...[
                // Kullanıcı Adı veya E-posta
                _buildInputLabel('KULLANICI ADI VEYA E-POSTA'),
                _buildTextField(
                  controller: _usernameController,
                  hint: 'Kullanıcı adı veya e-posta',
                  icon: Icons.person_outline_rounded,
                ),
                const SizedBox(height: 14),

                // Şifre
                _buildInputLabel('ŞİFRE'),
                _buildTextField(
                  controller: _passwordController,
                  hint: 'Şifrenizi girin',
                  icon: Icons.lock_outline_rounded,
                  obscureText: true,
                ),
                const SizedBox(height: 22),

                // 3D Giriş Yap Butonu
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isLoading ? null : _handleLogin,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(color: Color(0xFF047857), offset: Offset(0, 4)),
                        ],
                      ),
                      child: Center(
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text(
                                'Giriş Yap',
                                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: Colors.white),
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Mod Değiştir
                Center(
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _isLogin = false;
                        _errorMessage = null;
                      });
                    },
                    child: const Text(
                      'Hesabın yok mu? Yeni Hesap Aç',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFFF59E0B), fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ]
              // 3. AŞAMA: KAYIT FORMU (Şifre 2 defa + Opsiyonel E-posta)
              else ...[
                // Kullanıcı Adı
                _buildInputLabel('KULLANICI ADI (ZORUNLU)'),
                _buildTextField(
                  controller: _usernameController,
                  hint: 'Benzersiz bir kullanıcı adı',
                  icon: Icons.badge_outlined,
                ),
                const SizedBox(height: 12),

                // Şifre
                _buildInputLabel('ŞİFRE (EN AZ 6 KARAKTER)'),
                _buildTextField(
                  controller: _passwordController,
                  hint: 'Şifrenizi oluşturun',
                  icon: Icons.lock_outline_rounded,
                  obscureText: true,
                ),
                const SizedBox(height: 12),

                // Şifre Tekrarı (ZORUNLU 2 DEFA)
                _buildInputLabel('ŞİFRE TEKRARI (ZORUNLU)'),
                _buildTextField(
                  controller: _confirmPasswordController,
                  hint: 'Şifrenizi tekrar girin',
                  icon: Icons.check_circle_outline_rounded,
                  obscureText: true,
                ),
                const SizedBox(height: 12),

                // E-posta (OPSİYONEL)
                _buildInputLabel('E-POSTA (OPSİYONEL - DOĞRULAMA KODU GÖNDERİLİR)'),
                _buildTextField(
                  controller: _emailController,
                  hint: 'ornek@eposta.com (İsteğe bağlı)',
                  icon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 22),

                // 3D Kayıt Ol Butonu
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isLoading ? null : _handleRegisterStart,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(color: Color(0xFFB45309), offset: Offset(0, 4)),
                        ],
                      ),
                      child: Center(
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text(
                                'Hesap Oluştur',
                                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: Colors.white),
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Giriş Moduna Geç
                Center(
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _isLogin = true;
                        _errorMessage = null;
                      });
                    },
                    child: const Text(
                      'Zaten bir hesabın var mı? Giriş Yap',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF10B981), fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: AppColors.textMuted,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(color: AppColors.textLight, fontWeight: FontWeight.w700, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w500),
          prefixIcon: Icon(icon, color: AppColors.textMuted, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        ),
      ),
    );
  }
}
