import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/tp_palette.dart';
import '../../core/theme/tp_theme.dart';
import 'tp_format.dart';

/// ภาพ 3D ประจำแบรนด์ (เจนจาก ChatGPT 2026-10-06 + ชุดเดียวกับแอปลูกค้า)
enum TpArt {
  bill,
  headset,
  payout,
  sms,
  hourglass,
  shield,
  ai,
  members,
  analytics,
  broadcast,
  settings,
  server,
  tarot,
  wallet,
  store,
  scooter,
  emptyDone,
  emptyInbox,
  emptyOffline;

  String get asset => switch (this) {
        TpArt.emptyDone => 'assets/images/icons/empty_done.webp',
        TpArt.emptyInbox => 'assets/images/icons/empty_inbox.webp',
        TpArt.emptyOffline => 'assets/images/icons/empty_offline.webp',
        _ => 'assets/images/icons/$name.webp',
      };
}

class Tp3D extends StatelessWidget {
  const Tp3D(this.art, {super.key, this.size = 42, this.shadow = true});
  final TpArt art;
  final double size;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final img = Image.asset(
      art.asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      cacheWidth: (size * 3).round(),
    );
    if (!shadow) return img;
    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(alpha: context.tp.isDark ? 0.35 : 0.12),
            blurRadius: size * 0.22,
            offset: Offset(0, size * 0.1),
            spreadRadius: -size * 0.18,
          ),
        ],
      ),
      child: img,
    );
  }
}

/// การ์ดมาตรฐาน — ไล่เฉด + ขอบบาง + เงาตามโหมด · แตะได้ถ้าส่ง onTap
class TpCard extends StatelessWidget {
  const TpCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.onTap,
    this.goldBorder = false,
    this.accent,
    this.color,
    this.clip = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final bool goldBorder;

  /// แถบสีบาง ๆ ด้านซ้าย (บอกสถานะของรายการ)
  final Color? accent;
  final Color? color;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final br = BorderRadius.circular(radius);
    Widget content = Padding(padding: padding, child: child);
    if (accent != null) {
      content = Stack(children: [
        content,
        Positioned(
          left: 0,
          top: 14,
          bottom: 14,
          child: Container(
            width: 3,
            decoration: BoxDecoration(
              color: accent,
              borderRadius:
                  const BorderRadius.horizontal(right: Radius.circular(3)),
            ),
          ),
        ),
      ]);
    }
    final deco = BoxDecoration(
      color: color,
      gradient: color == null
          ? LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [p.cardTop, p.cardBottom],
            )
          : null,
      borderRadius: br,
      border: Border.all(color: goldBorder ? p.borderGold : p.border),
      boxShadow: p.shadow,
    );
    return Container(
      decoration: deco,
      clipBehavior: (clip || accent != null) ? Clip.antiAlias : Clip.none,
      child: onTap == null
          ? content
          : Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: br,
                splashColor: p.gold.withValues(alpha: 0.10),
                highlightColor: p.gold.withValues(alpha: 0.05),
                onTap: () {
                  HapticFeedback.selectionClick();
                  onTap!();
                },
                child: content,
              ),
            ),
    );
  }
}

/// การ์ดฮีโร่น้ำเงินเข้ม + ลายกนกมุม + ขอบทอง (ใช้กับตัวเลขสำคัญที่สุดของหน้า)
class TpHeroCard extends StatelessWidget {
  const TpHeroCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.fromLTRB(18, 16, 18, 14)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment(-0.8, -1),
          end: Alignment(0.8, 1),
          colors: TpPalette.heroCard,
          stops: [0, 0.48, 1],
        ),
        border: Border.all(color: const Color(0x38F0C96A)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x73060D1B),
              blurRadius: 40,
              offset: Offset(0, 18),
              spreadRadius: -8),
        ],
      ),
      child: Stack(children: [
        Positioned(
          right: -26,
          top: -20,
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.16,
              child: Image.asset('assets/images/brand/kanok-gold.webp',
                  width: 150, cacheWidth: 450),
            ),
          ),
        ),
        Padding(padding: padding, child: child),
      ]),
    );
  }
}

