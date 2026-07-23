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

// Plugin subprojects (screen_protector, home_widget, workmanager_android,
// etc.) each pin their own Java/Kotlin compat in their own android {} /
// kotlinOptions {} blocks (some 1.8, some inheriting the running JDK) —
// tripping AGP's "Inconsistent JVM Target Compatibility" check. Override
// both to 17 via afterEvaluate so ours applies after the plugin's own
// script. evaluationDependsOn(":app") above forces :app to already be
// evaluated by this point (already at 17 per app/build.gradle.kts), so
// only the not-yet-evaluated plugin subprojects need the override.
subprojects {
    if (!state.executed) {
        afterEvaluate {
            extensions.findByType(com.android.build.gradle.BaseExtension::class.java)?.apply {
                compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_17
                    targetCompatibility = JavaVersion.VERSION_17
                }
            }
            tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
                compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
