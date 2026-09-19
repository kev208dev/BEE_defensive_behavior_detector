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

// Keep every subproject's Java bytecode target at the level the app itself
// uses (17, see app/build.gradle.kts).
//
// Some pub packages pin their Java compatibility to 11 and never declare a
// Kotlin jvmTarget — tflite_flutter 0.12.1 is the one that bites here, and
// it is the only Java-11 plugin in this build that actually ships Kotlin
// sources. The Kotlin Gradle Plugin then takes its target from the JDK
// running Gradle (17), disagrees with javac (11), and fails the whole build:
//
//   Execution failed for task ':tflite_flutter:compileDebugKotlin'.
//   > Inconsistent JVM-target compatibility detected for tasks
//     'compileDebugJavaWithJavac' (11) and 'compileDebugKotlin' (17).
//
// A pub package cannot be edited, so the alignment has to happen here.
// Raising javac rather than lowering Kotlin is what converges the build:
// every plugin that declares a Kotlin jvmTarget already declares 17, so
// nothing is pulled away from a target it asked for.
//
// Only JavaCompile is touched, deliberately — it is a core Gradle type, so
// this file needs no Kotlin Gradle Plugin classes on the root build script's
// classpath.
subprojects {
    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = JavaVersion.VERSION_17.toString()
        targetCompatibility = JavaVersion.VERSION_17.toString()
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
