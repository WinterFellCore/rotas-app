import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Serviço de Text-to-Speech para navegação por voz
/// 
/// Usa flutter_tts (nativo iOS/Android) para falar instruções
/// em português brasileiro durante a navegação
class TTSService {
  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;

  bool get isInitialized => _isInitialized;
  bool get isSpeaking => _isSpeaking;

  /// Inicializa o serviço TTS
  Future<void> initialize() async {
    try {
      // iOS: categoria de áudio "playback" para continuar falando com a
      // tela bloqueada e baixar o volume de outros apps (música) durante a fala
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        await _tts.setSharedInstance(true);
        await _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.duckOthers,
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
            IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          ],
          IosTextToSpeechAudioMode.voicePrompt,
        );
      }

      // Configurações gerais
      await _tts.setLanguage('pt-BR');
      await _tts.setSpeechRate(0.5); // Velocidade normal
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      // Callbacks para monitorar estado
      _tts.setStartHandler(() {
        _isSpeaking = true;
      });

      _tts.setCompletionHandler(() {
        _isSpeaking = false;
      });

      _tts.setErrorHandler((message) {
        print('Erro TTS: $message');
        _isSpeaking = false;
      });

      _tts.setCancelHandler(() {
        _isSpeaking = false;
      });

      _isInitialized = true;
      print('TTS inicializado com sucesso');
    } catch (e) {
      print('Erro ao inicializar TTS: $e');
      _isInitialized = false;
    }
  }

  /// Fala um texto
  Future<void> falar(String texto) async {
    if (!_isInitialized) {
      print('TTS não inicializado');
      return;
    }

    try {
      // Cancela fala anterior se houver
      if (_isSpeaking) {
        await parar();
      }

      await _tts.speak(texto);
    } catch (e) {
      print('Erro ao falar: $e');
    }
  }

  /// Para a fala atual
  Future<void> parar() async {
    if (!_isInitialized) return;

    try {
      await _tts.stop();
      _isSpeaking = false;
    } catch (e) {
      print('Erro ao parar TTS: $e');
    }
  }

  /// Pausa a fala
  Future<void> pausar() async {
    if (!_isInitialized) return;

    try {
      await _tts.pause();
    } catch (e) {
      print('Erro ao pausar TTS: $e');
    }
  }

  /// Ajusta velocidade de fala (0.0 a 1.0)
  Future<void> setVelocidade(double velocidade) async {
    if (!_isInitialized) return;

    try {
      await _tts.setSpeechRate(velocidade);
    } catch (e) {
      print('Erro ao ajustar velocidade: $e');
    }
  }

  /// Ajusta volume (0.0 a 1.0)
  Future<void> setVolume(double volume) async {
    if (!_isInitialized) return;

    try {
      await _tts.setVolume(volume);
    } catch (e) {
      print('Erro ao ajustar volume: $e');
    }
  }

  /// Ajusta tom/pitch (0.5 a 2.0)
  Future<void> setPitch(double pitch) async {
    if (!_isInitialized) return;

    try {
      await _tts.setPitch(pitch);
    } catch (e) {
      print('Erro ao ajustar pitch: $e');
    }
  }

  /// Lista vozes disponíveis
  Future<List<dynamic>> listarVozes() async {
    if (!_isInitialized) return [];

    try {
      return await _tts.getVoices ?? [];
    } catch (e) {
      print('Erro ao listar vozes: $e');
      return [];
    }
  }

  /// Define voz específica
  Future<void> setVoz(Map<String, String> voz) async {
    if (!_isInitialized) return;

    try {
      await _tts.setVoice(voz);
    } catch (e) {
      print('Erro ao definir voz: $e');
    }
  }

  /// Limpa recursos
  void dispose() {
    _tts.stop();
  }
}
