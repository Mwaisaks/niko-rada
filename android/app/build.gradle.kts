plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.nikorada.niko_rada"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.nikorada.niko_rada"
        // 26+: required by firebase-ai-ondevice (and by flutter_gemma .litertlm until Phase 1 removes it)
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // .litertlm FFI engine only ships arm64-v8a prebuilt
        ndk { abiFilters += listOf("arm64-v8a") }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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

// Firebase config is NOT committed (public repo). If android/app/google-services.json is present, apply the
// google-services plugin so FirebaseApp auto-initialises. Without it the app still builds; the hybrid spike screen
// then reports "Firebase not configured" instead of crashing. See docs/SPIKE_CHECKLIST.md.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
} else {
    logger.warn("niko_rada: android/app/google-services.json not found; building without Firebase config.")
}

dependencies {
    // Firebase AI Logic hybrid inference (Android). Versions per
    // https://firebase.google.com/docs/ai-logic/hybrid/android/get-started (on-device SDK is not in the BoM yet).
    implementation("com.google.firebase:firebase-ai:18.2.0")
    implementation("com.google.firebase:firebase-ai-ondevice:16.0.0-beta08")
    // App Check debug provider: fine for the hackathon submission; swap for Play Integrity before any real release.
    implementation("com.google.firebase:firebase-appcheck-debug:20.1.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")
}
