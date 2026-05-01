<!-- ── คำอธิบายการเปลี่ยนแปลง ── -->

## สรุป
<!-- 1-3 บรรทัด: ทำอะไร? -->

## ทำไมต้องเปลี่ยน
<!-- บริบท / context -->

## วิธีทดสอบ
- [ ] flutter analyze ผ่าน
- [ ] flutter test ผ่าน
- [ ] ทดสอบบน Android device จริง
- [ ] (ถ้าแตะ UI) screenshot ก่อน-หลัง

---

## 🏷️ Release Label (สำคัญ — กำหนดว่า merge แล้วจะ bump version ระดับไหน)

เลือก **1 label** จาก:

| Label | ผลลัพธ์ | ใช้เมื่อ |
|-------|---------|---------|
| `release:major` | 0.1.0 → **1.0.0** | Breaking change (API/UI หลัก) |
| `release:minor` | 0.1.0 → **0.2.0** | Feature ใหม่ (backward-compatible) |
| `release:patch` | 0.1.0 → **0.1.1** | Bug fix / refactor (default) |
| `release:build` | 0.1.0+1 → 0.1.0+**2** | เพิ่ม build no. อย่างเดียว (rebuild) |
| `release:skip` | ❌ ไม่ bump, ไม่ release | docs/CI/comment-only |

ถ้าไม่ติด label ใดเลย → default `release:patch`

หลัง merge:
1. Workflow `auto-bump-on-merge` bump pubspec อัตโนมัติ
2. Push tag `v<version>` → trigger workflow `release` ให้ build APK + create GitHub Release
3. แอปบนมือถือผู้ใช้ detect ภายใน 6 ชม. → แจ้งเตือนอัปเดท
