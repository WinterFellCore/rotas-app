import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:rotas_app/models/endereco.dart';
import 'package:rotas_app/models/rota_otimizada.dart';
import 'package:rotas_app/services/database_service.dart';
import 'package:rotas_app/services/api_service.dart';
import 'package:rotas_app/services/roteador_local.dart';

/// Provider para gerenciar rotas e paradas
class RotaProvider extends ChangeNotifier {
  final DatabaseService _db;
  late final ApiService _api;
  late final RoteadorLocal _local;

  // Paradas na rota (IDs dos endereços)
  final List<int> _paradasIds = [];
  
  // Endereços completos das paradas (cache)
  final Map<int, Endereco> _enderecosCache = {};
  
  // Rota otimizada atual
  RotaOtimizada? _rotaOtimizada;
  
  // Trajeto detalhado com manobras
  TrajetoDetalhado? _trajetoDetalhado;
  
  // Configurações da rota
  LatLng? _partidaPersonalizada;
  bool _voltarAoInicio = false;
  bool _usarRuas = true;

  // Estado de carregamento
  bool _isOptimizing = false;
  bool _isLoadingTrajeto = false;
  String? _erro;

  RotaProvider(this._db) {
    _api = ApiService();
    _local = RoteadorLocal(_db);
  }

  // Getters
  List<int> get paradasIds => List.unmodifiable(_paradasIds);
  List<Endereco> get paradas => _paradasIds
      .map((id) => _enderecosCache[id])
      .whereType<Endereco>()
      .toList();
  RotaOtimizada? get rotaOtimizada => _rotaOtimizada;
  TrajetoDetalhado? get trajetoDetalhado => _trajetoDetalhado;
  LatLng? get partidaPersonalizada => _partidaPersonalizada;
  bool get voltarAoInicio => _voltarAoInicio;
  bool get usarRuas => _usarRuas;
  bool get isOptimizing => _isOptimizing;
  bool get isLoadingTrajeto => _isLoadingTrajeto;
  String? get erro => _erro;
  bool get temParadas => _paradasIds.isNotEmpty;
  int get numeroParadas => _paradasIds.length;

  /// Configura URL base da API
  void setApiBaseUrl(String url) {
    _api.setBaseUrl(url);
  }

  /// Configura API Key
  void setApiKey(String? key) {
    _api.setApiKey(key);
  }

  /// Adiciona uma parada à rota. Retorna false se o endereço não foi encontrado.
  Future<bool> adicionarParada(int enderecoId) async {
    if (_paradasIds.contains(enderecoId)) {
      return true; // Já está na lista
    }

    // Carrega o endereço antes de incluir o ID, para a lista de IDs e a
    // lista exibida (paradas) terem sempre os mesmos índices
    if (!_enderecosCache.containsKey(enderecoId)) {
      try {
        final endereco = await _db.obterEndereco(enderecoId);
        if (endereco == null) return false;
        _enderecosCache[enderecoId] = endereco;
      } catch (e) {
        debugPrint('Erro ao carregar endereço $enderecoId: $e');
        return false;
      }
    }

    if (_paradasIds.contains(enderecoId)) return true;
    _paradasIds.add(enderecoId);

    // Limpa otimização anterior
    _rotaOtimizada = null;
    _trajetoDetalhado = null;
    _erro = null;

    notifyListeners();
    return true;
  }

  /// Move uma parada arrastada na lista (ReorderableListView)
  void reordenarParada(int indiceAntigo, int indiceNovo) {
    if (indiceAntigo < 0 || indiceAntigo >= _paradasIds.length) return;
    // ReorderableListView informa o índice como se o item ainda estivesse
    // na lista; ao mover para baixo, desconta a posição removida
    if (indiceNovo > indiceAntigo) indiceNovo -= 1;
    indiceNovo = indiceNovo.clamp(0, _paradasIds.length - 1);
    if (indiceNovo == indiceAntigo) return;

    final id = _paradasIds.removeAt(indiceAntigo);
    _paradasIds.insert(indiceNovo, id);
    _rotaOtimizada = null;
    _trajetoDetalhado = null;
    notifyListeners();
  }

  /// Remove uma parada da rota
  void removerParada(int enderecoId) {
    _paradasIds.remove(enderecoId);
    _rotaOtimizada = null;
    _trajetoDetalhado = null;
    _erro = null;
    notifyListeners();
  }

  /// Move uma parada para cima na ordem
  void moverParadaAcima(int index) {
    if (index > 0 && index < _paradasIds.length) {
      final temp = _paradasIds[index];
      _paradasIds[index] = _paradasIds[index - 1];
      _paradasIds[index - 1] = temp;
      _rotaOtimizada = null;
      _trajetoDetalhado = null;
      notifyListeners();
    }
  }

