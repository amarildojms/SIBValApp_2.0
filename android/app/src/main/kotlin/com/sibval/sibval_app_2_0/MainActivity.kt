package com.sibval.sibval_app_2_0

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// Canal nativo pra checar/abrir apps de banco por nome de pacote na aba
/// Contribua (01/09/2026) — ver lib/util/bank_apps.dart. Não usa
/// android_intent_plus de propósito: aquele plugin resolve a atividade via
/// PackageManager.resolveActivity(intent, MATCH_DEFAULT_ONLY), que só
/// encontra apps cujo launcher declara a categoria DEFAULT além de LAUNCHER
/// — a maioria dos bancos (Itaú, Bradesco, Banco do Brasil, CAIXA, Mercado
/// Pago, Sicoob, testado via adb neste projeto) só declara LAUNCHER (padrão
/// do Android, mesmo padrão usado na própria MainActivity abaixo), então
/// ficavam invisíveis mesmo instalados. getLaunchIntentForPackage não tem
/// essa exigência — é a API padrão do Android pra "abrir outro app pelo
/// pacote", usada inclusive pelo próprio launcher do sistema.
class MainActivity : FlutterActivity() {
    private val bankAppsChannel = "sibval.app/bank_apps"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, bankAppsChannel)
            .setMethodCallHandler { call, result ->
                val packageName = call.argument<String>("packageName")
                if (packageName == null) {
                    result.success(false)
                    return@setMethodCallHandler
                }
                when (call.method) {
                    "isInstalled" -> result.success(isPackageInstalled(packageName))
                    "launch" -> result.success(launchPackage(packageName))
                    else -> result.notImplemented()
                }
            }
    }

    private fun isPackageInstalled(packageName: String): Boolean {
        return try {
            packageManager.getApplicationInfo(packageName, 0)
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun launchPackage(packageName: String): Boolean {
        val intent = packageManager.getLaunchIntentForPackage(packageName) ?: return false
        return try {
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }
}
