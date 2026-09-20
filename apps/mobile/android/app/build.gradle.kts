plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")

    // NOTE: com.google.gms.google-services is deliberately NOT applied.
    // Applying it would make google-services.json a hard build requirement,
    // and this app is designed to build and run without any Firebase setup —
    // the manager phone falls back to polling for alerts. Add the plugin only
    // once a real google-services.json is committed or supplied by CI.
}

android {
    namespace = "kr.ainuri.beehive.beehive_guard"

    // Pinned rather than taking flutter.compileSdkVersion so that CI installs
    // exactly this platform. It must be >= the highest compileSdk any plugin
    // asks for; today that is 36 (record_android, flutter_local_notifications).
    // Keep in sync with ANDROID_COMPILE_SDK in
    // .github/workflows/android-build.yml, and only raise it to a level that
    // is actually published in the stable SDK channel — API 37 is not, which
    // is why permission_handler is pinned to 12.x in pubspec.yaml.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications uses java.time APIs that do not exist on
        // older Android versions, and declares in its AAR metadata that the
        // consuming app must desugar them. Without this the build fails at
        // :app:checkDebugAarMetadata with "requires core library desugaring
        // to be enabled for :app".
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "kr.ainuri.beehive.beehive_guard"
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

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // Required by isCoreLibraryDesugaringEnabled above. The version is the one
    // flutter_local_notifications itself builds against (see that plugin's
    // android/build.gradle), so keep the two in step when upgrading it.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
