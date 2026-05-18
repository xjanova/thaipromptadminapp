package online.thaiprompt.admin.thaipromptadmin

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (instead of FlutterActivity) is required by local_auth
// to use BiometricPrompt for fingerprint/face authentication.
class MainActivity : FlutterFragmentActivity()
