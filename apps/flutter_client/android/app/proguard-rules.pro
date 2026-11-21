# Same rules as the Tauri Android app (docs/android-extractor-validation.md).
# rustls-platform-verifier: called from Rust through JNI.
-keep, includedescriptorclasses class org.rustls.platformverifier.** { *; }
# youtubedl-android unpacks Python/FFmpeg with Commons Compress, whose ZIP
# extra-field classes are created by reflection.
-keep class * implements org.apache.commons.compress.archivers.zip.ZipExtraField { *; }
