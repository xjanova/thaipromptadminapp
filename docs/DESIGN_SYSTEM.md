# ไทยพร้อม แอดมิน — ระบบดีไซน์ (v3 · 2026-10-06)

เจ้าของเลือก **แบบ A "มิดไนท์โกลด์" เป็นหลัก + สลับเป็นแบบ B "รอยัลงาช้าง" ได้** (หน้าบัญชี)
เป้าหมาย: แอปแอดมินระดับพรีเมียม ใช้ข้อมูลจริงทุกหน้า — เข้าชุดกับเว็บธีมโนวาและแอปลูกค้า Thai Prompt APP (กรมท่า + ทอง + ลายกนก)

## กติกาเหล็ก

1. **import ชุด UI ไฟล์เดียว** `import '../../../shared/ui/tp.dart';` — สีอ่านจาก `context.tp` เท่านั้น ห้ามพิมพ์ hex ในหน้าจอ
   (ยกเว้นของที่มืดเสมอทั้งสองโหมด เช่น การ์ดฮีโร่ `TpHeroCard` ใช้ค่าคงที่ `TpPalette.hero*`)
2. **ทุกหน้าต้องสวยทั้งสองโหมด** — ทดสอบด้วยการสลับธีมในหน้าบัญชี
3. **ข้อความผู้ใช้เห็นเป็นภาษาไทยทั้งหมด** · คอมเมนต์โค้ดภาษาไทย · **ห้ามอีโมจิเป็นไอคอน** (ใช้ Phosphor หรือภาพ 3D)
   ข้อมูลจากเซิร์ฟเวอร์ที่มีอีโมจิ (เช่น `purpose_label`) ให้ตัดอีโมจิออกก่อนแสดง
4. **ห้ามโชว์ error ดิบ** (`Exception:` / ข้อความอังกฤษจาก backend) — ใช้ `tpErrorText(e)` เสมอ
5. **ห้ามสปินเนอร์เต็มจอตอนรีเฟรช** — ใช้ `TpAsync` (โหลดครั้งแรก = โครงกระพริบ, รีเฟรช = คงข้อมูลเดิม)
6. **รายการเงิน/ย้อนกลับไม่ได้**: ใช้ `TpSlideToConfirm` (อนุมัติ/ยืนยันยอด) หรือ `tpConfirm(..., danger: true)` / `tpPrompt` (ต้องใส่เหตุผล)
7. **กันกดซ้ำ**: ปุ่มที่ยิง API ต้องมีสถานะ `loading` · หลัง `await` ต้อง `if (!mounted) return;` ก่อน `setState`/ใช้ `context`
8. **dispose ทุกอย่าง**: Timer / StreamSubscription / TextEditingController / AnimationController
9. **ห้ามใส่ letterSpacing กับข้อความไทย**
10. ตัวเลขเงิน/จำนวน → `TpType.money()` (tabular) + `TpFmt.baht()` / `TpFmt.count()` · เวลา → `TpFmt.ago()/dateTime()/longDate()`

## โครงหน้า

```dart
return TpPage(
  title: 'กระเป๋าเงิน',          // ชื่อหน้า (ฟอนต์ serif บนหัวรอยัล)
  subtitle: 'สมาชิก 8,214 กระเป๋า',
  back: true,                   // หน้าย่อย (ไม่มีแท็บบาร์) — ใส่ bottomSpace: 32
  bottomSpace: 32,
  actions: [TpGlassButton(icon: PhosphorIconsRegular.magnifyingGlass, onTap: ...)],
  headerBottom: TpChips<Filter>(onHeader: true, padding: EdgeInsets.zero, ...), // ชิปบนหัว (ถ้ามี)
  onRefresh: () async { ref.invalidate(xProvider); },
  slivers: [ ... ],             // SliverToBoxAdapter / SliverList / TpPagedSliver
);
```
หน้ารายละเอียดใช้ **แผ่นเลื่อนล่าง** `tpShowSheet(context, builder: (ctx, scroll) => ...)` + `TpBottomBar` สำหรับปุ่มติดล่าง

## ชิ้นส่วน (shared/ui)

