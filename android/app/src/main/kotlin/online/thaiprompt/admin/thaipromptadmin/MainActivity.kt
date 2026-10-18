package online.thaiprompt.admin.thaipromptadmin

import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.Signature
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest

// FlutterFragmentActivity (instead of FlutterActivity) is required by local_auth
// to use BiometricPrompt for fingerprint/face authentication.
class MainActivity : FlutterFragmentActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "signingSha256s" -> result.success(signingSha256s())
                        "cacheDir" -> result.success(cacheDir.absolutePath)
                        "saveToDownloads" -> {
                            val path = call.argument<String>("path")
                            val name = call.argument<String>("name")
                            if (path.isNullOrEmpty() || name.isNullOrEmpty()) {
                                result.error("args", "path/name required", null)
                            } else {
                                result.success(saveToDownloads(File(path), name))
                            }
                        }
                        "uninstallSelf" -> {
                            uninstallSelf()
                            result.success(true)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("native", e.message ?: e.javaClass.simpleName, null)
                }
            }
    }

    /**
     * SHA-256 (hex ตัวเล็ก) ของใบรับรองที่ใช้เซ็น APK ตัวที่ติดตั้งอยู่ — คืนทุกใบใน lineage
     * ฝั่ง Dart เทียบกับใบของ CI: ไม่ตรง = ติดตั้งทับไม่ได้ (INSTALL_FAILED_UPDATE_INCOMPATIBLE)
     * ต้องถอนก่อน
     */
    private fun signingSha256s(): List<String> {
        val pm = packageManager
        val sigs: Array<Signature>? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val info = pm.getPackageInfo(packageName, PackageManager.GET_SIGNING_CERTIFICATES)
            val si = info.signingInfo ?: return emptyList()
            if (si.hasMultipleSigners()) si.apkContentsSigners else si.signingCertificateHistory
        } else {
            @Suppress("DEPRECATION")
            pm.getPackageInfo(packageName, PackageManager.GET_SIGNATURES).signatures
        }
        val md = MessageDigest.getInstance("SHA-256")
        return (sigs ?: emptyArray()).map { sig ->
            md.digest(sig.toByteArray()).joinToString("") { "%02x".format(it) }
        }
    }

    /**
     * คัดลอก APK ไปโฟลเดอร์ Download สาธารณะ — ไฟล์ตรงนี้ "อยู่รอด" หลังถอนแอป
     * (ไฟล์ใน files/ota_update ของแอปจะหายไปพร้อมแอป) คืนชื่อไฟล์ที่ได้จริง
     * Android 10+ ผ่าน MediaStore ไม่ต้องขอสิทธิ์ · ต่ำกว่านั้นเขียนตรง (ต้อง WRITE_EXTERNAL_STORAGE)
     */
    private fun saveToDownloads(src: File, name: String): String {
        if (!src.exists()) throw IllegalStateException("source apk missing")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = contentResolver
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, name)
                put(MediaStore.Downloads.MIME_TYPE, "application/vnd.android.package-archive")
                put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("MediaStore insert failed")
            try {
                val out = resolver.openOutputStream(uri)
                    ?: throw IllegalStateException("cannot open output stream")
                out.use { o -> src.inputStream().use { it.copyTo(o) } }
                values.clear()
                values.put(MediaStore.Downloads.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
            } catch (e: Exception) {
                resolver.delete(uri, null, null)
                throw e
            }
            // MediaStore อาจเปลี่ยนชื่อเป็น "name (1).apk" ถ้าชื่อซ้ำ — อ่านชื่อจริงกลับมา
            resolver.query(uri, arrayOf(MediaStore.Downloads.DISPLAY_NAME), null, null, null)
                ?.use { c -> if (c.moveToFirst()) return c.getString(0) ?: name }
            return name
        } else {
            val dir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            if (!dir.exists() && !dir.mkdirs()) throw IllegalStateException("cannot create Download dir")
            src.copyTo(File(dir, name), overwrite = true)
            return name
        }
    }

    /** เปิดหน้าถอนการติดตั้งของ Android สำหรับแอปนี้เอง — ระบบจะถามผู้ใช้ยืนยันเสมอ */
    private fun uninstallSelf() {
        val intent = Intent(Intent.ACTION_DELETE, Uri.parse("package:$packageName"))
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }

    companion object {
        const val CHANNEL = "online.thaiprompt.admin/installer"
    }
}
