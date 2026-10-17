import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:thaipromptadmin/core/api/api_client.dart';
import 'package:thaipromptadmin/core/api/paged.dart';
import 'package:thaipromptadmin/features/work/data/work_repository.dart';
import 'package:thaipromptadmin/features/work/ui/quick_bills_screen.dart';
import 'package:thaipromptadmin/shared/ui/tp.dart';

class _FakeRepo extends WorkRepository {
  _FakeRepo(this.data) : super(ApiClient(baseUrl: 'http://127.0.0.1:9'));
  final List<FortuneBill> data;
  int markCalls = 0;
  int statsCalls = 0;

  @override
  Future<Paged<FortuneBill>> bills(BillBucket bucket,
      {int page = 1, int? perPage, String? search}) async {
    final items = data.where((b) => b.status == bucket.key).toList();
    return Paged(
        items: items,
        page: 1,
        lastPage: 1,
        total: items.length,
        perPage: perPage ?? 20);
  }

  @override
  Future<BillStats> billStats() async {
    statsCalls++;
    final c = <String, int>{};
    for (final b in data) {
      c[b.status] = (c[b.status] ?? 0) + 1;
    }
    return BillStats(counts: c);
  }

  @override
  Future<String?> markPaid(int readingId,
      {required double amount, String? note}) async {
    markCalls++;
    data.removeWhere((b) => b.id == readingId);
    return 'มาร์คจ่ายเรียบร้อย';
  }
}

FortuneBill _bill(int id, String status, String name) => FortuneBill.fromJson({
      'id': id,
      'bill_number': 'R$id',
      'status': status,
      'customer_name': name,
      'amount_thb': 99,
      'created_at':
          DateTime.now().subtract(Duration(minutes: id)).toIso8601String(),
      'actions': {'can_mark_paid': true},
    });

Future<void> _pump(WidgetTester tester, _FakeRepo repo) async {
  await tester.binding.setSurfaceSize(const Size(430, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(ProviderScope(
    overrides: [workRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
      theme: buildTpTheme(TpPalette.midnight),
      home: const QuickBillsScreen(),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('ไม่มีบิลค้าง → empty state ไม่ใช่จอว่าง', (tester) async {
    await _pump(tester, _FakeRepo([]));
    expect(find.text('ไม่มีบิลค้างจ่าย'), findsWidgets);
    expect(find.byType(TpEmpty), findsOneWidget);
  });

  testWidgets('เลื่อนอนุมัติ → บิลหาย ตัวเลขลด ไม่มีโครงกระพริบเต็มจอ',
      (tester) async {
    final repo = _FakeRepo([
      _bill(1, 'unpaid', 'ลูกค้าเอ'),
      _bill(2, 'awaiting', 'ลูกค้าบี'),
    ]);
    await _pump(tester, repo);
    expect(find.text('ลูกค้าเอ'), findsOneWidget);
    expect(find.text('ลูกค้าบี'), findsOneWidget);
    expect(find.text('ค้างจ่าย 2 บิล · ใหม่สุดก่อน'), findsOneWidget);
    final statsBefore = repo.statsCalls;

    // ลากตัวเลื่อนของบิลใบแรก (ใหม่สุด = id 1) จนสุด
    final knob = find.byIcon(PhosphorIconsBold.arrowRight).first;
    await tester.drag(knob, const Offset(600, 0));
    await tester.pump();
    expect(find.byType(TpSkeletonList), findsNothing);
    await tester.pump(const Duration(milliseconds: 50));

    expect(repo.markCalls, 1);
    expect(find.text('ลูกค้าเอ'), findsNothing);
    expect(find.text('ลูกค้าบี'), findsOneWidget);
    expect(find.text('ค้างจ่าย 1 บิล · ใหม่สุดก่อน'), findsOneWidget);
    expect(find.byType(TpSkeletonList), findsNothing);
    expect(repo.statsCalls, greaterThan(statsBefore));

    // ปล่อยให้ toast หมดเวลา (ไม่ให้ timer ค้างตอนจบเทสต์)
    await tester.pump(const Duration(seconds: 5));
  });
}