| ชิ้น | ใช้เมื่อ |
|---|---|
| `TpCard(child, onTap?, accent?, goldBorder?)` | การ์ดมาตรฐาน · `accent` = แถบสีซ้ายบอกสถานะ |
| `TpHeroCard` + `TpFoilText` + `TpAreaChart` | ตัวเลขสำคัญที่สุดของหน้า (การ์ดน้ำเงินเข้ม ทองฟอยล์) — หน้าละ 1 ใบ |
| `TpGroup([TpRow(...), ...])` | รายการในการ์ดเดียว คั่นเส้น · `TpRow(art: TpArt.x / icon:, title, subtitle, trailing, onTap)` |
| `TpSwitchRow` | สวิตช์เปิด/ปิด (มี `busy`) |
| `TpSection('หัวข้อ', action: 'ดูทั้งหมด', onAction:)` | หัวข้อส่วน |
| `TpPill(label, tone:, icon:)` · `TpCount(n, tone:)` · `TpBadge(n)` | ป้ายสถานะ / ตัวนับ |
| `TpChips<T>(items: [TpChipItem(v, 'ป้าย', count: n)], value:, onChanged:)` | ตัวกรอง |
| `TpAvatar(name:, platform:)` | อวาตาร์ตัวอักษร + ป้ายแพลตฟอร์ม (facebook/line/telegram) |
| `TpButton` / `.outline` / `.danger` / `.ghost` | ปุ่ม · ปุ่มยืนยันหลัก = ทอง (ค่าเริ่มต้น) |
| `TpKv(label, value)` | แถวข้อมูลในหน้ารายละเอียด |
| `TpStat` · `TpMeter` | ตัวเลข + คำบรรยาย / แถบโควตา |
| `TpAsync<T>(value:, data:, onRetry:)` | แสดง `AsyncValue` |
| `TpPagedSliver<T>(fetch: (page) => repo.list(page: page), itemBuilder:, reloadKey:, empty:)` | รายการแบ่งหน้า โหลดเพิ่มอัตโนมัติ (เปลี่ยน `reloadKey` = โหลดใหม่ ไม่กระพริบ) |
| `TpEmpty(art:, title:, message:)` · `TpErrorView(error:, onRetry:)` · `TpSkeleton` / `TpSkeletonList` | ว่าง / ผิดพลาด / กำลังโหลด |
| `tpToast(context, msg, kind:)` · `tpConfirm` · `tpPrompt` · `tpShowSheet` | แจ้งผล / ยืนยัน / ถามข้อความ / แผ่นล่าง |
| `TpSlideToConfirm(label:, onConfirmed: () async => bool)` | เลื่อนเพื่อยืนยัน (คืน false = เด้งกลับ) |
| `Tp3D(TpArt.x, size:)` | ภาพ 3D ประจำแบรนด์ (bill, headset, payout, sms, hourglass, shield, ai, members, analytics, broadcast, settings, server, tarot, wallet, store, scooter, emptyDone, emptyInbox, emptyOffline) |

ไอคอนเส้น: `phosphor_flutter` → `PhosphorIconsRegular.x` / `PhosphorIconsFill.x` / `PhosphorIconsBold.x`

## ข้อมูล

- `ApiClient` (`apiClientProvider`) base = `/api/admin` · `get/post/put/delete` คืน `data` ใน envelope แล้ว
- รายการแบ่งหน้า: `Paged.parse(data, Model.fromJson)` อ่านได้ทั้งแบบแบนและแบบ `meta`
- การกระทำที่ backend ตอบ `success:false` + ข้อความไทย → `throw ActionError(message)` (ดู `work_repository.dart`)
- โมเดล: parse แบบทนทาน (`TpFmt.toInt/toDouble/parse`) — ห้าม `as int` ตรง ๆ กับค่าจาก JSON
- **ไม่มีข้อมูลปลอมแล้ว** (ถอด mock mode ทั้งหมด) — ทุกหน้าอ่าน API จริง
- สัญญา API ใหม่: `D:/Code/Thaiprompt-Affiliate/.claude/worktrees/agent-af7e10d9ca234af33/docs/ADMIN_APP_API.md`
  endpoint เดิม: `D:/Code/Thaiprompt-Affiliate/routes/admin_api.php` + `app/Http/Controllers/Api/Admin/**`

## ตัวอย่างที่ทำเสร็จแล้ว (ดูเป็นแบบ)

`features/home/ui/home_screen.dart` · `features/work/ui/work_screen.dart` + `bill_widgets.dart` ·
`features/chat/ui/*` · `features/modules/ui/modules_screen.dart` · `features/settings/ui/account_screen.dart`
