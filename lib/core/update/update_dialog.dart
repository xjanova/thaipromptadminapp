import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/ui/tp.dart';
import 'auto_updater.dart';
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

class _UpdateSheetState extends ConsumerState<_UpdateSheet> {
  StreamSubscription<OtaUpdateState>? _sub;
  OtaUpdateState? _state;
  GitHubAsset? _apk;

  @override
  void initState() {
    super.initState();
    pickApkForDevice(widget.result.release!).then((a) {
      if (mounted) setState(() => _apk = a);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
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
    final busy = s != null && !s.isError;
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
          if (s != null && !s.isError) ...[
            Row(children: [
              Text(s.isInstalling ? 'กำลังเปิดตัวติดตั้ง…' : 'กำลังดาวน์โหลด',
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
          TpButton(
            busy
                ? 'กำลังอัปเดต…'
                : (s?.isError == true ? 'ลองอีกครั้ง' : 'อัปเดตเดี๋ยวนี้'),
            icon: PhosphorIconsBold.downloadSimple,
            loading: busy,
            onPressed: busy ? null : _start,
          ),
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
