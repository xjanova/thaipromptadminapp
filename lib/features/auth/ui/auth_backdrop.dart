import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// พื้นหลังหน้าเข้าสู่ระบบ/ปลดล็อก — ภาพลายกนกทองบนราตรี (เจนจาก ChatGPT) + ม่านมืดด้านล่าง
///
/// วงแหวนทองในภาพอยู่ที่ ~26.7% ของความสูงเมื่อวางแบบ cover — วางโลโก้ด้วย [AuthBackdrop.ringY]
class AuthBackdrop extends StatelessWidget {
  const AuthBackdrop({super.key, required this.child, this.dim = 0.7});
  final Widget child;
  final double dim;

  static double ringY(BuildContext context) => MediaQuery.sizeOf(context).height * 0.267;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: const Color(0xFF05070C),
      ),
      child: Stack(children: [
        Positioned.fill(
          child: Image.asset('assets/images/brand/login_bg.webp', fit: BoxFit.cover, alignment: Alignment.topCenter),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0x0005070C),
                  const Color(0xFF05070C).withValues(alpha: 0.55 * dim / 0.7),
                  const Color(0xFF05070C).withValues(alpha: dim),
                ],
                stops: const [0.4, 0.68, 1],
              ),
            ),
          ),
        ),
        Positioned.fill(child: child),
      ]),
    );
  }
}

/// ช่องกรอกสีเข้มบนพื้นหลังหน้าเข้าสู่ระบบ (ใช้สีคงที่ — หน้านี้มืดเสมอทั้งสองธีม)
class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.suffix,
    this.autofillHints,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;
  final Iterable<String>? autofillHints;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      borderSide: BorderSide(color: Color(0x24FFFFFF)),
    );
    return TextField(
      controller: controller,
      obscureText: obscure,
      enabled: enabled,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      autofillHints: autofillHints,
      autocorrect: false,
      enableSuggestions: !obscure,
      style: const TextStyle(fontFamily: 'Anuphan', fontSize: 15.5, color: Colors.white),
      cursorColor: const Color(0xFFF0C96A),
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0x14FFFFFF),
        hintText: hint,
        hintStyle: const TextStyle(fontFamily: 'Anuphan', fontSize: 15, color: Color(0x73FFFFFF)),
        prefixIcon: Icon(icon, color: const Color(0x99FFFFFF), size: 20),
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: border,
        enabledBorder: border,
        disabledBorder: border,
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(color: Color(0xFFF0C96A), width: 1.4),
        ),
      ),
    );
  }
}
