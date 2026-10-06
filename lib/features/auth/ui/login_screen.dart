import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../shared/ui/tp.dart';
import '../providers/auth_controller.dart';
import 'auth_backdrop.dart';

/// หน้าเข้าสู่ระบบ — อีเมล/รหัสผ่าน หรือจับคู่ด้วย QR จากหน้าเว็บแอดมิน
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  String? _error;
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((p) {
      if (mounted) setState(() => _version = 'v${p.version} (${p.buildNumber})');
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _doLogin() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'กรอกอีเมลผู้ดูแลให้ถูกต้อง');
      return;
    }
    if (password.isEmpty) {
      setState(() => _error = 'กรอกรหัสผ่าน');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    try {
      final result = await ref.read(authControllerProvider.notifier).login(email, password);
      if (!mounted) return;
      if (result.requiresTwoFactor && result.challengeToken != null) {
        context.push('/auth/2fa', extra: result.challengeToken);
      }
      // สำเร็จ → router พาไปหน้าภาพรวมเอง
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = tpErrorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final ringY = AuthBackdrop.ringY(context);
    // อ่านขอบบนนอก SafeArea (ข้างในจะเป็น 0)
    final topPad = MediaQuery.paddingOf(context).top;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final sessionMsg = _error ?? auth.error;

    return Scaffold(
      backgroundColor: const Color(0xFF05070C),
      resizeToAvoidBottomInset: true,
      body: AuthBackdrop(
        child: SafeArea(
          child: LayoutBuilder(builder: (context, c) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: c.maxHeight),
                child: Column(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    height: keyboard ? 24 : (ringY - topPad - 38).clamp(0, 9999).toDouble(),
                  ),
                  AnimatedScale(
                    duration: const Duration(milliseconds: 220),
                    scale: keyboard ? 0.7 : 1,
                    child: Image.asset('assets/images/brand/tp-mark.webp', width: 76, cacheWidth: 228),
                  ),
                  SizedBox(height: keyboard ? 12 : (ringY * 0.42).clamp(40, 110)),
                  TpFoilText('ไทยพร้อม แอดมิน', style: TpType.title(27, Colors.white)),
                  const SizedBox(height: 2),
                  Text('ศูนย์ควบคุมหลังบ้าน · main.thaiprompt.online',
                      style: TpType.body(13, const Color(0x9EFFFFFF)), textAlign: TextAlign.center),
                  const SizedBox(height: 26),
                  AutofillGroup(
                    child: Column(children: [
                      AuthField(
                        controller: _email,
                        hint: 'อีเมลผู้ดูแล',
                        icon: PhosphorIconsRegular.envelopeSimple,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email, AutofillHints.username],
                        enabled: !auth.loading,
                      ),
                      const SizedBox(height: 12),
                      AuthField(
                        controller: _password,
                        hint: 'รหัสผ่าน',
                        icon: PhosphorIconsRegular.lockSimple,
                        obscure: _obscure,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _doLogin(),
                        autofillHints: const [AutofillHints.password],
                        enabled: !auth.loading,
                        suffix: IconButton(
                          tooltip: _obscure ? 'แสดงรหัสผ่าน' : 'ซ่อนรหัสผ่าน',
                          icon: Icon(_obscure ? PhosphorIconsRegular.eye : PhosphorIconsRegular.eyeSlash,
                              color: const Color(0x99FFFFFF), size: 20),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ]),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    child: sessionMsg == null
                        ? const SizedBox(height: 18)
                        : Padding(
                            padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                            child: Row(children: [
                              const Icon(PhosphorIconsFill.warningCircle, color: Color(0xFFFF8A7A), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(sessionMsg,
                                    style: TpType.body(13, const Color(0xFFFF8A7A), w: FontWeight.w500)),
                              ),
                            ]),
                          ),
                  ),
                  TpButton(
                    'เข้าสู่ระบบ',
                    icon: PhosphorIconsBold.shieldCheck,
                    loading: auth.loading,
                    onPressed: _doLogin,
                  ),
                  const SizedBox(height: 18),
                  Row(children: [
                    const Expanded(child: Divider(color: Color(0x1FFFFFFF))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('หรือ', style: TpType.body(12.5, const Color(0x73FFFFFF))),
                    ),
                    const Expanded(child: Divider(color: Color(0x1FFFFFFF))),
                  ]),
                  const SizedBox(height: 14),
                  _QrButton(onTap: auth.loading ? null : () => context.push('/auth/qr')),
                  const SizedBox(height: 22),
                  Text(
                    'สร้าง QR ได้ที่ main.thaiprompt.online/admin/mobile-pair\n$_version',
                    textAlign: TextAlign.center,
                    style: TpType.body(11.5, const Color(0x61FFFFFF)),
                  ),
                  const SizedBox(height: 16),
                ]),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _QrButton extends StatelessWidget {
  const _QrButton({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0x14F0C96A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0x66F0C96A)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(PhosphorIconsRegular.qrCode, color: Color(0xFFF0C96A), size: 21),
            const SizedBox(width: 10),
            Text('สแกน QR จับคู่เครื่องนี้', style: TpType.h(15, const Color(0xFFF0C96A))),
          ]),
        ),
      ),
    );
  }
}
