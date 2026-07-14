allprojects {
    repositories {
        google()
        mavenCentral()
        // Kakao 지도 SDK 네이티브 라이브러리 저장소.
        // (kakao_map_sdk 플러그인이 자체적으로도 주입하지만 명시적으로 선언해 둡니다.)
        maven { url = uri("https://devrepo.kakao.com/nexus/repository/kakaomap-releases/") }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
