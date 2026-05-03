plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

fun readDotEnv(file: File): Map<String, String> {
    if (!file.exists()) return emptyMap()

    return file.readLines()
        .map { it.trim() }
        .filter { it.isNotEmpty() && !it.startsWith("#") && it.contains("=") }
        .mapNotNull { line ->
            val parts = line.split("=", limit = 2)
            val key = parts[0].trim()
            var value = parts[1].trim()
            if (
                (value.startsWith("\"") && value.endsWith("\"")) ||
                (value.startsWith("'") && value.endsWith("'"))
            ) {
                value = value.substring(1, value.length - 1)
            }
            key.takeIf { it.isNotEmpty() }?.let { it to value }
        }
        .toMap()
}

val dotEnv = readDotEnv(rootProject.projectDir.parentFile.resolve(".env"))

fun configValue(vararg names: String): String {
    for (name in names) {
        val propertyValue = project.findProperty(name)?.toString()
        if (!propertyValue.isNullOrBlank()) return propertyValue

        val environmentValue = System.getenv(name)
        if (!environmentValue.isNullOrBlank()) return environmentValue

        val dotEnvValue = dotEnv[name]
        if (!dotEnvValue.isNullOrBlank()) return dotEnvValue
    }
    return ""
}

android {
    namespace = "com.urbanparking.india"
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
        applicationId = "com.urbanparking.india"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["googleMapsApiKey"] = configValue(
            "GOOGLE_MAPS_API_KEY",
            "ANDROID_GOOGLE_MAPS_API_KEY",
            "EXPO_PUBLIC_GOOGLE_MAPS_API_KEY",
            "GOOGLE_ANDROID_API_KEY",
        )
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
