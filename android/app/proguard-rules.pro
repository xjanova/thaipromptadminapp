# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }

# Google Play Core — ใช้โดย Flutter deferred components
# เราไม่ใช้ deferred components แต่ Flutter อ้างถึงคลาสเหล่านี้
# ต้อง dontwarn เพื่อให้ R8 minify build ผ่าน
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
-keep interface com.google.android.play.core.** { *; }

# Firebase / Google Play Services (ถ้าใช้ในอนาคต)
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Keep Kotlin Coroutines
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keepclassmembers class kotlinx.coroutines.flow.** { *; }
