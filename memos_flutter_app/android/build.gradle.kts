import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

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

subprojects {
    plugins.withId("com.android.library") {
        afterEvaluate {
            val androidExt = extensions.findByName("android") ?: return@afterEvaluate
            val setter = androidExt.javaClass.methods.firstOrNull { it.name == "setNamespace" && it.parameterCount == 1 }
            val getter = androidExt.javaClass.methods.firstOrNull { it.name == "getNamespace" && it.parameterCount == 0 }
            if (setter != null && getter != null) {
                val current = getter.invoke(androidExt) as? String
                if (current.isNullOrBlank()) {
                    val rawGroup = project.group.toString().trim()
                    val groupValue = rawGroup.takeIf { it.isNotEmpty() && it != "unspecified" }
                    val fallback = "com.memoflow.autonamespace.${project.name.replace('-', '_')}"
                    setter.invoke(androidExt, groupValue ?: fallback)
                }
            }
        }
    }
}

subprojects {
    if (name == "image_gallery_saver") {
        tasks.withType<KotlinCompile>().configureEach {
            compilerOptions.jvmTarget.set(JvmTarget.JVM_1_8)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
