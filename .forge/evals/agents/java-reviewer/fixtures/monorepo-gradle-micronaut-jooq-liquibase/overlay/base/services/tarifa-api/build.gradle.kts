plugins {
    id("io.micronaut.application") version "4.4.2"
    id("nu.studer.jooq") version "9.0"
}

version = "2.1.0"
group = "br.com.axis.tarifa"

dependencies {
    annotationProcessor("io.micronaut.validation:micronaut-validation-processor")
    implementation("io.micronaut.validation:micronaut-validation")
    implementation("io.micronaut.sql:micronaut-jooq")
    implementation("io.micronaut.liquibase:micronaut-liquibase")
    implementation("io.micronaut.data:micronaut-data-tx-jdbc")
    runtimeOnly("org.postgresql:postgresql")
    testImplementation("org.testcontainers:postgresql")
}

micronaut {
    runtime("netty")
    testRuntime("junit5")
}
