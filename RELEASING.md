# Releasing Thaiprompt Admin App

แอปนี้ใช้ **GitHub Releases เป็นช่องทางส่งเวอร์ชัน** + **Auto-update ในตัวแอป**

## 🎯 หลักการ

- `pubspec.yaml` `version: 0.1.0+1` คือ **single source of truth**
- Tag บน GitHub ใช้รูป `v<version>` (เช่น `v0.1.0+1`)
- แอปเช็ค `api.github.com/repos/xjanova/thaipromptadminapp/releases/latest` เมื่อเปิด → ถ้าเวอร์ชันใหม่กว่า → แจ้งให้อัปเดท

## 🚀 วิธีออกเวอร์ชันใหม่

### วิธีที่ 1: ⭐ Auto-bump on PR merge (workflow ทำให้อัตโนมัติ)

**Flow ปกติ — สิ่งที่จะเกิดทุกครั้งที่ merge PR:**

```
PR merge → auto-bump-on-merge.yml (workflow):
  1. อ่าน label "release:*" จาก PR (default = patch)
  2. bump pubspec.yaml ตาม level
  3. commit "chore(release): bump to X.Y.Z [skip ci]"
  4. push tag vX.Y.Z
       ↓
release.yml (triggered by tag):
  5. CI: analyze + test
  6. build APK 4 variants (arm64, armv7, x86_64, universal) + AAB
  7. ใช้ secrets ANDROID_KEYSTORE_* sign APKs
  8. publish GitHub Release พร้อม artifacts + auto-generated notes
       ↓
แอปบนมือถือผู้ใช้ (ภายใน 6 ชม.):
  9. UpdateChecker เช็ค /releases/latest
  10. เห็นเวอร์ชันใหม่ → แจ้งเตือน + ปุ่ม "อัปเดทตอนนี้"
  11. user → download APK → ติดตั้งทับ → upgrade สำเร็จ (signature เดียวกัน)
```

**ติด PR label เพื่อกำหนด bump level:**

| Label | ผลลัพธ์ | เมื่อใด |
|-------|---------|---------|
| `release:major` | 0.1.0 → 1.0.0 | Breaking change |
| `release:minor` | 0.1.0 → 0.2.0 | Feature ใหม่ |
| `release:patch` ⭐ | 0.1.0 → 0.1.1 | Bug fix (default ถ้าไม่ติด) |
| `release:build` | 0.1.0+1 → 0.1.0+2 | Build number only |
| `release:skip` | ไม่ release | docs/CI/refactor only |

> **TIP:** PR template (`.github/PULL_REQUEST_TEMPLATE.md`) จะแสดง checkbox ตัวเลือกเหล่านี้
> ให้ developer เห็นทุกครั้งที่เปิด PR

### วิธีที่ 2: ใช้ GitHub Actions UI (manual override)

1. ไปที่ **Actions** → **Bump version + Tag**
2. กด **Run workflow** → เลือก bump level (patch/minor/major/build)
3. Bot จะ bump pubspec + tag + push → trigger Release workflow
4. ใช้เมื่อต้องการ release โดยไม่มี PR (hotfix etc.)

### วิธีที่ 3: bump + push tag เอง (manual)

```bash
# แก้ pubspec.yaml manually
sed -i -E 's/^version:.*/version: 0.2.0+2/' pubspec.yaml
git commit -am "chore: bump version to 0.2.0+2"
git tag -a v0.2.0+2 -m "Release 0.2.0+2"
git push origin main
git push origin v0.2.0+2
```

Push tag จะ trigger workflow `release.yml` อัตโนมัติ

### วิธีที่ 3: Manual workflow trigger (ใช้กับ tag ที่มีอยู่แล้ว)

Actions → **Release** → Run workflow → ใส่ tag → Run

## 🔑 ตั้งค่า Release Signing (จำเป็นก่อน production)

ตอนนี้ workflow ใช้ **debug signing** ถ้าไม่มี secrets — APK ลงเครื่องได้แต่ติดตั้งทับเวอร์ชันเก่า (ที่ signature ต่าง) ไม่ได้

### สร้าง keystore (ทำครั้งเดียว)