/// ข้อความทองฟอยล์ (ตัวเลขเงินใหญ่ / ชื่อแอป)
class TpFoilText extends StatelessWidget {
  const TpFoilText(this.text, {super.key, required this.style, this.textAlign});
  final String text;
  final TextStyle style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (r) => const LinearGradient(
          begin: Alignment(-1, -0.3),
          end: Alignment(1, 0.3),
          colors: TpPalette.foil,
          stops: [0, 0.35, 0.6, 0.85],
        ).createShader(r),
        child: Text(text, style: style, textAlign: textAlign),
      );
}

/// ป้ายสถานะเม็ดยา
class TpPill extends StatelessWidget {
  const TpPill(this.label,
      {super.key, this.tone = TpTone.neutral, this.icon, this.dense = false});
  final String label;
  final TpTone tone;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final fg = p.fg(tone);
    return Container(
      height: dense ? 20 : 24,
      padding: EdgeInsets.symmetric(horizontal: dense ? 7 : 9),
      decoration: BoxDecoration(
          color: p.soft(tone), borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: dense ? 11 : 13, color: fg),
          const SizedBox(width: 4)
        ],
        // ข้อความยาวตัดด้วย … แทนล้นกรอบ (จอแคบ 320dp)
        Flexible(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: TpType.body(dense ? 11 : 12, fg,
                  w: FontWeight.w600, height: 1.1)),
        ),
      ]),
    );
  }
}

/// ตัวนับงาน (กล่องเหลี่ยมมนตัวเลขหนา)
class TpCount extends StatelessWidget {
  const TpCount(this.count, {super.key, this.tone = TpTone.gold});
  final int count;
  final TpTone tone;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    return Container(
      constraints: const BoxConstraints(minWidth: 30),
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: p.soft(tone), borderRadius: BorderRadius.circular(9)),
      child: Text(TpFmt.count(count), style: TpType.money(14, p.fg(tone))),
    );
  }
}

/// จุดแดงตัวเลข (บนแท็บ/ไอคอน)
class TpBadge extends StatelessWidget {
  const TpBadge(this.count, {super.key, this.ring});
  final int count;
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFE5484D),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: ring ?? context.tp.cardSolid, width: 2),
      ),
      child: Text(count > 99 ? '99+' : '$count',
          style: TpType.money(10.5, Colors.white, w: FontWeight.w700)
              .copyWith(height: 1)),
    );
  }
}

