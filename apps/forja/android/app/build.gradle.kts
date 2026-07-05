plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Repo root: apps/forja/android -> Forja/
val forjaRepoRoot = rootProject.projectDir.parentFile.parentFile.parentFile
val forjaBuildRust =
    providers.gradleProperty("forjaBuildRust").orNull == "true" ||
        System.getenv("FORJA_BUILD_RUST_ANDROID") == "1"

if (forjaBuildRust) {
    tasks.register<Exec>("buildForjaRustAndroid") {
        group = "forja"
        description = "Cross-compile libforja_ffi.so (arm64-v8a) via scripts/build_rust_mobile.sh"
        workingDir = forjaRepoRoot
        commandLine("bash", "scripts/build_rust_mobile.sh", "android")
    }
    tasks.matching { it.name == "preReleaseBuild" }.configureEach {
        dependsOn("buildForjaRustAndroid")
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

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.forja.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
