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

android {
    namespace = "org.miarina.media"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    // The app name comes from resValue (Miarina Media Bêta).
    buildFeatures {
        resValues = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Beta installed next to the published 0.1.x app (org.miarina.media),
        // which it never replaces nor reads (owner's choice, 2026-11-21).
        applicationId = "org.miarina.media.beta"
        resValue("string", "app_name", "Miarina Media Bêta")
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
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
        }
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
}
