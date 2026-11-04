import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Mantém a tela ligada durante a navegação.
///
/// Usa um canal nativo simples (MainActivity.kt / AppDelegate.swift):
/// - Android: FLAG_KEEP_SCREEN_ON na janela
/// - iOS: UIApplication.isIdleTimerDisabled
/// Em plataformas sem implementação o pedido é ignorado.
class TelaService {
  static const MethodChannel _canal = MethodChannel('rotas_app/tela');

  static Future<void> manterLigada(bool ligar) async {
    try {
      await _canal.invokeMethod<void>('manterLigada', ligar);
    } on MissingPluginException {
      // Web/desktop: sem suporte, ignora
    } catch (e) {
      debugPrint('Erro ao alterar estado da tela: $e');
    }
  }
}
