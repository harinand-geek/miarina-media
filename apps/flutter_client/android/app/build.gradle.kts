import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing: the key of the published Android app (0.1.x), read from
// the Tauri project's keystore.properties (git-ignored, never copied here).
// Without it the release APK is signed with the debug key and not published.
val keystoreProperties = Properties().apply {
    val propFile = rootProject.file("../../client/src-tauri/gen/android/keystore.properties")
    if (propFile.exists()) propFile.inputStream().use { load(it) }
}

// Stable (B1): `flutter build apk --android-project-arg=mm-stable=true`
// makes the app that replaces the published 0.1.x (org.miarina.media, same
// key, version code above 0.1.11's 1011) and reuses its data. Without it:
// the separate beta, org.miarina.media.beta.
val stable = (project.findProperty("mm-stable") as String?) == "true"

// ABIs of the `flutter build --target-platform` list (Flutter's property).
val targetAbis: List<String> = run {
    val names = mapOf(
        "android-arm64" to "arm64-v8a",
        "android-x64" to "x86_64",
        "android-arm" to "armeabi-v7a",
    )
    (project.findProperty("target-platform") as String?)
        ?.split(",")
        ?.mapNotNull { names[it.trim()] }
        ?.takeIf { it.isNotEmpty() }
        ?: listOf("arm64-v8a", "x86_64")
}

android {
    namespace = "org.miarina.media"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    // The app name comes from resValue (Miarina Media, or Miarina Media Bêta).
    buildFeatures {
        resValues = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Beta installed next to the published 0.1.x app (org.miarina.media),
        // which it never replaces nor reads (owner's choice, 2026-11-21);
        // the stable build is that app's next version.
        applicationId = if (stable) "org.miarina.media" else "org.miarina.media.beta"
        resValue("string", "app_name", if (stable) "Miarina Media" else "Miarina Media Bêta")
        // Native libraries (youtubedl-android ships Python and FFmpeg for four
        // ABIs): only those Flutter builds for (--target-platform), so the
        // published APK holds arm64 only.
        ndk { abiFilters += targetAbis }
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = if (stable) 2000 + flutter.versionCode else flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystoreProperties.containsKey("storeFile")) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    // Android runs only APK-owned native binaries (Python, FFmpeg, QuickJS of
    // youtubedl-android): they must be extracted to the native library folder.
    packaging {
        jniLibs.useLegacyPackaging = true
        // Zip archives named .so (youtubedl-android): not ELF, nothing to strip.
        jniLibs.keepDebugSymbols += setOf("**/libpython.zip.so", "**/libffmpeg.zip.so")
        // Flutter adds 32-bit ARM to the ABI filter by itself: the ABIs not
        // asked for are left out of the APK here.
        jniLibs.excludes += listOf("arm64-v8a", "x86_64", "armeabi-v7a", "x86")
            .filterNot { it in targetAbis }
            .map { "lib/$it/**" }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Same Media3 release as the shipped Tauri Android app (validated on device).
    implementation("androidx.media3:media3-exoplayer:1.11.1")
    implementation("androidx.media3:media3-session:1.11.1")
    // Same release as the shipped Tauri app (design_handoff_splash).
    implementation("androidx.core:core-splashscreen:1.2.0")
    // Obtenir (bêta 2): the extractor and FFmpeg of the Tauri app, same
    // versions; the pinned yt-dlp 2026.08.19 is res/raw/ytdlp.
    implementation("io.github.junkfood02.youtubedl-android:library:0.18.1")
    implementation("io.github.junkfood02.youtubedl-android:ffmpeg:0.18.1")
    // Must match rustls-platform-verifier-android in Cargo.lock (0.2.0).
    implementation("org.rustls:rustls-platform-verifier:0.2.0")
}
