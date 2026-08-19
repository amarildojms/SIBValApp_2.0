# Habilitado junto com minifyEnabled/shrinkResources (19/08/2026) pra reduzir
# o tamanho do APK — a maioria dos plugins Flutter já traz suas próprias
# regras de consumo (consumer-rules.pro dentro do AAR), aplicadas automaticamente.
# As regras abaixo cobrem os casos que historicamente quebram com R8 em apps
# Flutter + Firebase + Google Sign-In: reflection do SDK do Google/Firebase.

# Engine e plugins Flutter — o próprio flutter-gradle-plugin já protege a
# embedding, mas manter explícito não tem custo e evita regressão silenciosa
# em upgrades do Flutter.
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase (Auth, Firestore, Storage) — usam reflection internamente para
# achar implementações de transporte/serialização.
-keep class com.google.firebase.** { *; }
-keepattributes Signature
-keepattributes *Annotation*

# Google Play Services / Google Sign-In (Credential Manager por baixo dos
# panos na versão atual do plugin) — classes de credencial não podem ser
# renomeadas, senão a autenticação falha em runtime.
-keep class com.google.android.gms.** { *; }
-keep class com.google.android.libraries.identity.googleid.** { *; }
-keep class androidx.credentials.** { *; }

# Evita warnings fatais de build por classes opcionais que essas libs
# referenciam mas o app não usa (ex.: integrações de outras plataformas).
-dontwarn com.google.android.gms.**
-dontwarn com.google.firebase.**

# io.flutter.embedding.engine.deferredcomponents referencia a lib Play Core
# (`com.google.android.play.core.*`) pra "deferred components" (módulos
# instalados sob demanda pela Play Store) — recurso que este app não usa e a
# dependência nem está no projeto. Sem isso o R8 falha o build com "Missing
# class". Fix oficial do próprio Flutter para esse caso.
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task
