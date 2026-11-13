plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// MAJOR.MINOR from pubspec's version (4.3.0+43 → "4.3"), used as the app's
// version name and in the release APK's name.
val appVersion: String = flutter.versionName!!.split(".").take(2).joinToString(".")

android {
    namespace = "com.bliksemit.Invoices"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.bliksemit.Invoices"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        // The version is MAJOR.MINOR (pubspec's 4.3.0 shows as 4.3).
        versionName = appVersion
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// Puts a copy of the release APK next to Flutter's app-release.apk as
// Invoices_<version>.apk (build/app/outputs/flutter-apk/Invoices_4.3.apk).
// A copy rather than a rename: `flutter build apk` looks for app-release.apk
// and reports the build as failed when it is gone.
val releaseApk = layout.buildDirectory.file("outputs/apk/release/app-release.apk")
val namedApk = layout.buildDirectory.file("outputs/flutter-apk/Invoices_$appVersion.apk")
tasks.matching { it.name == "assembleRelease" }.configureEach {
    doLast {
        val source = releaseApk.get().asFile
        if (source.exists()) {
            val target = namedApk.get().asFile
            source.copyTo(target, overwrite = true)
            println("Release APK: ${target.path}")
        }
    }
}

dependencies {
    // FileProvider, used by MainActivity to hand the invoice PDF to WhatsApp.
    implementation("androidx.core:core-ktx:1.13.1")
}
