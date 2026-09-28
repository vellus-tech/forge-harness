plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
}

android {
    namespace = "br.com.axis.posrecarga"
    compileSdk = 34
    defaultConfig {
        applicationId = "br.com.axis.posrecarga"
        minSdk = 25
        targetSdk = 34
        versionCode = 14
        versionName = "1.6.0"
    }
}

dependencies {
    implementation(project(":core:domain"))
    implementation(project(":hardware:nfc"))
    implementation(libs.coroutines.core)
}
