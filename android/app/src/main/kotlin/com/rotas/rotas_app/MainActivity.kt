package com.rotas.rotas_app

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Canal usado pela navegação para manter a tela ligada
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "rotas_app/tela")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "manterLigada" -> {
                        val ligar = call.arguments as? Boolean ?: false
                        if (ligar) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
