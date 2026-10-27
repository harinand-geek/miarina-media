# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.
#
# For more details, see
#   http://developer.android.com/guide/developing/tools/proguard.html

# If your project uses WebView with JS, uncomment the following
# and specify the fully qualified class name to the JavaScript interface
# class:
#-keepclassmembers class fqcn.of.javascript.interface.for.webview {
#   public *;
#}

# Uncomment this to preserve the line number information for
# debugging stack traces.
#-keepattributes SourceFile,LineNumberTable

# If you keep the line number information, uncomment this to
# hide the original source file name.
#-renamesourcefileattribute SourceFile
# rustls-platform-verifier is reached through JNI only.
-keep, includedescriptorclasses class org.rustls.platformverifier.** { *; }

# Commons Compress registers ZIP extra fields reflectively while unpacking
# Python/FFmpeg. R8 otherwise makes these classes abstract in release builds.
-keep class * implements org.apache.commons.compress.archivers.zip.ZipExtraField { *; }
