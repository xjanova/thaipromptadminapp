import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_envelope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../gen/l10n/app_localizations.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../providers/auth_controller.dart';

class Verify2FAScreen extends ConsumerStatefulWidget {
  const Verify2FAScreen({super.key, required this.challengeToken});
  final String challengeToken;

  @override
  ConsumerState<Verify2FAScreen> createState() => _Verify2FAScreenState();
}

class _Verify2FAScreenState extends ConsumerState<Verify2FAScreen> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _ctrl.text.trim();
    if (code.length < 6) return;
    try {
      await ref.read(authControllerProvider.notifier).verifyTwoFactor(widget.challengeToken, code);
      // router จะ redirect ไป dashboard เมื่อ admin != null
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final state = ref.watch(authControllerProvider);

    return Scaffold(
      body: Stack(
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(gradient: AppColors.cosmicGradient),
            child: SizedBox.expand(),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                  const SizedBox(height: 30),
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.verified_user, color: Colors.white, size: 40),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    l10n.twoFactorTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.twoFactorSubtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 14),
                  ),
                  const SizedBox(height: 32),
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    fillOpacity: 0.12,
                    child: Column(
                      children: [
                        TextField(
                          controller: _ctrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(8),
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          autofocus: true,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            letterSpacing: 12,
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: InputDecoration(
                            hintText: '••••••',
                            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4), letterSpacing: 12),
                            fillColor: Colors.white.withValues(alpha: 0.10),
                          ),
                          onSubmitted: (_) => _verify(),
                        ),
                        const SizedBox(height: 18),
                        GradientButton(
                          onPressed: state.loading ? null : _verify,
                          loading: state.loading,
                          icon: Icons.check_circle_outline,
                          label: l10n.twoFactorVerify,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
