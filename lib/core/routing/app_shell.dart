import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../features/chat/data/chat_repository.dart';
import '../../features/home/data/ops_repository.dart';
import '../../shared/ui/tp.dart';

/// โครงหลัก 5 แท็บ + รีเฟรชสรุปงานทุก 30 วินาทีขณะแอปอยู่หน้าจอ (badge บนแท็บจึงสดเสมอ)
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with WidgetsBindingObserver {
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      ref.invalidate(opsSummaryProvider);
      ref.invalidate(liveConversationsProvider);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(opsSummaryProvider);
      ref.invalidate(liveConversationsProvider);
      _startPolling();
    } else if (state == AppLifecycleState.paused) {
      _poll?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(opsSummaryProvider).valueOrNull;
    return Scaffold(
      extendBody: true,
      body: widget.shell,
      bottomNavigationBar: TpTabBar(
        index: widget.shell.currentIndex,
        onTap: (i) => widget.shell.goBranch(i, initialLocation: i == widget.shell.currentIndex),
        items: [
          const TpTabItem('ภาพรวม', PhosphorIconsRegular.house, PhosphorIconsFill.house),
          TpTabItem('งานรอทำ', PhosphorIconsRegular.tray, PhosphorIconsFill.tray, badge: s?.workBadge ?? 0),
          TpTabItem('แชท', PhosphorIconsRegular.chatsCircle, PhosphorIconsFill.chatsCircle,
              badge: s?.customerRequests.count ?? 0),
          const TpTabItem('โมดูล', PhosphorIconsRegular.squaresFour, PhosphorIconsFill.squaresFour),
          const TpTabItem('บัญชี', PhosphorIconsRegular.userCircle, PhosphorIconsFill.userCircle),
        ],
      ),
    );
  }
}