```bash
keytool -genkey -v -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

ตอบคำถาม + ตั้งรหัสผ่าน → ได้ไฟล์ `upload-keystore.jks`

### Encode + เพิ่ม secrets ใน GitHub

```bash
base64 -w 0 upload-keystore.jks > keystore.base64.txt
```

ไปที่ repo → **Settings** → **Secrets and variables** → **Actions** → **New secret** เพิ่ม 4 ตัว:

| Secret | ค่า |
|--------|-----|
| `ANDROID_KEYSTORE_BASE64` | เนื้อหาไฟล์ `keystore.base64.txt` |
| `ANDROID_KEYSTORE_PASSWORD` | รหัสผ่าน keystore |
| `ANDROID_KEY_ALIAS` | `upload` |
| `ANDROID_KEY_PASSWORD` | รหัสผ่าน key (ถ้าเหมือน keystore ใส่เหมือนกัน) |

⚠️ **เก็บ `upload-keystore.jks` + รหัสผ่านไว้ดีๆ** — ถ้าหายจะ update Play Store ไม่ได้อีก

## 📦 สิ่งที่ release.yml build

ทุกครั้งที่ trigger workflow จะได้ artifacts:

| ไฟล์ | สำหรับ |
|------|--------|
| `thaipromptadmin-X.Y.Z-arm64-v8a.apk` | Android 64-bit (เครื่องสมัยใหม่) ⭐ |
| `thaipromptadmin-X.Y.Z-armeabi-v7a.apk` | Android 32-bit (เครื่องเก่า) |
| `thaipromptadmin-X.Y.Z-x86_64.apk` | Emulator / x86 device |
| `thaipromptadmin-X.Y.Z-universal.apk` | ทุก architecture (ขนาดใหญ่กว่า) |
| `thaipromptadmin-X.Y.Z.aab` | Google Play Console |

## 🔄 Auto-update Flow ในแอป

1. แอปเปิด → `UpdateChecker.checkIfShouldPrompt()` (throttle: ทุก 6 ชม.)
2. GET `api.github.com/.../releases/latest`
3. เปรียบเทียบ tag กับ pubspec version ปัจจุบัน
4. ถ้าใหม่กว่า → แสดง dialog พร้อม release notes
5. ผู้ใช้กด:
   - **อัปเดทตอนนี้** → เปิด APK URL ใน browser → ติดตั้งเอง
   - **ภายหลัง** → ปิด dialog (จะถามใหม่ใน 6 ชม.)
   - **ข้ามเวอร์ชันนี้** → จะไม่ถามอีกจนกว่าจะมีเวอร์ชันใหม่กว่า

ผู้ใช้สามารถเช็คเองได้ที่ **Settings → ตรวจสอบอัปเดท**

## 🧪 ทดสอบ workflow ก่อนใช้งานจริง

```bash
# ทดสอบ build apk ในเครื่อง
flutter build apk --release --split-per-abi

# Trigger release workflow ใน GitHub UI:
#   Actions → Release → Run workflow → ใส่ tag (เช่น v0.0.1+0)
```

## 🐛 Troubleshooting

**Q: เพิ่ม secret แล้วแต่ workflow ยังบอกว่า "No keystore secrets set"**
A: เช็คชื่อ secret ให้ตรง — ตัวพิมพ์เล็กใหญ่ก็สำคัญ

**Q: APK build สำเร็จแต่ลงเครื่องไม่ได้ (signature mismatch)**
A: ถ้า user มีเวอร์ชันเก่าที่ signed ด้วย debug key → uninstall ก่อน → ติดตั้งใหม่

**Q: แอปไม่แจ้งเตือน update ทั้งที่มี release ใหม่**
A: เช็ค:
- `pubspec.yaml` version ของแอปปัจจุบัน < tag บน GitHub
- ผู้ใช้ไม่ได้กด "ข้ามเวอร์ชันนี้" — ลบ skip preference ที่ Settings (ฟีเจอร์ในอนาคต)
- ผ่าน throttle 6 ชม. แล้ว — เปิด Settings → ตรวจสอบอัปเดท เพื่อบังคับเช็ค
