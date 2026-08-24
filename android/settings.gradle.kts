pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.9.1" apply false
    // START: FlutterFire Configuration
    id("com.google.gms.google-services") version("4.3.15") apply false
    // END: FlutterFire Configuration
    // Must stay >= the Kotlin version the AdMob SDK was built with:
    // play-services-ads 25.3.0 carries Kotlin 2.3.0 metadata, and compiling
    // against it with an older Kotlin fails with "Module was compiled with an
    // incompatible version of Kotlin". Bump this when bumping google_mobile_ads.
    id("org.jetbrains.kotlin.android") version "2.3.0" apply false
}

include(":app")
