plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
}

android {
    namespace = "br.com.axis.validador"
    compileSdk = 34
    defaultConfig {
        applicationId = "br.com.axis.validador"
        minSdk = 26
        targetSdk = 34
        versionCode = 23
        versionName = "2.3.0"
    }
}

dependencies {
    implementation(project(":core:database"))
    implementation(project(":feature:sync"))
}
