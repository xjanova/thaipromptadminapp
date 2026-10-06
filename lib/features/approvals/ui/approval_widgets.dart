import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/storage/secure_storage.dart';
import '../../../shared/ui/tp.dart';
import '../data/approvals_repository.dart';

// ชิ้นส่วนร่วมของหน้าคิวอนุมัติทุกหน้า

// ───────────────────────── เวลารอ ─────────────────────────

/// ระยะเวลาแบบอ่านง่าย รวมหน่วยวัน ("2 วัน 3 ชม.")
String approvalDuration(int minutes) {
  if (minutes < 1440) return TpFmt.duration(minutes < 1 ? 1 : minutes);
  final d = minutes ~/ 1440, h = (minutes % 1440) ~/ 60;
  return h == 0 ? '$d วัน' : '$d วัน $h ชม.';
}

const _thMonths = [
  'ม.ค.',
  'ก.พ.',
  'มี.ค.',
  'เม.ย.',
  'พ.ค.',
  'มิ.ย.',
  'ก.ค.',
  'ส.ค.',
  'ก.ย.',
  'ต.ค.',
  'พ.ย.',
  'ธ.ค.',
];

/// วันที่จาก "YYYY-MM-DD" → "12 ม.ค. 2538" (ปี พ.ศ. เต็ม — ใช้กับวันเกิด/วันหมดอายุบัตร)
String approvalDate(String? ymd) {
  final d = ymd == null ? null : DateTime.tryParse(ymd);
  if (d == null) return ymd ?? '-';
  return '${d.day} ${_thMonths[d.month - 1]} ${d.year + 543}';
}

/// ตัดข้อความยาวสำหรับใส่ในป้าย (TpPill ไม่ตัดคำเอง — ชื่อยาวจะล้นการ์ดที่ 320dp)
String pillText(String s, [int max = 22]) {
  final r = s.runes;
  if (r.length <= max) return s;
  return '${String.fromCharCodes(r.take(max - 1))}…';
}

/// วันเวลาเต็ม "6 ต.ค. 69 14:08"
String approvalWhen(DateTime? d) =>
    d == null ? '-' : '${TpFmt.shortDate(d)} ${TpFmt.time(d)}';

/// สถานะ KYC ของบัญชีผู้ใช้เป็นภาษาไทย
String kycStatusLabel(String? s) => switch (s) {
      'approved' || 'verified' => 'ยืนยันตัวตนแล้ว',
      'pending' => 'รอตรวจ',
      'rejected' => 'ถูกปฏิเสธ',
      'retake' => 'รอถ่ายใหม่',
      null || '' || 'not_submitted' || 'none' => 'ยังไม่ยืนยันตัวตน',
      final String other => other,
    };

TpTone waitTone(int minutes) => minutes >= 1440
    ? TpTone.danger
    : (minutes >= 240 ? TpTone.warning : TpTone.neutral);

/// ป้าย "รอ 40 นาที" — สีเข้มขึ้นตามเวลาที่รอ
class WaitPill extends StatelessWidget {
  const WaitPill(this.minutes, {super.key, this.dense = true});
  final int? minutes;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final m = minutes;
    if (m == null) return const SizedBox.shrink();
    return TpPill(m < 1 ? 'เพิ่งเข้ามา' : 'รอ ${approvalDuration(m)}',
        tone: waitTone(m), icon: PhosphorIconsBold.clock, dense: dense);
  }
}

// ───────────────────────── ช่องค้นหาบนหัว ─────────────────────────

/// ช่องค้นหาบนหัวหน้าจอ (หน่วง 400 มิลลิวินาที) — เป็นเจ้าของ controller/timer เอง และ dispose ให้ครบ
class ApprovalSearchBar extends StatefulWidget {
  const ApprovalSearchBar(
      {super.key, required this.hint, required this.onQuery});
  final String hint;
  final ValueChanged<String> onQuery;

  @override
  State<ApprovalSearchBar> createState() => _ApprovalSearchBarState();
}

