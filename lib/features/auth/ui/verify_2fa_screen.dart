import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../shared/ui/tp.dart';
import '../providers/auth_controller.dart';
import 'auth_backdrop.dart';

/// ยืนยันตัวตนสองชั้น (รหัส 6 หลักจากแอป Authenticator)
class Verify2FAScreen extends ConsumerStatefulWidget {
  const Verify2FAScreen({super.key, required this.challengeToken});
  final String challengeToken;

  @override
  ConsumerState<Verify2FAScreen> createState() => _Verify2FAScreenState();
}

class _Verify2FAScreenState extends ConsumerState<Verify2FAScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _ctrl.text.trim();
    if (code.length < 6) {
      setState(() => _error = 'กรอกรหัสให้ครบ 6 หลัก');
      return;
    }
    setState(() => _error = null);
    try {
      await ref.read(authControllerProvider.notifier).verifyTwoFactor(widget.challengeToken, code);
      // สำเร็จ → router พาไปหน้าภาพรวม
    } catch (e) {
      if (!mounted) return;
      _ctrl.clear();
      HapticFeedback.vibrate();
      setState(() => _error = tpErrorText(e));
      _focus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authControllerProvider).loading;
    return Scaffold(
      backgroundColor: const Color(0xFF05070C),
      body: AuthBackdrop(
        dim: 0.85,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Material(
                color: const Color(0x14FFFFFF),
                shape: const CircleBorder(side: BorderSide(color: Color(0x24FFFFFF))),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.maybePop(context),
                  child: const SizedBox(
                      width: 42, height: 42, child: Icon(PhosphorIconsRegular.caretLeft, color: Colors.white, size: 20)),
                ),
              ),
              const SizedBox(height: 40),
              const Center(child: Tp3D(TpArt.shield, size: 110)),
              const SizedBox(height: 18),
              Center(child: TpFoilText('ยืนยันสองชั้น', style: TpType.title(26, Colors.white))),
              const SizedBox(height: 6),
              Center(
                child: Text('กรอกรหัส 6 หลักจากแอป Authenticator\nรหัสเปลี่ยนทุก 30 วินาที',
                    textAlign: TextAlign.center, style: TpType.body(13.5, const Color(0xA6FFFFFF))),
              ),
              const SizedBox(height: 26),
              TextField(
                controller: _ctrl,
                focusNode: _focus,
                autofocus: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) {
                  if (v.length == 6) _verify();
                },
                style: TpType.money(30, const Color(0xFFF0C96A), w: FontWeight.w700),
                cursorColor: const Color(0xFFF0C96A),
                decoration: const InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: Color(0x14FFFFFF),
                  hintText: '••••••',
                  hintStyle: TextStyle(color: Color(0x40FFFFFF), fontSize: 30),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(18)), borderSide: BorderSide(color: Color(0x24FFFFFF))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(18)),
                      borderSide: BorderSide(color: Color(0xFFF0C96A), width: 1.4)),
                ),
              ),
              SizedBox(
                height: 34,
                child: _error == null
                    ? null
                    : Center(child: Text(_error!, style: TpType.body(13, const Color(0xFFFF8A7A), w: FontWeight.w500))),
              ),
              TpButton('ยืนยัน', icon: PhosphorIconsBold.checkCircle, loading: loading, onPressed: _verify),
            ]),
          ),
        ),
      ),
    );
  }
}
