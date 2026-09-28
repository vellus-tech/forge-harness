plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.android)
}

android {
    namespace = "br.com.axis.posrecarga.hardware.printer"
    compileSdk = 34
    defaultConfig { minSdk = 25 }
}

dependencies {
    implementation(project(":core:domain"))
    implementation(libs.sunmi.printer)
    implementation(libs.coroutines.core)
}