class _ApprovalSearchBarState extends State<ApprovalSearchBar> {
  final _c = TextEditingController();
  Timer? _debounce;
  String _last = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _c.dispose();
    super.dispose();
  }

  void _emit(String v) {
    _debounce?.cancel();
    final q = v.trim();
    if (!mounted || q == _last) return;
    _last = q;
    widget.onQuery(q);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    OutlineInputBorder border(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c));
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _c,
      builder: (context, v, _) => TextField(
        controller: _c,
        onChanged: (s) {
          _debounce?.cancel();
          _debounce = Timer(const Duration(milliseconds: 400), () => _emit(s));
        },
        onSubmitted: _emit,
        textInputAction: TextInputAction.search,
        style: TpType.body(14.5, p.onHeader),
        cursorColor: p.gold,
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: p.glass,
          hintText: widget.hint,
          hintStyle: TpType.body(14, p.onHeaderMuted),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          prefixIcon: Icon(PhosphorIconsRegular.magnifyingGlass,
              size: 19, color: p.onHeaderMuted),
          suffixIcon: v.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'ล้างคำค้น',
                  icon: Icon(PhosphorIconsRegular.xCircle,
                      size: 19, color: p.onHeaderMuted),
                  onPressed: () {
                    _c.clear();
                    _emit('');
                  },
                ),
          border: border(p.glassBorder),
          enabledBorder: border(p.glassBorder),
          focusedBorder: border(p.gold.withValues(alpha: 0.65)),
        ),
      ),
    );
  }
}

// ───────────────────────── รูปส่วนตัว (ต้องแนบ token) ─────────────────────────

Map<String, String>? _authHeaders(String? token) =>
    (token == null || token.isEmpty)
        ? null
        : {'Authorization': 'Bearer $token'};

/// ล้างรูปส่วนตัวออกจากแคชหน่วยความจำ (เรียกตอนปิดแผ่นรายละเอียด)
///
/// รูปบัตร/เอกสารโหลดผ่าน Image.network = อยู่ในแคชหน่วยความจำเท่านั้น ไม่ลงดิสก์
/// ใช้ provider ตัวเดียวทั้งรูปย่อและรูปเต็ม (ไม่ตั้ง cacheWidth) → เปิดดูหนึ่งครั้ง = โหลดหนึ่งครั้ง = บันทึกการเปิดดู (PDPA) หนึ่งแถว
void evictPrivatePhotos(Iterable<String> urls) {
  for (final u in urls) {
    NetworkImage(u).evict();
  }
}

/// รูปย่อของรูปส่วนตัว — แตะเพื่อดูเต็มจอ (ซูมได้)
class PrivatePhoto extends ConsumerWidget {
  const PrivatePhoto({
    super.key,
    required this.url,
    required this.label,
    this.requiresAuth = true,
    this.height = 112,
    this.missingText = 'ไม่มีรูป',
  });

