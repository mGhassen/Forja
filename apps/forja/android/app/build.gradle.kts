plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

// Repo root: apps/forja/android -> Forja/
val repoRoot = rootProject.projectDir.parentFile.parentFile.parentFile
val buildRust =
    providers.gradleProperty("buildRust").orNull == "true" ||
        System.getenv("BUILD_RUST_ANDROID") == "1"

if (buildRust) {
    tasks.register<Exec>("buildRustAndroid") {
        group = "rust"
        description = "Cross-compile libffi.so (arm64-v8a + armeabi-v7a) via scripts/build_rust_mobile.sh"
        workingDir = repoRoot
        commandLine("bash", "scripts/build_rust_mobile.sh", "android")
    }
    tasks.matching { it.name == "preReleaseBuild" }.configureEach {
        dependsOn("buildRustAndroid")
    }
}

android {
    namespace = "com.forja.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.forja.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            signingConfig = if (project.hasProperty("FORJA_KEYSTORE_PATH")) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }

    signingConfigs {
        create("release") {
            storeFile = file(project.findProperty("FORJA_KEYSTORE_PATH") as String? ?: "release.keystore")
            storePassword = project.findProperty("FORJA_KEYSTORE_PASSWORD") as String? ?: ""
            keyAlias = project.findProperty("FORJA_KEY_ALIAS") as String? ?: "forja"
            keyPassword = project.findProperty("FORJA_KEY_PASSWORD") as String? ?: ""
        }
    }
}

flutter {
    source = "../.."
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
