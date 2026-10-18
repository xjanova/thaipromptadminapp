import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/ui/tp.dart';
import 'auto_updater.dart';
import 'reinstall_helper.dart';
import 'update_checker.dart';
import 'update_models.dart';

/// แผ่นแจ้งอัปเดต — ดาวน์โหลด APK จาก GitHub Releases แล้วติดตั้งทับในแอป
/// (แอปแอดมินใช้คนเดียว เจ้าของอนุญาตให้อัปเดตผ่าน GitHub ได้ — 2026-10-06)
Future<void> showUpdateAvailableDialog(
    BuildContext context, UpdateCheckResult result) async {
  final release = result.release;
  if (release == null) return;
  await tpShowSheet<void>(
    context,
    initial: 0.72,
    min: 0.45,
    builder: (ctx, scroll) => _UpdateSheet(result: result, scroll: scroll),
  );
}

/// เลือก APK ให้ตรงสถาปัตยกรรมเครื่อง (arm64 / armv7 / x86_64) — ไม่เจอค่อยใช้ universal
Future<GitHubAsset?> pickApkForDevice(GitHubRelease release) async {
  final apks = release.assets
      .where((a) => a.name.toLowerCase().endsWith('.apk'))
      .toList();
  if (apks.isEmpty) return null;
  if (Platform.isAndroid) {
    try {
      final abis = (await DeviceInfoPlugin().androidInfo).supportedAbis;
      for (final abi in abis) {
        final hit = apks
            .where((a) => a.name.toLowerCase().contains(abi.toLowerCase()))
            .firstOrNull;
        if (hit != null) return hit;
      }
    } catch (_) {}
  }
  return apks
          .where((a) => a.name.toLowerCase().contains('universal'))
          .firstOrNull ??
      apks.first;
}

class _UpdateSheet extends ConsumerStatefulWidget {
  const _UpdateSheet({required this.result, required this.scroll});
  final UpdateCheckResult result;
  final ScrollController scroll;

  @override
  ConsumerState<_UpdateSheet> createState() => _UpdateSheetState();
}

/// ขั้นของทาง "ถอนก่อนแล้วลงใหม่" (ใช้เมื่อลายเซ็นไม่ตรง)
enum _ReKind { idle, downloading, saved, error }

class _UpdateSheetState extends ConsumerState<_UpdateSheet> {
  StreamSubscription<OtaUpdateState>? _sub;
  OtaUpdateState? _state;
  GitHubAsset? _apk;

  /// null = ยังตรวจลายเซ็นไม่เสร็จ
  InstalledSigner? _signer;
  _ReKind _reKind = _ReKind.idle;
  int _rePct = 0; // -1 = ไม่รู้ขนาดไฟล์
  String? _reFile;
  String? _reError;
  CancelToken? _reCancel;