  final String? url;
  final String label;
  final bool requiresAuth;
  final double height;
  final String missingText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.tp;
    final u = url;
    Widget frame(Widget child) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(height: height, child: child)),
              const SizedBox(height: 5),
              Text(label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TpType.body(11.5, p.muted, w: FontWeight.w500)),
            ]);
    Widget placeholder(IconData icon, String text) => Container(
          color: p.inset,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(6),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: p.faint, size: 22),
            const SizedBox(height: 4),
            Text(text,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TpType.body(11, p.faint)),
          ]),
        );

    if (u == null) {
      return frame(placeholder(PhosphorIconsRegular.imageBroken, missingText));
    }
    final token = requiresAuth ? ref.watch(authTokenProvider) : null;
    // อ่าน token ไม่ได้ (error) = ลองโหลดแบบไม่มี token → เซิร์ฟเวอร์ตอบ 401 → แสดง "โหลดรูปไม่ได้"
    if (token != null && token.isLoading && !token.hasValue) {
      return frame(TpSkeleton(height: height, radius: 14));
    }
    final headers = _authHeaders(token?.valueOrNull);
    return frame(
      Material(
        color: p.inset,
        child: InkWell(
          onTap: () =>
              showPrivatePhoto(context, url: u, label: label, headers: headers),
          child: Stack(fit: StackFit.expand, children: [
            Image.network(
              u,
              headers: headers,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : TpSkeleton(height: height, radius: 0),
              errorBuilder: (_, __, ___) => placeholder(
                  PhosphorIconsRegular.imageBroken, 'โหลดรูปไม่ได้'),
            ),
            Positioned(
              right: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                    color: p.sheet.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(PhosphorIconsRegular.arrowsOut,
                    size: 13, color: p.text),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// ดูรูปเต็มจอ (พื้นดำเสมอทั้งสองโหมด) — ซูม/เลื่อนได้ แตะปุ่มปิดหรือปัดกลับ
Future<void> showPrivatePhoto(BuildContext context,
    {required String url,
    required String label,
    Map<String, String>? headers}) {
  return showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: 'ปิดรูป',
    barrierColor: Colors.black.withValues(alpha: 0.94),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (ctx, _, __) =>
        _PhotoViewer(url: url, label: label, headers: headers),
  );
}

class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer({required this.url, required this.label, this.headers});
  final String url;
  final String label;
  final Map<String, String>? headers;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: Stack(children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 6,
              child: Center(
                child: Image.network(
                  url,
                  headers: headers,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  loadingBuilder: (context, child, progress) => progress == null
                      ? child
                      : const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.4, color: Colors.white)),
                  errorBuilder: (_, __, ___) => Text('โหลดรูปไม่ได้',
                      style: TpType.body(14, Colors.white70)),
                ),
              ),
            ),
          ),
          Positioned(
            left: 8,
            right: 8,
            top: 4,
            child: Row(children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TpType.h(15, Colors.white)),
                ),
              ),
              IconButton(
                tooltip: 'ปิด',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(PhosphorIconsBold.x,
                    color: Colors.white, size: 22),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ───────────────────────── การกระทำ ─────────────────────────

/// ถามเหตุผล (บังคับกรอก) แล้วตรวจความยาวตามที่เซิร์ฟเวอร์รับ — คืน null ถ้ายกเลิก/ไม่ผ่าน
///
/// นับความยาวแบบ code point ให้ตรงกับ mb_strlen ของ Laravel (สระ/วรรณยุกต์ไทยนับแยก)
Future<String?> askReason(
  BuildContext context, {
  required String title,
  String? message,
  String hint = 'เหตุผล',
  String confirmLabel = 'ยืนยัน',
  bool danger = true,
  int min = 1,
  int max = 500,
}) async {
  final r = await tpPrompt(context,
      title: title,
      message: message,
      hint: hint,
      confirmLabel: confirmLabel,
      danger: danger);
  if (r == null || !context.mounted) return null;
  final n = r.runes.length;
  if (n < min) {
    tpToast(context, 'เหตุผลต้องยาวอย่างน้อย $min ตัวอักษร',
        kind: TpToastKind.error);
    return null;
  }
  if (n > max) {
    tpToast(context, 'เหตุผลยาวเกิน $max ตัวอักษร (ตอนนี้ $n)',
        kind: TpToastKind.error);
    return null;
  }
  return r;
}

/// ยิงการกระทำของคิวอนุมัติ → แจ้งผล + รีเฟรชตัวเลขป้าย + ปิดแผ่น (คืน true ให้หน้ารายการโหลดใหม่)
///
/// - สำเร็จ / เป็นผลนี้อยู่แล้ว (`already`) = แจ้ง + ปิดแผ่น
/// - ผิดพลาดทั่วไป = แจ้ง + คงแผ่นไว้ให้ลองใหม่
/// - รายการเปลี่ยนสถานะไปแล้ว (แอดมินอีกคนตัดสิน / ถูกลบ) = แจ้ง + ปิดแผ่นแล้วโหลดใหม่
Future<bool> runApprovalAction(
  BuildContext context,
  Future<ApprovalResult> Function() call, {
  bool closeSheet = true,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  try {
    final r = await call();
    container.invalidate(approvalsSummaryProvider);
    if (!context.mounted) return true;
    tpToast(context, r.message,
        kind: r.already ? TpToastKind.info : TpToastKind.success);
    if (closeSheet) Navigator.of(context).pop(true);
    return true;
  } catch (e) {
    if (!context.mounted) return false;
    tpToast(context, tpErrorText(e), kind: TpToastKind.error);
    if (e is ApprovalError && e.stale) {
      container.invalidate(approvalsSummaryProvider);
      if (closeSheet) Navigator.of(context).pop(true);
    }
    return false;
  }
}

// ───────────────────────── ชิ้นส่วนแสดงผล ─────────────────────────

/// แถบข้อความแจ้งในแผ่นรายละเอียด (เตือน/ข้อมูล)
class ApprovalNotice extends StatelessWidget {
  const ApprovalNotice(
      {super.key, required this.text, this.tone = TpTone.warning, this.icon});
  final String text;
  final TpTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
          color: p.soft(tone), borderRadius: BorderRadius.circular(14)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon ?? PhosphorIconsFill.warningCircle,
              size: 17, color: p.fg(tone)),
        ),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style: TpType.body(13, p.fg(tone), w: FontWeight.w500))),
      ]),
    );
  }
}

