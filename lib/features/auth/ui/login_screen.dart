import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_envelope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/update/app_version_provider.dart';
import '../../../gen/l10n/app_localizations.dart';
import '../../../shared/widgets/clay_ball.dart';
import '../../../shared/widgets/coin_3d.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../providers/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _remember = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _doLogin() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      _showSnack('กรุณากรอกอีเมลและรหัสผ่าน');
      return;
    }

    final notifier = ref.read(authControllerProvider.notifier);
    try {
      final result = await notifier.login(email, password);
      if (!mounted) return;

      if (result.requiresTwoFactor && result.challengeToken != null) {
        // ไป 2FA screen
        context.push('/auth/2fa', extra: result.challengeToken);
      } else if (result.admin != null) {
        // Login สำเร็จ → router จะ redirect ไป dashboard อัตโนมัติ
      }
    } on ApiException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack('ไม่สามารถเชื่อมต่อได้: $e');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final state = ref.watch(authControllerProvider);

    return Scaffold(
      body: Stack(
        children: [
          // Cosmic gradient background
          const DecoratedBox(
            decoration: BoxDecoration(gradient: AppColors.cosmicGradient),
            child: SizedBox.expand(),
          ),
          // Floating orbs
          Positioned(
            top: -40,
            right: -50,
            child: _orb(220, [const Color(0xFFFBBF24), const Color(0xFFEF4444).withValues(alpha: 0)], 0.55),
          ),
          Positioned(
            bottom: 180,
            left: -80,
            child: _orb(260, [const Color(0xFF22D3EE), const Color(0xFF6366F1).withValues(alpha: 0)], 0.5),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),

                  // 3D shield with TP logo
                  Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.10),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                          ),
                        ),
                        ClayBall(
                          size: 96,
                          hue: 45,
                          saturation: 0.95,
                          lightness: 0.62,
                          child: const Text(
                            'TP',
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF7C2D12),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: -8,
                          left: -6,
                          child: const Coin3D(size: 42),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Title
                  const Text(
                    'THAIPROMPT',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 4,
                      color: Color(0xCCFFFFFF),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.loginTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.loginSubtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: Color(0xD9FFFFFF)),
                  ),

                  const SizedBox(height: 28),

                  // Glass form
                  GlassCard(
                    padding: const EdgeInsets.all(22),
                    fillOpacity: 0.12,
                    borderOpacity: 0.22,
                    borderRadius: 28,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.emailLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xE6FFFFFF),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.mail_outline, color: Colors.white),
                            hintText: 'admin@thaiprompt.com',
                            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                            fillColor: Colors.white.withValues(alpha: 0.14),
                          ),
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 14),

                        Text(
                          l10n.passwordLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xE6FFFFFF),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _passwordCtrl,
                          obscureText: _obscure,
                          autofillHints: const [AutofillHints.password],
                          onSubmitted: (_) => _doLogin(),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.lock_outline, color: Colors.white),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                color: Colors.white,
                              ),
                            ),
                            fillColor: Colors.white.withValues(alpha: 0.14),
                          ),
                          style: const TextStyle(color: Colors.white, letterSpacing: 4),
                        ),

                        const SizedBox(height: 14),

                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => setState(() => _remember = !_remember),
                              child: Row(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: _remember ? AppColors.goldStart : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                                    ),
                                    child: _remember
                                        ? const Icon(Icons.check, size: 14, color: Color(0xFF7C2D12))
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.rememberMe,
                                    style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            Text(
                              l10n.forgotPassword,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),

                        GradientButton(
                          onPressed: state.loading ? null : _doLogin,
                          loading: state.loading,
                          icon: Icons.shield_outlined,
                          label: l10n.loginButton,
                        ),

                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.25))),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                l10n.loginOrDivider,
                                style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 11),
                              ),
                            ),
                            Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.25))),
                          ],
                        ),

                        const SizedBox(height: 14),

                        Row(
                          children: [
                            Expanded(
                              child: _altButton(
                                icon: Icons.qr_code_2,
                                label: l10n.loginWithQr,
                                onTap: () => context.push('/auth/qr'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // เวอร์ชันจริงจาก pubspec.yaml (ผ่าน package_info_plus)
                  Consumer(builder: (_, ref, __) {
                    final versionAsync = ref.watch(appVersionStringProvider);
                    return Text(
                      l10n.appVersion(versionAsync.maybeWhen(
                        data: (v) => v,
                        orElse: () => '...',
                      )),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 11),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _orb(double size, List<Color> colors, double opacity) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.4, -0.4),
            colors: colors,
            stops: const [0.0, 0.75],
          ),
        ),
      ),
    );
  }

  Widget _altButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
