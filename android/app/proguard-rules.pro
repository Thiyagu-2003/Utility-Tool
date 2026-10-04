# ProGuard / R8 rules for ML Kit and ToolBox Pro
-dontwarn com.google.mlkit.**
-dontwarn com.google_mlkit_text_recognition.**

-keep class com.google.mlkit.** { *; }
-keep class com.google_mlkit_text_recognition.** { *; }