/// หัวข้อ + การ์ดเนื้อหา ในแผ่นรายละเอียด
class DetailSection extends StatelessWidget {
  const DetailSection(this.title,
      {super.key, required this.children, this.trailing});
  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TpSection(title,
          trailing: trailing, padding: const EdgeInsets.fromLTRB(4, 18, 4, 8)),
      TpCard(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      ),
    ]);
  }
}

/// โครงกระพริบของแผ่นรายละเอียด (โหลดครั้งแรก)
class SheetSkeleton extends StatelessWidget {
  const SheetSkeleton({super.key});

  @override
  Widget build(BuildContext context) =>
      const Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(height: 8),
        TpSkeleton(height: 112, radius: 18),
        SizedBox(height: 16),
        TpSkeleton(width: 140, height: 14),
        SizedBox(height: 10),
        TpSkeleton(height: 120, radius: 18),
        SizedBox(height: 16),
        TpSkeleton(width: 110, height: 14),
        SizedBox(height: 10),
        TpSkeleton(height: 90, radius: 18),
      ]);
}

/// ส่วนหัวของแผ่นรายละเอียด: ภาพ/อวาตาร์ + ชื่อ + บรรทัดรอง + ป้ายสถานะ
class SheetHeader extends StatelessWidget {
  const SheetHeader(
      {super.key,
      required this.leading,
      required this.title,
      this.subtitle,
      this.pill});
  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? pill;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      leading,
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TpType.h(16.5, p.textStrong)),
          if (subtitle != null && subtitle!.isNotEmpty)
            Text(subtitle!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TpType.body(12.5, p.muted)),
          if (pill != null) ...[const SizedBox(height: 6), pill!],
        ]),
      ),
    ]);
  }
}

/// เส้นเวลาในแผ่นรายละเอียด (จุด + เส้น + เวลา)
class ApprovalTimeline extends StatelessWidget {
  const ApprovalTimeline({super.key, required this.steps});
  final List<(String, DateTime)> steps;

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    return Column(children: [
      for (var i = 0; i < steps.length; i++)
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              width: 20,
              child: Column(children: [
                const SizedBox(height: 4),
                Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == steps.length - 1 ? p.gold : p.success,
                  ),
                ),
                if (i < steps.length - 1)
                  Expanded(child: Container(width: 2, color: p.divider)),
              ]),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: i < steps.length - 1 ? 12 : 0),
                child: Row(children: [
                  Expanded(
                      child: Text(steps[i].$1,
                          style:
                              TpType.body(13.5, p.text, w: FontWeight.w500))),
                  Text(TpFmt.dateTime(steps[i].$2),
                      style: TpType.money(12.5, p.muted, w: FontWeight.w500)),
                ]),
              ),
            ),
          ]),
        ),
    ]);
  }
}
