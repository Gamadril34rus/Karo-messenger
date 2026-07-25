# ─── ЧАРО — Proguard Rules ────────────────────────────────────
# Strip debug symbols, optimise release builds

-optimizationpasses 5
-dontusemixedcaseclassnames
-dontskipnonpubliclibraryclasses
-dontpreverify
-verbose

-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# Flutter engine
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# Kotlin
-dontwarn kotlin.**
-keep class kotlin.Metadata { *; }
-keepclassmembers class kotlin.Metadata {
    public <methods>;
}

# Signal Protocol
-keep class org.signal.** { *; }
-keep class signal_protocol_dart.** { *; }
-dontwarn org.signal.**

# Prisma generated
-keep class com.charo.messenger.** { *; }
-keepclassmembers class com.charo.messenger.** { *; }

# AndroidX / Material
-keep class androidx.** { *; }
-keep interface androidx.** { *; }
-dontwarn androidx.**

# Gson / JSON
-keepattributes Signature
-keepattributes *Annotation*
-keep class sun.misc.Unsafe { *; }
-keep class com.google.gson.** { *; }

# Remove debug logs in release
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}