/// ปุ่มไอคอนกระจกบนหัวหน้าจอ
class TpGlassButton extends StatelessWidget {
  const TpGlassButton(
      {super.key,
      required this.icon,
      this.onTap,
      this.dot = false,
      this.tooltip,
      this.gold = false});
  final IconData icon;
  final VoidCallback? onTap;
  final bool dot;
  final String? tooltip;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final btn = Material(
      color: gold ? const Color(0x1AF0C96A) : p.glass,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: gold ? const Color(0x59F0C96A) : p.glassBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        child: SizedBox(
          width: 42,
          height: 42,
          child: Stack(alignment: Alignment.center, children: [
            Icon(icon,
                size: 21, color: gold ? const Color(0xFFF0C96A) : p.onHeader),
            if (dot)
              Positioned(
                top: 8,
                right: 9,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B5B),
                    shape: BoxShape.circle,
                    border: Border.all(color: p.header.last, width: 1.5),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

enum TpButtonKind { gold, outline, danger, ghost, navy }

/// ปุ่มมาตรฐาน — ปุ่มยืนยัน/การกระทำหลักใช้ทองเสมอ (เจ้าของเคาะ 2026-09-26)
class TpButton extends StatelessWidget {
  const TpButton(
    this.label, {
    super.key,
    this.onPressed,
    this.kind = TpButtonKind.gold,
    this.icon,
    this.loading = false,
    this.height = 52,
    this.expand = true,
    this.fontSize,
  });

  const TpButton.outline(this.label,
      {super.key,
      this.onPressed,
      this.icon,
      this.loading = false,
      this.height = 52,
      this.expand = true,
      this.fontSize})
      : kind = TpButtonKind.outline;

  const TpButton.danger(this.label,
      {super.key,
      this.onPressed,
      this.icon,
      this.loading = false,
      this.height = 52,
      this.expand = true,
      this.fontSize})
      : kind = TpButtonKind.danger;

  const TpButton.ghost(this.label,
      {super.key,
      this.onPressed,
      this.icon,
      this.loading = false,
      this.height = 44,
      this.expand = false,
      this.fontSize})
      : kind = TpButtonKind.ghost;

  final String label;
  final VoidCallback? onPressed;
  final TpButtonKind kind;
  final IconData? icon;
  final bool loading;
  final double height;
  final bool expand;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final disabled = onPressed == null || loading;
    final (
      Color fg,
      Gradient? grad,
      Color? bg,
      Color? border,
      List<BoxShadow> shadow
    ) = switch (kind) {
      TpButtonKind.gold => (
          TpPalette.onGold,
          const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: TpPalette.goldButton,
              stops: [0, 0.42, 1]),
          null,
          null,
          [
            BoxShadow(
                color: const Color(0xFFCFA349).withValues(alpha: 0.35),
                blurRadius: 22,
                offset: const Offset(0, 8),
                spreadRadius: -6)
          ],
        ),
      TpButtonKind.navy => (
          const Color(0xFFF0C96A),
          const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF22427A), Color(0xFF10223F)]),
          null,
          const Color(0x38F0C96A),
          const <BoxShadow>[],
        ),
      TpButtonKind.outline => (
          p.text,
          null,
          p.cardSolid,
          p.border,
          const <BoxShadow>[]
        ),
      TpButtonKind.danger => (
          p.danger,
          null,
          p.dangerSoft,
          null,
          const <BoxShadow>[]
        ),
      TpButtonKind.ghost => (
          p.goldText,
          null,
          Colors.transparent,
          null,
          const <BoxShadow>[]
        ),
    };
    final br = BorderRadius.circular(height >= 50 ? 16 : 13);
    final textStyle = TpType.h(fontSize ?? (height >= 50 ? 15.5 : 14), fg);

    final inner = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.2, color: fg))
        else if (icon != null)
          Icon(icon, size: 19, color: fg),
        if (loading || icon != null) const SizedBox(width: 8),
        Flexible(
            child: Text(label,
                style: textStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis)),
      ],
    );

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: disabled && !loading ? 0.45 : 1,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: grad,
          color: bg,
          borderRadius: br,
          border: border == null ? null : Border.all(color: border),
          boxShadow: disabled ? const [] : shadow,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: br,
            onTap: disabled
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    onPressed!();
                  },
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: inner),
          ),
        ),
      ),
    );
  }
}

/// หัวข้อส่วน + ปุ่มขวา (เช่น "ดูทั้งหมด")
class TpSection extends StatelessWidget {
  const TpSection(this.title,
      {super.key, this.trailing, this.action, this.onAction, this.padding});
  final String title;
  final Widget? trailing;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(4, 22, 4, 10),
      child: Row(children: [
        Expanded(child: Text(title, style: TpType.h(17, p.textStrong))),
        if (trailing != null) trailing!,
        if (action != null)
          GestureDetector(
            onTap: onAction,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(action!,
                    style: TpType.body(13, p.goldText, w: FontWeight.w600)),
                Icon(PhosphorIconsBold.caretRight, size: 12, color: p.goldText),
              ]),
            ),
          ),
      ]),
    );
  }
}

