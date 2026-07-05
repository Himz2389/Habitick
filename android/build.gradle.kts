allprojects {
    repositories {
        google()
        mavenCentral()
    }
    
    extra.set("compileSdkVersion", 36)
    extra.set("targetSdkVersion", 36)
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


subprojects {
    val subproject = this
    val fixAndroidSdk = {
        val androidExt = subproject.extensions.findByName("android")
        if (androidExt != null && androidExt is com.android.build.gradle.BaseExtension) {
            androidExt.compileSdkVersion(36)
        }
    }
    
    
    if (subproject.state.executed) {
        fixAndroidSdk()
    } 
    
    else {
        subproject.afterEvaluate { fixAndroidSdk() }
    }
}