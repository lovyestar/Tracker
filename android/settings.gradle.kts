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
    id("com.android.application") version "9.0.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
    // Firebase(리더보드)용 google-services 플러그인.
    // apply false 라 google-services.json 이 없어도 무해하며 빌드에 영향 없음.
    // Firebase 사용 시 app/build.gradle.kts 의 주석 한 줄만 해제하면 됩니다. (README 5번)
    id("com.google.gms.google-services") version "4.4.2" apply false
}

include(":app")
