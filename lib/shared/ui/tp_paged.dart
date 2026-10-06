import 'package:flutter/material.dart';

import '../../core/api/paged.dart';
import 'tp_feedback.dart';
import 'tp_kit.dart';

/// รายการแบบแบ่งหน้า (sliver) — โหลดหน้าถัดไปเองเมื่อเลื่อนถึงท้าย
///
/// เปลี่ยน [reloadKey] (เช่น ตัวกรอง/คำค้น/ตัวนับรีเฟรช) → โหลดใหม่ตั้งแต่หน้าแรก
/// ระหว่างรีโหลดจะคงรายการเดิมไว้ (ไม่กระพริบ) จนข้อมูลใหม่มาถึง
class TpPagedSliver<T> extends StatefulWidget {
  const TpPagedSliver({
    super.key,
    required this.fetch,
    required this.itemBuilder,
    this.reloadKey,
    this.empty,
    this.gap = 10,
    this.skeletonCount = 5,
    this.onLoaded,
  });

  final Future<Paged<T>> Function(int page) fetch;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Object? reloadKey;
  final Widget? empty;
  final double gap;
  final int skeletonCount;

  /// แจ้งผลหน้าแรก (เช่น เอา total ไปแสดงบนหัว)
  final ValueChanged<Paged<T>>? onLoaded;

  @override
  State<TpPagedSliver<T>> createState() => _TpPagedSliverState<T>();
}

class _TpPagedSliverState<T> extends State<TpPagedSliver<T>> {
  final List<T> _items = [];
  int _page = 0;
  int _lastPage = 1;
  bool _loading = false;
  bool _loadedOnce = false;
  Object? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant TpPagedSliver<T> old) {
    super.didUpdateWidget(old);
    if (old.reloadKey != widget.reloadKey) _reload();
  }

  Future<void> _reload() async {
    final gen = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await widget.fetch(1);
      if (!mounted || gen != _generation) return;
      setState(() {
        _items
          ..clear()
          ..addAll(res.items);
        _page = res.page;
        _lastPage = res.lastPage;
        _loading = false;
        _loadedOnce = true;
      });
      widget.onLoaded?.call(res);
    } catch (e) {
      if (!mounted || gen != _generation) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _page >= _lastPage) return;
    final gen = _generation;
    setState(() => _loading = true);
    try {
      final res = await widget.fetch(_page + 1);
      if (!mounted || gen != _generation) return;
      setState(() {
        _items.addAll(res.items);
        _page = res.page;
        _lastPage = res.lastPage;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || gen != _generation) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loadedOnce) {
      if (_error != null) {
        return SliverToBoxAdapter(
            child: TpErrorView(error: _error, onRetry: _reload, compact: true));
      }
      return SliverToBoxAdapter(
          child: TpSkeletonList(count: widget.skeletonCount));
    }
    if (_items.isEmpty) {
      return SliverToBoxAdapter(
        child: widget.empty ??
            const TpEmpty(
                art: TpArt.emptyInbox, title: 'ไม่มีรายการ', compact: true),
      );
    }
    final hasMore = _page < _lastPage;
    return SliverList.builder(
      itemCount: _items.length + (hasMore || (_error != null) ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= _items.length) {
          if (_error != null) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                  child: TpButton.ghost('โหลดต่อไม่สำเร็จ · ลองใหม่',
                      onPressed: _loadMore)),
            );
          }
          WidgetsBinding.instance.addPostFrameCallback((_) => _loadMore());
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(
                child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.2))),
          );
        }
        return Padding(
          padding: EdgeInsets.only(bottom: widget.gap),
          child: widget.itemBuilder(context, _items[i], i),
        );
      },
    );
  }
}
