plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.android)
}

android {
    namespace = "br.com.axis.validador.hardware.serial"
    compileSdk = 34
    defaultConfig { minSdk = 26 }
}

dependencies {
    implementation(libs.usb.serial)
}
