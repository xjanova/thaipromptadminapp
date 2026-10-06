import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/tp_palette.dart';
import '../../core/theme/tp_theme.dart';
import 'tp_kit.dart';

/// โครงหน้าจอมาตรฐาน: หัวรอยัล (ลายกนก + แสงเรือง) → เนื้อหาเป็น sliver
///
/// แบบ A: หัวกลืนกับพื้นมืด · แบบ B: หัวน้ำเงินกรมท่า + ฝาครอบงาช้างมุมโค้ง
class TpPage extends StatelessWidget {
  const TpPage({
    super.key,
    required this.title,
    this.subtitle,
    this.back = false,
    this.onBack,
    this.actions = const [],
    this.showMark = false,
    this.headerBottom,
    this.headerLeading,
    required this.slivers,
    this.onRefresh,
    this.bodyPadding = const EdgeInsets.fromLTRB(16, 14, 16, 0),
    this.bottomSpace = 112,
    this.bottomBar,
    this.controller,
  });

  final String title;
  final String? subtitle;
  final bool back;
  final VoidCallback? onBack;
  final List<Widget> actions;

  /// แสดงโลโก้ T ทองหน้าชื่อหน้า (หน้าหลักของแท็บ)
  final bool showMark;

  /// แทนที่ส่วนซ้ายของหัว (เช่น อวาตาร์ลูกค้าในหน้าแชท)
  final Widget? headerLeading;

  /// แถวใต้ชื่อหน้า (ชิปตัวกรอง / ป้ายสถานะ)
  final Widget? headerBottom;
  final List<Widget> slivers;
  final Future<void> Function()? onRefresh;
  final EdgeInsets bodyPadding;

  /// เว้นล่างให้แท็บบาร์ลอย (หน้าย่อยที่ไม่มีแท็บบาร์ใส่ 32)
  final double bottomSpace;

  /// แถบปุ่มติดล่างจอ (หน้ารายละเอียด)
  final Widget? bottomBar;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    Widget scroll = CustomScrollView(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
      slivers: [
        SliverToBoxAdapter(
          child: TpHeader(
            title: title,
            subtitle: subtitle,
            back: back,
            onBack: onBack,
            actions: actions,
            showMark: showMark,
            leading: headerLeading,
            bottom: headerBottom,
          ),
        ),
        if (p.bodyOverlap > 0)
          SliverToBoxAdapter(
            child: ColoredBox(
              color: p.header.last,
              child: Container(
                height: p.bodyOverlap,
                decoration: BoxDecoration(
                  color: p.bg,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                ),
              ),
            ),
          ),
        SliverPadding(
          padding: p.bodyOverlap > 0 ? bodyPadding.copyWith(top: (bodyPadding.top - 10).clamp(0, 99)) : bodyPadding,
          sliver: SliverMainAxisGroup(slivers: slivers),
        ),
        SliverToBoxAdapter(child: SizedBox(height: bottomSpace + MediaQuery.paddingOf(context).bottom * 0.4)),
      ],
    );
    if (onRefresh != null) {
      scroll = RefreshIndicator(
        color: TpPalette.onGold,
        backgroundColor: const Color(0xFFF0C96A),
        displacement: 64,
        onRefresh: () async {
          HapticFeedback.selectionClick();
          await onRefresh!();
        },
        child: scroll,
      );
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: p.bg,
        systemNavigationBarIconBrightness: p.isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: p.bg,
        // ม่านทึบใต้แถบสถานะ — เลื่อนแล้วเนื้อหาไม่ไหลไปซ้อนกับนาฬิกา/ไอคอนสัญญาณ
        body: _StatusScrim(color: p.header.first, child: scroll),
        bottomNavigationBar: bottomBar,
      ),
    );
  }
}

