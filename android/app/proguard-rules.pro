# Flutter Wrapper & Engine
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class com.example.expense_tracker.MainActivity { *; }
-dontwarn io.flutter.embedding.**

# Preserve generic signatures, annotations, and line numbers for debugging/stack traces
-keepattributes SourceFile,LineNumberTable,*Annotation*,Signature,InnerClasses,EnclosingMethod

# Keep @Keep annotated classes and members
-keep class androidx.annotation.Keep
-keep @androidx.annotation.Keep class * { *; }
-keepclasseswithmembers class * {
    @androidx.annotation.Keep <methods>;
}
-keepclasseswithmembers class * {
    @androidx.annotation.Keep <fields>;
}
-keepclasseswithmembers class * {
    @androidx.annotation.Keep <init>(...);
}

# FileProvider (used by share_plus and open_file)
-keep class androidx.core.content.FileProvider { *; }
-keep class dev.fluttercommunity.plus.share.** { *; }
-keep class com.crazecoder.openfile.** { *; }

# Dynamic Color (Material You / CorePalette)
-keep class io.material.plugins.dynamic_color.** { *; }
-keep class com.google.android.material.color.** { *; }

# Connectivity Plus & Shared Preferences
-keep class dev.fluttercommunity.plus.connectivity.** { *; }
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class io.flutter.plugins.pathprovider.** { *; }

# Kotlin Coroutines (prevent R8 full-mode stripping of internal service loaders)
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keepclassmembers class kotlinx.coroutines.** {
    volatile <fields>;
}

# Suppress warnings for optional/missing platform classes in R8 full mode
-dontwarn java.lang.invoke.StringConcatFactory
-dontwarn javax.annotation.**
-dontwarn org.codehaus.mojo.animal_sniffer.IgnoreJRERequirement
