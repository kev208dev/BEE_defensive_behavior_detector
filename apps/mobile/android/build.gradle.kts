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
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Pub packages that pin their Java compatibility below the 17 this app builds
// at, and so need their Kotlin compilation pinned to the same level.
//
// A package that sets `compileOptions` to Java 11 but declares no Kotlin
// jvmTarget leaves the Kotlin Gradle Plugin to derive its target from the JDK
// running Gradle — 17 here. KGP then compares the two and fails the build:
//
//   Execution failed for task ':tflite_flutter:compileDebugKotlin'.
//   > Inconsistent JVM-target compatibility detected for tasks
//     'compileDebugJavaWithJavac' (11) and 'compileDebugKotlin' (17).
//
// tflite_flutter is the only one of these that currently ships Kotlin sources,
// so it is the only one that trips the check today; the others are listed so a
// version of them that adds Kotlin does not reopen this. Pinning a plugin that
// has no Kotlin to compile is a no-op.
//
// Kotlin is lowered to meet javac rather than javac raised to meet Kotlin,
// because raising javac does not survive: AGP sets the JavaCompile task's
// targetCompatibility from its own DSL in an action it registers while the
// subproject is evaluated, which is after anything this root script registers,
// so AGP's value wins on realization. KGP's jvmTarget, by contrast, is only a
// convention here — the plugin never asks for a target — and an explicit set
// beats a convention no matter when it is registered.
val javaElevenPlugins = setOf("tflite_flutter", "jni", "jni_flutter")

subprojects {
    if (name in javaElevenPlugins) {
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>()
            .configureEach {
                compilerOptions.jvmTarget.set(
                    org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11,
                )
            }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
