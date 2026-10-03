import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.plugin.compose")
}

@Suppress("UnstableApiUsage")
android {
    namespace = "com.vincent.rentreceipt"
    buildToolsVersion = "37.0.0"
    compileSdk {
        version = release(37) { minorApiLevel = 0 }
    }

    defaultConfig {
        applicationId = "com.vincent.rentreceipt"
        minSdk = 31
        targetSdk = 37
        versionCode = 2
        versionName = "1.1"
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }

    // 读取项目根目录的 keystore.properties（含密码，已在 .gitignore 中）。
    // 该文件不存在时（例如他人 clone 后构建）回退到 debug 签名，保证仓库开箱可编译。
    val keystorePropsFile = rootProject.file("keystore.properties")
    val loadedKeystoreProps: Properties? = if (keystorePropsFile.exists()) {
        Properties().apply { keystorePropsFile.inputStream().use { load(it) } }
    } else {
        null
    }
    val keystoreProps = loadedKeystoreProps?.takeIf { properties ->
        properties.getProperty("storeFile")?.let(::file)?.exists() == true
    }

    signingConfigs {
        if (keystoreProps != null) {
            create("release") {
                storeFile = file(keystoreProps.getProperty("storeFile"))
                storePassword = keystoreProps.getProperty("storePassword")
                keyAlias = keystoreProps.getProperty("keyAlias")
                keyPassword = keystoreProps.getProperty("keyPassword")
                // v2 保证兼容性（minSdk 31 仍建议保留），
                // v3 支持密钥轮换（key rotation）：万一将来需要更换签名密钥，
                // 已安装用户仍可平滑升级，不必卸载重装。
                enableV2Signing = true
                enableV3Signing = true
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            if (keystoreProps != null) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                signingConfig = signingConfigs.getByName("debug")
                logger.warn(
                    "未找到 keystore.properties，release 包将用 debug 密钥签名。" +
                        "正式发布前请配置自己的 keystore，否则用户无法覆盖安装升级。"
                )
            }
        }
    }

    packaging {
        resources.excludes += "/META-INF/{AL2.0,LGPL2.1}"
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_21)
    }
}

dependencies {
    implementation(platform("androidx.compose:compose-bom:2026.06.00"))
    implementation("androidx.core:core-ktx:1.16.0")
    implementation("androidx.activity:activity-compose:1.12.4")
    implementation("androidx.compose.animation:animation")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3:1.4.0")
    implementation("androidx.compose.material:material-icons-core")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("com.materialkolor:material-kolor:4.1.1")
    implementation("top.yukonga.miuix.kmp:miuix-ui:0.9.4")
    implementation("top.yukonga.miuix.kmp:miuix-preference:0.9.4")
    implementation("top.yukonga.miuix.kmp:miuix-icons:0.9.4")
    implementation("top.yukonga.miuix.kmp:miuix-nav:0.9.4")
    implementation("top.yukonga.miuix.kmp:miuix-blur:0.9.4")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.10.0")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.10.0")
    testImplementation("junit:junit:4.13.2")
    debugImplementation("androidx.compose.ui:ui-tooling")
}
