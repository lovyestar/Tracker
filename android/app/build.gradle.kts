plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // ── Firebase(리더보드) 활성화됨. ──
    // settings.gradle.kts 에 플러그인이 선언돼 있고 google-services.json 이
    // android/app/ 에 배치되어 있어(패키지 com.example.tracker_app 일치) 활성화 상태입니다.
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.tracker_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.tracker_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // ★ Kakao 지도 SDK 요구사항: minSdk 23 이상 ★
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // 데모/제출용: 디버그 서명키로 서명해 `flutter run --release` 및 APK 설치가 바로 되게 합니다.
            // 실제 배포 시에는 별도의 release 서명키로 교체하세요.
            signingConfig = signingConfigs.getByName("debug")

            // 코드 축소(R8) 사용 시 proguard-rules.pro 의 Kakao 보존 규칙을 함께 적용합니다.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
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
