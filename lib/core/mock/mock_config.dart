/// Mock-mode flag — เปิด/ปิดผ่าน `--dart-define=MOCK_MODE=...`
///
/// Default **true** เพื่อให้แอพรันได้ตามคอนเซปโดยไม่ต้องรอ backend Laravel
/// (admin JSON API ยังไม่มี — backend มีแค่ /api/v1/login ตามที่บันทึก)
///
/// เมื่อ backend admin endpoints พร้อม → build ด้วย `--dart-define=MOCK_MODE=false`
const bool kMockMode = bool.fromEnvironment('MOCK_MODE', defaultValue: true);

/// หน่วงเวลาเล็กน้อยเลียนแบบ network latency เพื่อให้เห็น loading skeleton/spinner
/// ของจริง — ไม่งั้นทุกอย่างจะ snap เร็วเกินไปจน UX ดูแปลก
Future<T> mockDelay<T>(T value, {Duration delay = const Duration(milliseconds: 350)}) async {
  await Future.delayed(delay);
  return value;
}
