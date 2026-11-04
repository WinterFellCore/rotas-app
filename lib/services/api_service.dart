import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';
import 'package:rotas_app/models/endereco.dart';
import 'package:rotas_app/models/rota_otimizada.dart';

/// Serviço de comunicação com a API backend (Python/FastAPI)
/// 
/// Endpoint padrão: https://www.zefi.solutions/app/
/// ou servidor local para desenvolvimento/sincronização
class ApiService {
  late final Dio _dio;
  String _baseUrl;
  String? _apiKey;

  ApiService({
    String baseUrl = 'https://www.zefi.solutions',
    String? apiKey,
  })  : _baseUrl = baseUrl,
        _apiKey = apiKey {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Interceptor para adicionar API Key automaticamente
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_apiKey != null && _apiKey!.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $_apiKey';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        print('Erro na requisição: ${error.message}');
        return handler.next(error);
      },
    ));
  }

  /// Atualiza a base URL (útil para alternar entre prod/dev)
  void setBaseUrl(String url) {
    _baseUrl = url;
    _dio.options.baseUrl = url;
  }

  /// Atualiza a API Key
  void setApiKey(String? key) {
    _apiKey = key;
  }

  // ========================================================================
  // Consultas (não requerem autenticação em modo somente leitura)
  // ========================================================================

  /// Verifica saúde da API
  Future<Map<String, dynamic>> verificarSaude() async {
    try {
      final response = await _dio.get('/saude');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  /// Busca endereços por texto
  Future<List<Endereco>> buscar({
    required String query,
    String municipio = '3516903',
    int limite = 25,
  }) async {
    try {
      final response = await _dio.get('/buscar', queryParameters: {
        'q': query,
        'municipio': municipio,
        'limite': limite,
      });

      final List<dynamic> data = response.data as List;
      return data.map((json) => Endereco.fromMap(json as Map<String, dynamic>)).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Busca endereços próximos a uma coordenada
  Future<List<Endereco>> buscarProximos({
    required double lat,
    required double lon,
    double raioMetros = 300,
    String municipio = '3516903',
    int limite = 50,
  }) async {
    try {
      final response = await _dio.get('/proximos', queryParameters: {
        'lat': lat,
        'lon': lon,
        'raio_m': raioMetros,
        'municipio': municipio,
        'limite': limite,
      });

      final List<dynamic> data = response.data as List;
      return data.map((json) => Endereco.fromMap(json as Map<String, dynamic>)).toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Obtém um endereço por ID
  Future<Endereco> obterEndereco(int id) async {
    try {
      final response = await _dio.get('/enderecos/$id');
      return Endereco.fromMap(response.data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  // ========================================================================
  // Otimização de Rotas
  // ========================================================================

  /// Otimiza a ordem de uma lista de paradas
  Future<RotaOtimizada> otimizarRota({
    required List<int> paradasIds,
    LatLng? partida,
    bool voltarAoInicio = false,
    bool usarRuas = true,
    String municipio = '3516903',
  }) async {
    try {
      final body = {
        'paradas': paradasIds,
        'voltar_ao_inicio': voltarAoInicio,
        'usar_ruas': usarRuas,
        'municipio': municipio,
      };

      if (partida != null) {
        body['partida'] = {
          'lat': partida.latitude,
          'lon': partida.longitude,
        };
      }

      final response = await _dio.post('/rota/otimizar', data: body);
      return RotaOtimizada.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  /// Obtém trajeto detalhado com manobras turn-by-turn
  Future<TrajetoDetalhado> obterTrajeto({
    required List<int> paradasIds,
    LatLng? partida,
    bool manobras = true,
    String municipio = '3516903',
  }) async {
    try {
      final body = {
        'paradas': paradasIds,
        'manobras': manobras,
        'municipio': municipio,
      };

      if (partida != null) {
        body['partida'] = {
          'lat': partida.latitude,
          'lon': partida.longitude,
        };
      }

      final response = await _dio.post('/rota/trajeto', data: body);
      return TrajetoDetalhado.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  /// Verifica informações sobre a malha viária
  Future<Map<String, dynamic>> verificarMalha() async {
    try {
      final response = await _dio.get('/malha');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  // ========================================================================
  // Lacunas (números faltando)
  // ========================================================================

  /// Lista números que provavelmente faltam
  Future<List<Map<String, dynamic>>> listarLacunas({
    String municipio = '3516903',
    int? logradouroId,
    int maxCandidatos = 15,
    int limite = 100,
    String confianca = 'todas', // todas|alta|baixa
    bool comCoordenada = true,
  }) async {
    try {
      final response = await _dio.get('/lacunas', queryParameters: {
        'municipio': municipio,
        if (logradouroId != null) 'logradouro_id': logradouroId,
        'max_candidatos': maxCandidatos,
        'limite': limite,
        'confianca': confianca,
        'com_coordenada': comCoordenada,
      });

      return (response.data as List).cast<Map<String, dynamic>>();
    } catch (e) {
      rethrow;
    }
  }

  /// Sugere coordenada para um número específico
  Future<Map<String, dynamic>> sugerirCoordenada({
    required int logradouroId,
    required int numero,
  }) async {
    try {
      final response = await _dio.get('/sugerir-coordenada', queryParameters: {
        'logradouro_id': logradouroId,
        'numero': numero,
      });

      return response.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  // ========================================================================
  // Escrita (requer autenticação)
  // ========================================================================

  /// Cria um novo endereço
  Future<Endereco> criarEndereco({
    required String logradouro,
    required String numero,
    String codIbge = '3516903',
    String? bairro,
    String? complemento,
    String? cep,
    double? lat,
    double? lon,
    int? especie,
    String? estabelecimento,
    String? obs,
    bool verificado = false,
    String? autor,
    bool criarLogradouro = false,
  }) async {
    try {
      final body = {
        'logradouro': logradouro,
        'numero': numero,
        'cod_ibge': codIbge,
        if (bairro != null) 'bairro': bairro,
        if (complemento != null) 'complemento': complemento,
        if (cep != null) 'cep': cep,
        if (lat != null) 'lat': lat,
        if (lon != null) 'lon': lon,
        if (especie != null) 'especie': especie,
        if (estabelecimento != null) 'estabelecimento': estabelecimento,
        if (obs != null) 'obs': obs,
        'verificado': verificado,
        if (autor != null) 'autor': autor,
        'criar_logradouro': criarLogradouro,
      };

      final response = await _dio.post('/enderecos', data: body);
      return Endereco.fromMap(response.data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  /// Verifica um endereço em campo (atualiza coordenada GPS real)
  Future<Endereco> verificarEndereco({
    required int enderecoId,
    double? lat,
    double? lon,
    String? autor,
  }) async {
    try {
      final body = {
        if (lat != null) 'lat': lat,
        if (lon != null) 'lon': lon,
        if (autor != null) 'autor': autor,
      };

      final response = await _dio.post(
        '/enderecos/$enderecoId/verificar',
        data: body,
      );
      return Endereco.fromMap(response.data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  /// Edita um endereço existente
  Future<Endereco> editarEndereco({
    required int enderecoId,
    String? numero,
    String? complemento,
    String? bairro,
    String? cep,
    double? lat,
    double? lon,
    int? especie,
    int? tipoEdificacao,
    String? estabelecimento,
    String? obs,
    bool? ativo,
    String? autor,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (numero != null) body['numero'] = numero;
      if (complemento != null) body['complemento'] = complemento;
      if (bairro != null) body['bairro'] = bairro;
      if (cep != null) body['cep'] = cep;
      if (lat != null) body['lat'] = lat;
      if (lon != null) body['lon'] = lon;
      if (especie != null) body['especie'] = especie;
      if (tipoEdificacao != null) body['tipo_edificacao'] = tipoEdificacao;
      if (estabelecimento != null) body['estabelecimento'] = estabelecimento;
      if (obs != null) body['obs'] = obs;
      if (ativo != null) body['ativo'] = ativo;
      if (autor != null) body['autor'] = autor;

      final response = await _dio.patch(
        '/enderecos/$enderecoId',
        data: body,
      );
      return Endereco.fromMap(response.data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  // ========================================================================
  // Exportação
  // ========================================================================

  /// Exporta endereços em GeoJSON
  Future<Map<String, dynamic>> exportarGeoJson({
    String municipio = '3516903',
    bool apenasComNumero = false,
  }) async {
    try {
      final response = await _dio.get('/exportar/geojson', queryParameters: {
        'municipio': municipio,
        'apenas_com_numero': apenasComNumero,
      });

      return response.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  /// Lista logradouros
  Future<List<Map<String, dynamic>>> listarLogradouros({
    String municipio = '3516903',
    String query = '',
  }) async {
    try {
      final response = await _dio.get('/logradouros', queryParameters: {
        'municipio': municipio,
        'q': query,
      });

      return (response.data as List).cast<Map<String, dynamic>>();
    } catch (e) {
      rethrow;
    }
  }

  /// Lista bairros
  Future<List<Map<String, dynamic>>> listarBairros({
    String municipio = '3516903',
  }) async {
    try {
      final response = await _dio.get('/bairros', queryParameters: {
        'municipio': municipio,
      });

      return (response.data as List).cast<Map<String, dynamic>>();
    } catch (e) {
      rethrow;
    }
  }

  /// Obtém dicionário de códigos
  Future<Map<String, dynamic>> obterDicionario() async {
    try {
      final response = await _dio.get('/dicionario');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }
}
