import javax.xml.parsers.DocumentBuilderFactory

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.plugin.compose")
}

val firebaseConfig = rootProject.projectDir.parentFile.resolve("GoogleService-Info.plist")
fun plistValue(key: String): String {
    if (!firebaseConfig.exists()) return ""
    val document = DocumentBuilderFactory.newInstance().newDocumentBuilder().parse(firebaseConfig)
    val keys = document.getElementsByTagName("key")
    for (index in 0 until keys.length) {
        if (keys.item(index).textContent == key) {
            var valueNode = keys.item(index).nextSibling
            while (valueNode != null && valueNode.nodeType != 1) valueNode = valueNode.nextSibling
            return valueNode?.textContent.orEmpty()
        }
    }
    return ""
}
fun quotedBuildValue(value: String): String = "\"${value.replace("\\", "\\\\").replace("\"", "\\\"")}\""
val releaseKeystorePath = System.getenv("ANDROID_KEYSTORE_PATH")
val hasReleaseSigning = !releaseKeystorePath.isNullOrBlank() &&
    !System.getenv("ANDROID_KEYSTORE_PASSWORD").isNullOrBlank() &&
    !System.getenv("ANDROID_KEY_ALIAS").isNullOrBlank() &&
    !System.getenv("ANDROID_KEY_PASSWORD").isNullOrBlank()

android {
    namespace = "fi.chromehearts.cards.android"
    compileSdk = 37

    defaultConfig {
        applicationId = "fi.chromehearts.cards.android"
        minSdk = 26
        targetSdk = 36
        versionCode = providers.gradleProperty("versionCode").orNull?.toIntOrNull() ?: 1
        versionName = providers.gradleProperty("versionName").orNull ?: "1.0.0"
        buildConfigField("String", "FIREBASE_API_KEY", quotedBuildValue(plistValue("API_KEY")))
        buildConfigField("String", "FIREBASE_DATABASE_URL", quotedBuildValue(plistValue("DATABASE_URL")))
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(releaseKeystorePath!!)
                storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("ANDROID_KEY_ALIAS")
                keyPassword = System.getenv("ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        getByName("release") {
            // GitHub Actions uses a persistent release key when supplied, otherwise a debug key.
            signingConfig = if (hasReleaseSigning) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
            isMinifyEnabled = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

}

dependencies {
    implementation(platform("androidx.compose:compose-bom:2026.09.00"))
    implementation("androidx.activity:activity-compose:1.12.2")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.10.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")
    implementation("com.google.code.gson:gson:2.13.2")
    implementation("com.google.zxing:core:3.5.4")
    implementation("com.google.mlkit:barcode-scanning:17.3.0")
    implementation("androidx.camera:camera-camera2:1.5.2")
    implementation("androidx.camera:camera-lifecycle:1.5.2")
    implementation("androidx.camera:camera-view:1.5.2")
    debugImplementation("androidx.compose.ui:ui-tooling")
}