/// แถวรายการ (ใช้ใน TpGroup) — นำหน้าด้วยภาพ 3D หรือไอคอนในกล่องสี
class TpRow extends StatelessWidget {
  const TpRow({
    super.key,
    required this.title,
    this.subtitle,
    this.art,
    this.icon,
    this.iconTone = TpTone.navy,
    this.leading,
    this.trailing,
    this.onTap,
    this.chevron = true,
    this.titleStyle,
    this.dense = false,
  });

  final String title;
  final String? subtitle;
  final TpArt? art;
  final IconData? icon;
  final TpTone iconTone;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool chevron;
  final TextStyle? titleStyle;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    Widget? lead = leading;
    if (lead == null && art != null) lead = Tp3D(art!, size: dense ? 36 : 42);
    if (lead == null && icon != null) {
      lead = TpIconTile(icon!, tone: iconTone, size: dense ? 36 : 40);
    }
    return InkWell(
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap!();
            },
      child: Padding(
        padding:
            EdgeInsets.symmetric(horizontal: 14, vertical: dense ? 10 : 12),
        child: Row(children: [
          if (lead != null) ...[lead, const SizedBox(width: 12)],
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      style: titleStyle ??
                          TpType.h(14.5, p.textStrong, w: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(subtitle!,
                          style: TpType.body(12.5, p.muted),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ),
                ]),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          if (chevron && onTap != null) ...[
            const SizedBox(width: 6),
            Icon(PhosphorIconsRegular.caretRight, size: 16, color: p.faint),
          ],
        ]),
      ),
    );
  }
}

/// กลุ่มแถวในการ์ดเดียว คั่นเส้นบาง
class TpGroup extends StatelessWidget {
  const TpGroup({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) items.add(Divider(height: 1, thickness: 1, color: p.divider));
      items.add(children[i]);
    }
    return TpCard(
        padding: EdgeInsets.zero, clip: true, child: Column(children: items));
  }
}

/// ไอคอนเส้นในกล่องสี่เหลี่ยมมน
class TpIconTile extends StatelessWidget {
  const TpIconTile(this.icon,
      {super.key, this.tone = TpTone.navy, this.size = 40});
  final IconData icon;
  final TpTone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          color: p.soft(tone),
          borderRadius: BorderRadius.circular(size * 0.34)),
      child: Icon(icon, size: size * 0.5, color: p.fg(tone)),
    );
  }
}

/// อวาตาร์ตัวอักษร + ป้ายแพลตฟอร์ม (Messenger / LINE / Telegram)
class TpAvatar extends StatelessWidget {
  const TpAvatar(
      {super.key,
      required this.name,
      this.platform,
      this.size = 42,
      this.online = false,
      this.gold = false});
  final String? name;
  final String? platform;
  final double size;
  final bool online;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final pf = platformStyle(platform);
    return SizedBox(
      width: size + 4,
      height: size + 4,
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: gold ? null : p.navySoft,
            gradient: gold
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFF3DC9B), Color(0xFFC99A40)])
                : null,
          ),
          child: Text(TpFmt.initial(name),
              style: TpType.h(size * 0.38, gold ? TpPalette.onGold : p.navyIcon)
                  .copyWith(height: 1)),
        ),
        if (pf != null)
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: size * 0.45,
              height: size * 0.45,
              decoration: BoxDecoration(
                color: pf.$1,
                shape: BoxShape.circle,
                border: Border.all(color: p.cardSolid, width: 2),
              ),
              child: Icon(pf.$2, size: size * 0.24, color: Colors.white),
            ),
          )
        else if (online)
          Positioned(
            right: 1,
            bottom: 1,
            child: Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: const Color(0xFF3DDC84),
                shape: BoxShape.circle,
                border: Border.all(color: p.cardSolid, width: 2),
              ),
            ),
          ),
      ]),
    );
  }

  /// สี + ไอคอนของแพลตฟอร์มแชท (null = ไม่แสดงป้าย)
  static (Color, IconData, String)? platformStyle(String? platform) {
    final v = (platform ?? '').toLowerCase();
    if (v.contains('line')) {
      return (TpPalette.line, PhosphorIconsFill.chatCircle, 'LINE');
    }
    if (v.contains('tele') || v == 'tg') {
      return (TpPalette.telegram, PhosphorIconsFill.telegramLogo, 'Telegram');
    }
    if (v.contains('face') || v.contains('fb') || v.contains('messenger')) {
      return (TpPalette.facebook, PhosphorIconsFill.messengerLogo, 'Messenger');
    }
    if (v.contains('web')) {
      return (const Color(0xFF8A6420), PhosphorIconsFill.globe, 'เว็บ');
    }
    return null;
  }
}

