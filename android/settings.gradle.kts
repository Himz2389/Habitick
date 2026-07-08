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

// AGP 9.0 removed support for plugins applying their own Kotlin Gradle
// Plugin (see https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin).
// flutter_timezone, quill_native_bridge_android, package_info_plus, and
// workmanager all still apply KGP the legacy way and have no published
// version that's migrated, so building against AGP 9.x hard-fails
// (":app:compileDebugJavaWithJavac" — "Cannot query the value of this
// provider because it has no value available"). Pinned to the last 8.x
// line, which still supports it, until those plugins migrate upstream.
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.13.0" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
}

include(":app")
