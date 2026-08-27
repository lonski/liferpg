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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// The Firebase Android SDK AARs (e.g. com.google.firebase:firebase-auth) carry
// `org.checkerframework.checker.initialization.qual.UnknownInitialization` *type*
// annotations in their published bytecode (see
// FirebaseAuth$IdTokenListener.onIdTokenChanged), but their POMs do not declare
// `org.checkerframework:checker-qual` as a dependency, so the annotation class is
// absent from every consumer's compile classpath. Kotlin 2.4 turns an unresolvable
// type annotation on an *inferred* type into a hard compile error
// ("Type annotation class ... of the inferred type is inaccessible"), which breaks
// `:firebase_auth:compileDebugKotlin`. Supplying the annotations-only artifact
// restores the missing declaration. It is `compileOnly`, so nothing is added to the
// APK.
subprojects {
    listOf("com.android.library", "com.android.application").forEach { pluginId ->
        plugins.withId(pluginId) {
            dependencies.add("compileOnly", "org.checkerframework:checker-qual:3.43.0")
        }
    }
}
