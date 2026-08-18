allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // Flutter's integration_test plugin currently declares these artifacts
    // with dynamic `+` versions. Dynamic selectors force a metadata request on
    // every release build and make otherwise cached builds fail during a
    // temporary Maven/DNS outage. Pin the exact compatible versions used by
    // Flutter's own lockfile so Android releases remain reproducible.
    if (name == "integration_test") {
        configurations.configureEach {
            resolutionStrategy.eachDependency {
                when ("${requested.group}:${requested.name}") {
                    "androidx.test:runner" -> useVersion("1.3.0")
                    "androidx.test:rules" -> useVersion("1.2.0")
                    "androidx.test.espresso:espresso-core" -> useVersion("3.3.0")
                }
            }
        }
    }

    // Flutter currently keeps legacy Kotlin enabled for AGP 9 compatibility.
    // file_picker 11.0.2 skips its Kotlin plugin based only on the AGP version,
    // so its Kotlin sources otherwise never reach the Android compilation.
    if (name == "file_picker") {
        pluginManager.withPlugin("com.android.library") {
            pluginManager.apply("org.jetbrains.kotlin.android")
            extensions.configure<org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension> {
                compilerOptions {
                    jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
                }
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
