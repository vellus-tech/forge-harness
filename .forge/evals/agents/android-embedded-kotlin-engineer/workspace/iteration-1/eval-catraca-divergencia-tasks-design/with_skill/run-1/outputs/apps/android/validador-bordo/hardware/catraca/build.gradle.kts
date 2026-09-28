plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.android)
}

android {
    namespace = "br.com.axis.validador.hardware.catraca"
    compileSdk = 34
    defaultConfig { minSdk = 26 }
}

dependencies {
    implementation(project(":core:domain"))
    implementation(project(":hardware:serial"))
    implementation(libs.coroutines.core)

    testImplementation(libs.junit)
    testImplementation(libs.coroutines.test)
}
