# ─────────────────────────────────────────────────────────────────────────────
# Flutter embedding
# ─────────────────────────────────────────────────────────────────────────────
# NOTE: this blanket keep is intentional. It keeps the whole Flutter embedding
# (which is reflection-heavy) but it also keeps the unused deferred-components
# classes, so R8 goes on to resolve their Play Core references. The
# "-dontwarn com.google.android.play.core.**" rule below is what keeps that from
# failing the release build. If you ever remove the blanket keep, keep the
# -dontwarn rule: Flutter's embedding still references Play Core.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Flutter's embedding has optional references to Google Play Core deferred
# components (FlutterPlayStoreSplitApplication, PlayStoreDeferredComponentManager).
# This app ships no dynamic feature modules and its Application class is the
# default FlutterApplication, so those classes are never loaded at runtime and
# Play Core is deliberately not a dependency. Without this rule, R8 full mode
# fails the release build with:
#   ERROR: Missing class com.google.android.play.core.splitcompat.SplitCompatApplication
#   ERROR: Missing class com.google.android.play.core.splitinstall.SplitInstallManager
#   ... Execution failed for task ':app:minifyReleaseWithR8'
# See https://github.com/flutter/flutter/issues/110658
-dontwarn com.google.android.play.core.**

# Prevent R8 from mangling MainActivity
-keep class com.penfight.kolomkhela.MainActivity { *; }

# Google Sign In & Firebase
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# AudioPlayers
-keep class xyz.luan.audioplayers.** { *; }
-dontwarn xyz.luan.audioplayers.**

# Flutter Secure Storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-dontwarn com.it_nomads.fluttersecurestorage.**

# Shared Preferences
-keep class io.flutter.plugins.sharedpreferences.** { *; }
