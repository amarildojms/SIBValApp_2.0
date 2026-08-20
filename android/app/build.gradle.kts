import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Mesma chave de upload usada pelo app nativo (SIBValApp2) — vive fora do
// repositório (C:\Users\Administrador\keystores\) para nunca ser commitada.
val releaseKeystoreProperties = Properties().apply {
    val propsFile = File("C:/Users/Administrador/keystores/sibvalapp-keystore.properties")
    if (propsFile.exists()) {
        propsFile.inputStream().use { load(it) }
    }
}

android {
    namespace = "com.sibval.sibval_app_2_0"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Mesmo applicationId do app nativo (SIBValApp2) — a reescrita em Flutter substitui
        // o nativo na mesma ficha da Play Store (mesmo histórico de testes/avaliações/base
        // instalada), em vez de virar um app novo. Assinado com a mesma chave de upload
        // (ver releaseKeystoreProperties acima), já cadastrada no Firebase para este pacote.
        applicationId = "com.sibval.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseKeystoreProperties.containsKey("storeFile")) {
            create("release") {
                storeFile = file(releaseKeystoreProperties.getProperty("storeFile"))
                storePassword = releaseKeystoreProperties.getProperty("storePassword")
                keyAlias = releaseKeystoreProperties.getProperty("keyAlias")
                keyPassword = releaseKeystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (releaseKeystoreProperties.containsKey("storeFile")) {
                signingConfigs.getByName("release")
            } else {
                // Sem a chave de upload disponível nesta máquina, cai pro debug pra
                // `flutter run --release` continuar funcionando.
                signingConfigs.getByName("debug")
            }
            // 19/08/2026: reduz o tamanho do APK (código Java/Kotlin morto de
            // Firebase/Google Sign-In não utilizado, recursos não referenciados).
            // Regras de manutenção em proguard-rules.pro — testar login,
            // notificações e upload de foto depois de qualquer mudança aqui.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
