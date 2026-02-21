import java.io.FileInputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasKeystoreProperties = keystorePropertiesFile.exists()
if (hasKeystoreProperties) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
val releaseSigningReady = if (hasKeystoreProperties) {
    val keyAlias = keystoreProperties.getProperty("keyAlias")?.trim()
    val keyPassword = keystoreProperties.getProperty("keyPassword")?.trim()
    val storePassword = keystoreProperties.getProperty("storePassword")?.trim()
    val storeFilePath = keystoreProperties.getProperty("storeFile")?.trim()
    if (keyAlias.isNullOrEmpty() ||
        keyPassword.isNullOrEmpty() ||
        storePassword.isNullOrEmpty() ||
        storeFilePath.isNullOrEmpty()
    ) {
        false
    } else {
        val storeFile = file(storeFilePath)
        storeFile.isFile && storeFile.length() > 0
    }
} else {
    false
}

android {
    namespace = "com.memoflow.hzc073"
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.memoflow.hzc073"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (releaseSigningReady) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(requireNotNull(keystoreProperties.getProperty("storeFile")))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        debug {
            applicationIdSuffix = ".debug"
        }

        release {
            signingConfig = if (releaseSigningReady) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // Ensure R8 keeps generic signatures used by Gson when shrinking is enabled.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.core:core-splashscreen:1.0.1")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

val copyReleaseApk by tasks.registering {
    group = "build"
    description = "Copy release APK to tool/<date>/MemoFlow_v<version>-release.apk"
    doLast {
        val flutterRoot = rootProject.projectDir.parentFile
        val dateTag = SimpleDateFormat("yyyyMMdd").format(Date())
        val outDir = File(flutterRoot, "tool/$dateTag")
        val versionLabel = run {
            val pubspecFile = File(flutterRoot, "pubspec.yaml")
            if (!pubspecFile.exists()) {
                "0.0.0"
            } else {
                val rawVersion = pubspecFile.useLines { lines ->
                    lines.map { it.trim() }
                        .firstOrNull { it.startsWith("version:") }
                        ?.substringAfter("version:")
                        ?.trim()
                }
                val cleaned = rawVersion?.split(" ")?.firstOrNull()?.ifBlank { null }
                val versionName = cleaned?.substringBefore("+") ?: "0.0.0"
                versionName.replace(Regex("[^A-Za-z0-9._-]"), "_")
            }
        }
        if (!outDir.exists()) {
            outDir.mkdirs()
        }

        val preferredRoots = listOf(
            File(flutterRoot, "build/app/outputs/flutter-apk"),
            File(flutterRoot, "build/app/outputs/apk/release")
        ).filter { it.exists() }

        val preferredApks = preferredRoots.flatMap { dir ->
            dir.listFiles { file ->
                file.isFile && file.name.contains("release") && file.extension == "apk"
            }?.toList() ?: emptyList()
        }.distinct()

        val apkFiles = if (preferredApks.isNotEmpty()) {
            preferredApks
        } else {
            val fallbackRoot = File(flutterRoot, "build/app/outputs")
            if (fallbackRoot.exists()) {
                fallbackRoot.walkTopDown()
                    .filter { it.isFile && it.name.contains("release") && it.extension == "apk" }
                    .toList()
            } else {
                emptyList()
            }
        }

        if (apkFiles.isEmpty()) {
            throw RuntimeException(
                "No release APKs found under ${File(flutterRoot, "build/app/outputs").absolutePath}"
            )
        }

        val preferredApk = apkFiles.firstOrNull { it.name == "app-release.apk" }
        val apkToCopy = preferredApk ?: apkFiles.maxByOrNull { it.lastModified() }!!
        if (preferredApk == null && apkFiles.size > 1) {
            println("Multiple release APKs found; copying newest: ${apkToCopy.name}")
        }

        val destFile = File(outDir, "MemoFlow_v${versionLabel}-release.apk")
        apkToCopy.copyTo(destFile, overwrite = true)
        println("APK copied to: ${destFile.absolutePath}")
    }
}

tasks.matching { it.name == "assembleRelease" }.configureEach {
    finalizedBy(copyReleaseApk)
}