  /// Move uma parada para baixo na ordem
  void moverParadaAbaixo(int index) {
    if (index >= 0 && index < _paradasIds.length - 1) {
      final temp = _paradasIds[index];
      _paradasIds[index] = _paradasIds[index + 1];
      _paradasIds[index + 1] = temp;
      _rotaOtimizada = null;
      _trajetoDetalhado = null;
      notifyListeners();
    }
  }

  /// Limpa toda a rota
  void limparRota() {
    _paradasIds.clear();
    _rotaOtimizada = null;
    _trajetoDetalhado = null;
    _erro = null;
    notifyListeners();
  }

  /// Define ponto de partida personalizado
  void setPartida(LatLng? posicao) {
    _partidaPersonalizada = posicao;
    _rotaOtimizada = null;
    _trajetoDetalhado = null;
    notifyListeners();
  }

  /// Define se deve voltar ao início
  void setVoltarAoInicio(bool valor) {
    _voltarAoInicio = valor;
    _rotaOtimizada = null;
    _trajetoDetalhado = null;
    notifyListeners();
  }

  /// Define se deve usar malha de ruas
  void setUsarRuas(bool valor) {
    _usarRuas = valor;
    _rotaOtimizada = null;
    _trajetoDetalhado = null;
    notifyListeners();
  }

  /// Otimiza a ordem das paradas
  Future<void> otimizarRota() async {
    if (_paradasIds.isEmpty) {
      _erro = 'Adicione paradas à rota primeiro';
      notifyListeners();
      return;
    }

    _isOptimizing = true;
    _erro = null;
    notifyListeners();

    try {
      // Offline primeiro: calcula no aparelho com a malha do banco local.
      // Se falhar, tenta a API.
      try {
        _rotaOtimizada = await _local.otimizar(
          paradasIds: _paradasIds,
          partida: _partidaPersonalizada,
          voltarAoInicio: _voltarAoInicio,
          usarRuas: _usarRuas,
        );
      } catch (e) {
        debugPrint('Otimização local falhou, tentando API: $e');
        _rotaOtimizada = await _api.otimizarRota(
          paradasIds: _paradasIds,
          partida: _partidaPersonalizada,
          voltarAoInicio: _voltarAoInicio,
          usarRuas: _usarRuas,
        );
      }

      // Atualiza ordem das paradas conforme otimização. Paradas que ficaram
      // de fora (sem coordenada) vão para o fim em vez de sumir.
      final anteriores = List<int>.from(_paradasIds);
      _paradasIds.clear();
      for (final paradaNaRota in _rotaOtimizada!.paradas) {
        _paradasIds.add(paradaNaRota.endereco.id);
        _enderecosCache[paradaNaRota.endereco.id] = paradaNaRota.endereco;
      }
      for (final id in anteriores) {
        if (!_paradasIds.contains(id)) _paradasIds.add(id);
      }

      // Limpa trajeto antigo
      _trajetoDetalhado = null;
    } catch (e) {
      _erro = 'Erro ao otimizar rota: $e';
      debugPrint(_erro);
    } finally {
      _isOptimizing = false;
      notifyListeners();
    }
  }

  /// Carrega trajeto detalhado com manobras
  ///
  /// [partida] (ex.: posição do GPS) faz o trajeto começar onde você está.
  Future<void> carregarTrajeto({LatLng? partida}) async {
    final inicio = partida ?? _partidaPersonalizada;
    if (_paradasIds.isEmpty) {
      _erro = 'Adicione paradas à rota primeiro';
      notifyListeners();
      return;
    }

    _isLoadingTrajeto = true;
    _erro = null;
    notifyListeners();

    try {
      try {
        _trajetoDetalhado = await _local.trajeto(
          paradasIds: _paradasIds,
          partida: inicio,
          manobras: true,
        );
      } catch (erroLocal) {
        debugPrint('Trajeto local falhou, tentando API: $erroLocal');
        try {
          _trajetoDetalhado = await _api.obterTrajeto(
            paradasIds: _paradasIds,
            partida: inicio,
            manobras: true,
          );
        } catch (_) {
          // Sem internet, o motivo útil é o local (ex.: precisa de dois pontos)
          throw erroLocal;
        }
      }
    } catch (e) {
      _erro = 'Erro ao carregar trajeto: $e';
      debugPrint(_erro);
    } finally {
      _isLoadingTrajeto = false;
      notifyListeners();
    }
  }

  /// Carrega endereços em cache (útil ao iniciar)
  Future<void> precarregarEnderecos() async {
    if (_paradasIds.isEmpty) return;

    try {
      final enderecos = await _db.obterEnderecosPorIds(_paradasIds);
      for (final endereco in enderecos) {
        _enderecosCache[endereco.id] = endereco;
      }
      notifyListeners();
    } catch (e) {
      print('Erro ao precarregar endereços: $e');
    }
  }

  /// Importa lista de IDs (para restaurar sessão)
  Future<void> importarParadas(List<int> ids) async {
    _paradasIds.clear();
    _paradasIds.addAll(ids);
    _rotaOtimizada = null;
    _trajetoDetalhado = null;
    await precarregarEnderecos();
  }
}
