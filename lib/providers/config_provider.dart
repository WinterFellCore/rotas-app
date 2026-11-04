import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider para configurações do app
class ConfigProvider extends ChangeNotifier {
  static const String _keyApiBaseUrl = 'api_base_url';
  static const String _keyApiKey = 'api_key';
  static const String _keyMunicipioId = 'municipio_id';
  static const String _keyTemaEscuro = 'tema_escuro';
  static const String _keyVozHabilitada = 'voz_habilitada';
  static const String _keyVelocidadeVoz = 'velocidade_voz';
  static const String _keyVolumeVoz = 'volume_voz';

  SharedPreferences? _prefs;
  bool _initialized = false;

  // Valores padrão
  String _apiBaseUrl = 'https://www.zefi.solutions';
  String? _apiKey;
  String _municipioId = '3516903';
  bool _temaEscuro = false;
  bool _vozHabilitada = true;
  double _velocidadeVoz = 0.5;
  double _volumeVoz = 1.0;

  // Getters
  bool get initialized => _initialized;
  String get apiBaseUrl => _apiBaseUrl;
  String? get apiKey => _apiKey;
  String get municipioId => _municipioId;
  bool get temaEscuro => _temaEscuro;
  bool get vozHabilitada => _vozHabilitada;
  double get velocidadeVoz => _velocidadeVoz;
  double get volumeVoz => _volumeVoz;

  /// Inicializa e carrega configurações salvas
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _prefs = prefs;
      _carregar(prefs);
    } catch (e) {
      // Sem armazenamento: segue com os valores padrão em memória
      debugPrint('Erro ao carregar configurações: $e');
    }
    _initialized = true;
    notifyListeners();
  }

  void _carregar(SharedPreferences prefs) {
    _apiBaseUrl = prefs.getString(_keyApiBaseUrl) ?? _apiBaseUrl;
    _apiKey = prefs.getString(_keyApiKey);
    _municipioId = prefs.getString(_keyMunicipioId) ?? _municipioId;
    _temaEscuro = prefs.getBool(_keyTemaEscuro) ?? _temaEscuro;
    _vozHabilitada = prefs.getBool(_keyVozHabilitada) ?? _vozHabilitada;
    _velocidadeVoz = prefs.getDouble(_keyVelocidadeVoz) ?? _velocidadeVoz;
    _volumeVoz = prefs.getDouble(_keyVolumeVoz) ?? _volumeVoz;
  }

  /// Define URL base da API
  Future<void> setApiBaseUrl(String url) async {
    _apiBaseUrl = url;
    await _prefs?.setString(_keyApiBaseUrl, url);
    notifyListeners();
  }

  /// Define API Key
  Future<void> setApiKey(String? key) async {
    _apiKey = key;
    if (key != null) {
      await _prefs?.setString(_keyApiKey, key);
    } else {
      await _prefs?.remove(_keyApiKey);
    }
    notifyListeners();
  }

  /// Define município
  Future<void> setMunicipioId(String id) async {
    _municipioId = id;
    await _prefs?.setString(_keyMunicipioId, id);
    notifyListeners();
  }

  /// Alterna tema escuro
  Future<void> setTemaEscuro(bool valor) async {
    _temaEscuro = valor;
    await _prefs?.setBool(_keyTemaEscuro, valor);
    notifyListeners();
  }

  /// Habilita/desabilita voz
  Future<void> setVozHabilitada(bool valor) async {
    _vozHabilitada = valor;
    await _prefs?.setBool(_keyVozHabilitada, valor);
    notifyListeners();
  }

  /// Define velocidade da voz
  Future<void> setVelocidadeVoz(double valor) async {
    _velocidadeVoz = valor;
    await _prefs?.setDouble(_keyVelocidadeVoz, valor);
    notifyListeners();
  }

  /// Define volume da voz
  Future<void> setVolumeVoz(double valor) async {
    _volumeVoz = valor;
    await _prefs?.setDouble(_keyVolumeVoz, valor);
    notifyListeners();
  }

  /// Reseta todas as configurações
  Future<void> resetar() async {
    await _prefs?.clear();
    _apiBaseUrl = 'https://www.zefi.solutions';
    _apiKey = null;
    _municipioId = '3516903';
    _temaEscuro = false;
    _vozHabilitada = true;
    _velocidadeVoz = 0.5;
    _volumeVoz = 1.0;
    notifyListeners();
  }
}