/// ตัวเลือกแบบชิป (ตัวกรอง) พร้อมตัวนับ — วางบนหัวหน้าจอ (onHeader) หรือในเนื้อหา
class TpChips<T> extends StatelessWidget {
  const TpChips({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    this.onHeader = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 18),
  });

  final List<TpChipItem<T>> items;
  final T value;
  final ValueChanged<T> onChanged;
  final bool onHeader;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (context, i) {
          final it = items[i];
          final on = it.value == value;
          final fg =
              on ? TpPalette.onGold : (onHeader ? p.onHeaderMuted : p.muted);
          return GestureDetector(
            onTap: () {
              if (on) return;
              HapticFeedback.selectionClick();
              onChanged(it.value);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 13),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: on
                    ? const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFF3DC9B), Color(0xFFD9B25C)])
                    : null,
                color: on ? null : (onHeader ? p.glass : p.cardSolid),
                borderRadius: BorderRadius.circular(12),
                border: on
                    ? null
                    : Border.all(color: onHeader ? p.glassBorder : p.border),
                boxShadow: on
                    ? [
                        BoxShadow(
                            color:
                                const Color(0xFFCFA349).withValues(alpha: 0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                            spreadRadius: -4)
                      ]
                    : null,
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(it.label,
                    style:
                        TpType.body(13, fg, w: FontWeight.w600, height: 1.1)),
                if (it.count != null) ...[
                  const SizedBox(width: 6),
                  Text(TpFmt.count(it.count),
                      style: TpType.money(
                          12.5, fg.withValues(alpha: on ? 0.75 : 0.7))),
                ],
              ]),
            ),
          );
        },
      ),
    );
  }
}

class TpChipItem<T> {
  const TpChipItem(this.value, this.label, {this.count});
  final T value;
  final String label;
  final int? count;
}

/// แถว key–value ในหน้ารายละเอียด
class TpKv extends StatelessWidget {
  const TpKv(this.label, this.value,
      {super.key, this.valueColor, this.mono = false});
  final String label;
  final String value;
  final Color? valueColor;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 118, child: Text(label, style: TpType.body(13, p.muted))),
        Expanded(
          child: Text(value,
              textAlign: TextAlign.right,
              style: mono
                  ? TpType.money(13.5, valueColor ?? p.text, w: FontWeight.w600)
                  : TpType.body(13.5, valueColor ?? p.text,
                      w: FontWeight.w600)),
        ),
      ]),
    );
  }
}

/// สวิตช์พร้อมป้ายข้อความ (ใช้ในหน้าตั้งค่า/ควบคุม)
class TpSwitchRow extends StatelessWidget {
  const TpSwitchRow(
      {super.key,
      required this.title,
      this.subtitle,
      required this.value,
      this.onChanged,
      this.art,
      this.icon,
      this.busy = false});
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final TpArt? art;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return TpRow(
      title: title,
      subtitle: subtitle,
      art: art,
      icon: icon,
      chevron: false,
      trailing: busy
          ? const SizedBox(
              width: 44,
              height: 22,
              child: Center(
                  child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))))
          : Switch.adaptive(value: value, onChanged: onChanged),
    );
  }
}