/// หัวหน้าจอรอยัล
class TpHeader extends StatelessWidget {
  const TpHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.back = false,
    this.onBack,
    this.actions = const [],
    this.showMark = false,
    this.leading,
    this.bottom,
  });

  final String title;
  final String? subtitle;
  final bool back;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final bool showMark;
  final Widget? leading;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: p.header),
      ),
      child: Stack(children: [
        // แสงเรืองมุมขวาบน
        Positioned(
          right: -120,
          top: -160,
          child: IgnorePointer(
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [p.headerGlow, p.headerGlow.withValues(alpha: 0)]),
              ),
            ),
          ),
        ),
        Positioned(
          right: -18,
          top: -6,
          child: IgnorePointer(
            child: Opacity(
              opacity: p.kanokOpacity,
              child: Image.asset('assets/images/brand/kanok-gold.webp', width: 200, cacheWidth: 600),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, top + 8, 16, bottom == null ? 16 : 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (back) ...[
                TpGlassButton(
                  icon: PhosphorIconsRegular.caretLeft,
                  tooltip: 'ย้อนกลับ',
                  onTap: onBack ?? () => context.canPop() ? context.pop() : Navigator.maybePop(context),
                ),
                const SizedBox(width: 12),
              ],
              if (leading != null) ...[leading!, const SizedBox(width: 10)],
              if (showMark && leading == null) ...[
                Image.asset('assets/images/brand/tp-mark.webp', width: 34, height: 34, cacheWidth: 102),
                const SizedBox(width: 11),
              ],
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: leading != null ? TpType.h(16, p.onHeader) : TpType.title(back ? 20 : 22, p.onHeader)),
                  if (subtitle != null)
                    Text(subtitle!,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: TpType.body(12.5, p.onHeaderMuted)),
                ]),
              ),
              for (final a in actions) ...[const SizedBox(width: 8), a],
            ]),
            if (bottom != null) ...[const SizedBox(height: 12), bottom!],
          ]),
        ),
      ]),
    );
  }
}

/// แถบปุ่มติดล่างจอ (หน้ารายละเอียด/แชท)
class TpBottomBar extends StatelessWidget {
  const TpBottomBar({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    return Container(
      decoration: BoxDecoration(
        color: p.sheet,
        border: Border(top: BorderSide(color: p.divider)),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.paddingOf(context).bottom),
      child: child,
    );
  }
}

class TpTabItem {
  const TpTabItem(this.label, this.icon, this.iconOn, {this.badge = 0});
  final String label;
  final IconData icon;
  final IconData iconOn;
  final int badge;
}

/// แท็บบาร์ลอยกระจก — แท็บที่เลือกเป็นทอง + เส้นเรืองด้านบน
class TpTabBar extends StatelessWidget {
  const TpTabBar({super.key, required this.items, required this.index, required this.onTap});
  final List<TpTabItem> items;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 10 + bottom * 0.6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: 70,
            decoration: BoxDecoration(
              color: p.tabBar,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: p.border),
            ),
            child: Row(
              children: List.generate(items.length, (i) {
                final it = items[i];
                final on = i == index;
                final color = on ? p.goldText : p.faint;
                return Expanded(
                  child: InkResponse(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onTap(i);
                    },
                    radius: 40,
                    child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 220),
                        top: on ? 0 : -6,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 220),
                          opacity: on ? 1 : 0,
                          child: Container(
                            width: 22,
                            height: 3,
                            decoration: BoxDecoration(
                              color: p.gold,
                              borderRadius: BorderRadius.circular(3),
                              boxShadow: [BoxShadow(color: p.gold, blurRadius: 10)],
                            ),
                          ),
                        ),
                      ),
                      Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Stack(clipBehavior: Clip.none, children: [
                          Icon(on ? it.iconOn : it.icon, size: 24, color: color),
                          if (it.badge > 0)
                            Positioned(right: -12, top: -6, child: TpBadge(it.badge, ring: p.cardSolid)),
                        ]),
                        const SizedBox(height: 3),
                        Text(it.label,
                            style: TpType.body(11.5, color, w: on ? FontWeight.w600 : FontWeight.w500, height: 1.1)),
                      ]),
                    ]),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

/// ม่านทึบใต้แถบสถานะ — โผล่เฉพาะเมื่อเลื่อนลง (ตอนอยู่บนสุดให้ลายกนก/แสงเรืองของหัวโชว์เต็ม)
class _StatusScrim extends StatefulWidget {
  const _StatusScrim({required this.color, required this.child});
  final Color color;
  final Widget child;

  @override
  State<_StatusScrim> createState() => _StatusScrimState();
}

class _StatusScrimState extends State<_StatusScrim> {
  bool _scrolled = false;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.depth == 0 && n.metrics.axis == Axis.vertical) {
          final s = n.metrics.pixels > 8;
          if (s != _scrolled) setState(() => _scrolled = s);
        }
        return false;
      },
      child: Stack(children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: MediaQuery.paddingOf(context).top,
          child: IgnorePointer(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: _scrolled ? 1 : 0,
              child: ColoredBox(color: widget.color),
            ),
          ),
        ),
      ]),
    );
  }
}