  @override
  void initState() {
    super.initState();
    pickApkForDevice(widget.result.release!).then((a) {
      if (mounted) setState(() => _apk = a);
    });
    ref.read(reinstallHelperProvider).installedSigner().then((s) {
      if (mounted) setState(() => _signer = s);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _reCancel?.cancel();
    super.dispose();
  }

  /// ต้องถอนก่อน: ตรวจลายเซ็นพบว่าเป็นคีย์อื่น หรือตัวติดตั้งเพิ่งตอบกลับมาว่าลายเซ็นไม่ตรง
  bool get _needsReinstall =>
      _signer == InstalledSigner.foreign ||
      (_state?.isError == true && (_state!.error ?? '').contains('ลายเซ็น'));

  Future<void> _startReinstall() async {
    final apk = _apk;
    if (apk == null) {
      _openPage();
      return;
    }
    if (_reKind == _ReKind.downloading) return; // กดซ้ำ — ไม่โหลดซ้อน
    _reCancel?.cancel();
    final cancel = CancelToken();
    _reCancel = cancel;
    setState(() {
      _reKind = _ReKind.downloading;
      _rePct = 0;
      _reError = null;
    });
    try {
      final saved = await ref.read(reinstallHelperProvider).saveApkToDownloads(
            apk.browserDownloadUrl,
            apk.name,
            cancelToken: cancel,
            onProgress: (p) {
              if (mounted && _reCancel == cancel) setState(() => _rePct = p);
            },
          );
      if (!mounted || _reCancel != cancel) return;
      setState(() {
        _reKind = _ReKind.saved;
        _reFile = saved;
      });
    } on ReinstallException catch (e) {
      if (!mounted || _reCancel != cancel) return;
      setState(() {
        _reKind = _ReKind.error;
        _reError = e.message;
      });
    } catch (_) {
      if (!mounted || _reCancel != cancel) return;
      setState(() {
        _reKind = _ReKind.error;
        _reError = 'เตรียมไฟล์ติดตั้งไม่สำเร็จ ลองใหม่ หรือดาวน์โหลดจากหน้าเว็บ';
      });
    }
  }

  void _cancelReinstall() {
    _reCancel?.cancel();
    _reCancel = null;
    setState(() {
      _reKind = _ReKind.idle;
      _rePct = 0;
    });
  }

  Future<void> _uninstall() async {
    final file = _reFile ?? _apk?.name ?? 'ไฟล์ .apk';
    final ok = await tpConfirm(
      context,
      title: 'ถอนแอปเดิมตอนนี้?',
      message: 'ข้อมูลในเครื่องจะถูกลบ (การจับคู่อุปกรณ์ การเข้าสู่ระบบ PIN) '
          'ต้องจับคู่และเข้าสู่ระบบใหม่หลังติดตั้ง\n\n'
          'ไฟล์ติดตั้งอยู่ที่ Download/$file แล้ว '
          'หลังถอนเสร็จให้เปิดแอป "ไฟล์" → Download → แตะไฟล์นี้ → ติดตั้ง',
      confirmLabel: 'ถอนแอป',
      danger: true,
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(reinstallHelperProvider).uninstallSelf();
    } on ReinstallException catch (e) {
      if (mounted) tpToast(context, e.message, kind: TpToastKind.error);
    }
  }

  void _start() {
    final apk = _apk;
    if (apk == null) {
      _openPage();
      return;
    }
    _sub?.cancel();
    setState(() => _state = OtaUpdateState.downloading(0));
    _sub = ref
        .read(autoUpdaterProvider)
        .downloadAndInstall(apk.browserDownloadUrl,
            destinationFilename:
                'thaipromptadmin-${widget.result.release!.tagName}.apk')
        .listen((s) {
      if (mounted) setState(() => _state = s);
    }, onError: (_) {
      if (mounted) {
        setState(() => _state =
            OtaUpdateState.error('ดาวน์โหลดไม่สำเร็จ ลองใหม่อีกครั้ง'));
      }
    }, onDone: () {
      // ปลั๊กอินปิด stream หลังเปิดตัวติดตั้งของ Android — ปลดปุ่มไม่ให้ค้างหมุนตลอดไป
      if (!mounted) return;
      final cur = _state;
      if (cur == null || cur.isDownloading || cur.isInstalling) {
        setState(() => _state = cur != null && cur.isInstalling
            ? OtaUpdateState.handedOff()
            : OtaUpdateState.error('ดาวน์โหลดไม่สำเร็จ ลองใหม่อีกครั้ง'));
      }
    });
  }

  Future<void> _openPage() async {
    final url = Uri.tryParse(widget.result.release!.htmlUrl);
    if (url != null) await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.tp;
    final r = widget.result.release!;
    final s = _state;
    final reinstall = _needsReinstall;
    final reBusy = _reKind == _ReKind.downloading;
    final busy = (s != null && !s.isError && !s.isHandedOff) || reBusy;
    final failedOrDone = s != null && (s.isError || s.isHandedOff);
    final notes = r.body.trim().isEmpty
        ? 'ปรับปรุงประสิทธิภาพและแก้ไขข้อผิดพลาด'
        : _cleanNotes(r.body);

    return ListView(
        controller: widget.scroll,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          const Center(child: Tp3D(TpArt.settings, size: 96)),
          const SizedBox(height: 10),
          Center(
              child: Text('มีเวอร์ชันใหม่',
                  style: TpType.title(22, p.textStrong))),
          const SizedBox(height: 4),
          Center(
            child: Text(
                '${widget.result.current.label} → ${widget.result.latest?.label ?? r.tagName}',
                style: TpType.money(15, p.goldText, w: FontWeight.w600)),
          ),
          if (r.publishedAt != null)
            Center(
                child: Text(
                    'ออกเมื่อ ${TpFmt.dateTime(r.publishedAt!.toLocal())}',
                    style: TpType.body(12.5, p.muted))),
          const SizedBox(height: 16),
          TpCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('มีอะไรใหม่', style: TpType.h(14.5, p.textStrong)),
              const SizedBox(height: 6),
              Text(notes, style: TpType.body(13.5, p.text, height: 1.55)),
            ]),
          ),
          const SizedBox(height: 16),
          if (reinstall)
            ..._reinstallSection(p)
          else ...[
            if (busy && s != null) ...[
              Row(children: [
                Text(
                    s.isInstalling ? 'กำลังเปิดตัวติดตั้ง…' : 'กำลังดาวน์โหลด',
                    style: TpType.body(13, p.muted)),
                const Spacer(),
                Text('${s.progress}%', style: TpType.money(13, p.goldText)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                    value: s.progress / 100,
                    minHeight: 8,
                    backgroundColor: p.inset),
              ),
              const SizedBox(height: 16),
            ],
            if (s != null && s.isError) ...[
              Text(s.error ?? 'เกิดข้อผิดพลาด',
                  style: TpType.body(13, p.danger, w: FontWeight.w500)),
              const SizedBox(height: 12),
            ],
            if (s != null && s.isHandedOff) ...[
              Text(
                  'เปิดหน้าติดตั้งของ Android แล้ว — กด "ติดตั้ง" แล้วแอปจะปิดตัวเอง '
                  'ให้เปิดแอปใหม่อีกครั้ง\nถ้าขึ้นว่า "ไม่ได้ติดตั้งแอป" แปลว่าลายเซ็นไม่ตรงกับตัวที่ลงอยู่ '
                  'ให้ถอนแอปเดิมแล้วติดตั้งจากหน้าดาวน์โหลด',
                  style: TpType.body(13, p.muted, height: 1.5)),
              const SizedBox(height: 12),
            ],
            TpButton(
              busy
                  ? 'กำลังอัปเดต…'
                  : (failedOrDone ? 'ลองอีกครั้ง' : 'อัปเดตเดี๋ยวนี้'),
              icon: PhosphorIconsBold.downloadSimple,
              loading: busy,
              // รอผลตรวจลายเซ็นก่อน (เสี้ยววินาที) กันกดแล้วไปทางที่พังแน่ ๆ
              onPressed: busy || _signer == null ? null : _start,
            ),
            if (failedOrDone) ...[
              const SizedBox(height: 8),
              TpButton.ghost('เปิดหน้าดาวน์โหลด', onPressed: _openPage),
            ],
          ],
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TpButton.ghost('ข้ามเวอร์ชันนี้',
                  onPressed: busy
                      ? null
                      : () async {
                          await UpdateChecker.skipVersion(r.tagName);
                          if (context.mounted) Navigator.pop(context);
                        }),
            ),
            Expanded(
                child: TpButton.ghost('ไว้ทีหลัง',
                    onPressed: busy ? null : () => Navigator.pop(context))),
          ]),
          if (_apk != null)
            Center(
                child: Text('${_apk!.name} · ${_apk!.sizeMb} MB',
                    style: TpType.body(11.5, p.faint))),
        ]);
  }

  /// ทาง "ถอนก่อนแล้วลงใหม่" — Android ไม่ให้แอปถอนตัวเองเงียบ ๆ
  /// ทำให้ได้มากสุดคือเตรียมไฟล์ไว้ใน Download แล้วพาไปหน้าถอน (เหลือ 3 แตะ)
  List<Widget> _reinstallSection(TpPalette p) {
    final file = _reFile ?? _apk?.name ?? 'thaipromptadmin-….apk';
    return [
      TpCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(PhosphorIconsFill.warningCircle, size: 18, color: p.danger),
            const SizedBox(width: 6),
            Text('ต้องถอนแอปเดิมก่อนหนึ่งครั้ง',
                style: TpType.h(14.5, p.textStrong)),
          ]),
          const SizedBox(height: 6),
          Text(
              'ตัวที่ลงอยู่เซ็นด้วยคีย์คนละชุดกับเวอร์ชันบน GitHub (มักเป็นบิลด์ทดสอบจากคอม) '
              'Android จึงไม่ยอมให้ติดตั้งทับ — แอปจะเตรียมไฟล์ไว้ให้ แล้วพาไปหน้าถอนแอป '
              'ครั้งต่อ ๆ ไปอัปเดตในแอปได้ตามปกติ',
              style: TpType.body(13, p.text, height: 1.5)),
          const SizedBox(height: 10),
          Text(
              '1. ดาวน์โหลดไฟล์ไว้ที่ Download\n'
              '2. ถอนแอปเดิม (แอปจะปิด)\n'
              '3. เปิดแอป "ไฟล์" → Download → แตะ $file → ติดตั้ง',
              style: TpType.body(12.5, p.muted, height: 1.6)),
        ]),
      ),
      const SizedBox(height: 14),
      if (_reKind == _ReKind.downloading) ...[
        Row(children: [
          Text('กำลังดาวน์โหลดไว้ที่ Download',
              style: TpType.body(13, p.muted)),
          const Spacer(),
          Text(_rePct < 0 ? '…' : '$_rePct%',
              style: TpType.money(13, p.goldText)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
              value: _rePct < 0 ? null : _rePct / 100,
              minHeight: 8,
              backgroundColor: p.inset),
        ),
        const SizedBox(height: 12),
        TpButton.ghost('ยกเลิก', onPressed: _cancelReinstall),
      ] else if (_reKind == _ReKind.saved) ...[
        Row(children: [
          Icon(PhosphorIconsFill.checkCircle,
              size: 18, color: const Color(0xFF3DDC84)),
          const SizedBox(width: 6),
          Expanded(
            child: Text('บันทึกไว้ที่ Download/$file แล้ว',
                style: TpType.body(13, p.text, w: FontWeight.w500)),
          ),
        ]),
        const SizedBox(height: 12),
        TpButton.danger('ถอนแอปเดิมเดี๋ยวนี้',
            icon: PhosphorIconsBold.trash, onPressed: _uninstall),
      ] else ...[
        if (_reKind == _ReKind.error) ...[
          Text(_reError ?? 'เกิดข้อผิดพลาด',
              style: TpType.body(13, p.danger, w: FontWeight.w500)),
          const SizedBox(height: 12),
        ],
        TpButton(
          _reKind == _ReKind.error
              ? 'ลองอีกครั้ง'
              : 'ดาวน์โหลดแล้วเตรียมถอนแอป',
          icon: PhosphorIconsBold.downloadSimple,
          onPressed: _startReinstall,
        ),
        if (_reKind == _ReKind.error) ...[
          const SizedBox(height: 8),
          TpButton.ghost('เปิดหน้าดาวน์โหลด', onPressed: _openPage),
        ],
      ],
    ];
  }

  /// ตัดหัวข้อ markdown/ลิงก์ยาวของ GitHub ออก ให้อ่านง่ายบนมือถือ
  String _cleanNotes(String body) {
    final lines = body
        .split('\n')
        .map((l) => l.trim())
        .where((l) =>
            l.isNotEmpty &&
            !l.startsWith('**Full Changelog') &&
            !l.startsWith('<!--'))
        .map((l) => l
            .replaceAll(RegExp(r'^#+\s*'), '')
            .replaceAll('**', '')
            .replaceAll(RegExp(r'https?://\S+'), ''))
        .take(14)
        .toList();
    return lines.join('\n');
  }
}
