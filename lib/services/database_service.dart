import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:rotas_app/models/endereco.dart';

/// Serviço de acesso ao banco SQLite embutido
/// 
/// O banco rotas.db vem empacotado no app e contém:
/// - Endereços do CNEFE 2022 (IBGE)
/// - Malha viária do OpenStreetMap
/// - Índice FTS5 para busca rápida
/// 
/// IMPORTANTE: Funciona apenas em iOS/Android (não web)
class DatabaseService {
  static const String _databaseName = 'rotas.db';
  static const int _databaseVersion = 1;
  
  Database? _database;
  
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Inicializa o banco: copia do assets se necessário
  Future<void> initialize() async {
    await database;
  }

  Future<Database> _initDatabase() async {
    // Obtém o diretório de documentos do app
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _databaseName);

    // Verifica se o banco já existe
    final exists = await databaseExists(path);
    
    if (!exists) {
      print('📦 Copiando banco de dados do asset...');
      
      // Cria o diretório se necessário
      try {
        await Directory(dirname(path)).create(recursive: true);
      } catch (_) {}

      // Lê do asset e escreve no disco
      ByteData data = await rootBundle.load('assets/database/$_databaseName');
      List<int> bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      
      await File(path).writeAsBytes(bytes, flush: true);
      print('✅ Banco copiado com sucesso para: $path');
    } else {
      print('✅ Banco já existe em: $path');
    }

    // Abre o banco
    return await openDatabase(
      path,
      version: _databaseVersion,
      readOnly: false,
    );
  }

  /// Busca endereços por texto usando FTS5
  Future<List<Endereco>> buscarEnderecos(
    String query, {
    String codIbge = '3516903',
    int limite = 25,
  }) async {
    final db = await database;

    final consultaFts = _montarConsultaFts(query);
    if (consultaFts == null) return [];

    // Tenta busca FTS5 primeiro
    try {
      final results = await db.rawQuery('''
        SELECT e.*,
               l.nome_completo AS logradouro_completo,
               l.nome AS logradouro_nome,
               (l.nome_completo || ' ' || COALESCE(e.numero, 'S/N') || 
                COALESCE(', ' || e.complemento, '') ||
                COALESCE(' - ' || e.bairro, '')) AS endereco_formatado
        FROM enderecos e
        JOIN logradouros l ON l.id = e.logradouro_id
        WHERE e.id IN (
          SELECT endereco_id FROM enderecos_fts
          WHERE busca MATCH ?
        )
        AND e.cod_ibge = ?
        AND e.ativo = 1
        LIMIT ?
      ''', [consultaFts, codIbge, limite]);
      
      return results.map((map) => Endereco.fromMap(map)).toList();
    } catch (e) {
      print('FTS5 não disponível, usando LIKE: $e');
      // Fallback para LIKE se FTS5 não estiver disponível
      return await _buscarPorLike(query, codIbge, limite);
    }
  }

  /// Transforma o texto digitado numa consulta FTS5 segura com prefixo.
  ///
  /// "Bruno Mart 51" vira `"Bruno"* "Mart"* "51"*`: cada palavra vira um
  /// termo entre aspas (aspas, hífens e dois-pontos do usuário não quebram a
  /// sintaxe) e o `*` encontra palavras incompletas enquanto se digita.
  static String? _montarConsultaFts(String query) {
    final termos = query
        .split(RegExp(r'\s+'))
        .map((t) => t.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), ''))
        .where((t) => t.isNotEmpty)
        .map((t) => '"$t"*')
        .toList();
    return termos.isEmpty ? null : termos.join(' ');
  }

  Future<List<Endereco>> _buscarPorLike(
    String query,
    String codIbge,
    int limite,
  ) async {
    final db = await database;
    final termo = '%${query.toUpperCase()}%';
    
    final results = await db.rawQuery('''
      SELECT e.*,
             l.nome_completo AS logradouro_completo,
             l.nome AS logradouro_nome,
             (l.nome_completo || ' ' || COALESCE(e.numero, 'S/N') || 
              COALESCE(', ' || e.complemento, '') ||
              COALESCE(' - ' || e.bairro, '')) AS endereco_formatado
      FROM enderecos e
      JOIN logradouros l ON l.id = e.logradouro_id
      WHERE e.cod_ibge = ?
        AND e.ativo = 1
        AND (
          l.nome_completo LIKE ? OR
          e.numero LIKE ? OR
          e.bairro LIKE ? OR
          e.estabelecimento LIKE ?
        )
      LIMIT ?
    ''', [codIbge, termo, termo, termo, termo, limite]);
    
    return results.map((map) => Endereco.fromMap(map)).toList();
  }

  /// Busca endereços próximos a uma coordenada
  Future<List<Endereco>> buscarProximos({
    required double lat,
    required double lon,
    double raioMetros = 300.0,
    String codIbge = '3516903',
    int limite = 50,
  }) async {
    final db = await database;
    
    // Caixa delimitadora aproximada
    final grausLat = raioMetros / 111320.0;
    final grausLon = raioMetros / (111320.0 * 0.9); // Aproximação
    
    final results = await db.rawQuery('''
      SELECT e.*,
             l.nome_completo AS logradouro_completo,
             l.nome AS logradouro_nome,
             (l.nome_completo || ' ' || COALESCE(e.numero, 'S/N') || 
              COALESCE(', ' || e.complemento, '') ||
              COALESCE(' - ' || e.bairro, '')) AS endereco_formatado
      FROM enderecos e
      JOIN logradouros l ON l.id = e.logradouro_id
      WHERE e.cod_ibge = ?
        AND e.ativo = 1
        AND e.lat IS NOT NULL
        AND e.lon IS NOT NULL
        AND e.lat BETWEEN ? AND ?
        AND e.lon BETWEEN ? AND ?
      LIMIT ?
    ''', [
      codIbge,
      lat - grausLat,
      lat + grausLat,
      lon - grausLon,
      lon + grausLon,
      limite,
    ]);
    
    return results.map((map) => Endereco.fromMap(map)).toList();
  }

  /// Obtém um endereço por ID
  Future<Endereco?> obterEndereco(int id) async {
    final db = await database;
    
    final results = await db.rawQuery('''
      SELECT e.*,
             l.nome_completo AS logradouro_completo,
             l.nome AS logradouro_nome,
             (l.nome_completo || ' ' || COALESCE(e.numero, 'S/N') || 
              COALESCE(', ' || e.complemento, '') ||
              COALESCE(' - ' || e.bairro, '')) AS endereco_formatado
      FROM enderecos e
      JOIN logradouros l ON l.id = e.logradouro_id
      WHERE e.id = ?
    ''', [id]);
    
    if (results.isEmpty) return null;
    return Endereco.fromMap(results.first);
  }

  /// Obtém múltiplos endereços por IDs
  Future<List<Endereco>> obterEnderecosPorIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    
    final db = await database;
    final marcadores = List.filled(ids.length, '?').join(',');
    
    final results = await db.rawQuery('''
      SELECT e.*,
             l.nome_completo AS logradouro_completo,
             l.nome AS logradouro_nome,
             (l.nome_completo || ' ' || COALESCE(e.numero, 'S/N') || 
              COALESCE(', ' || e.complemento, '') ||
              COALESCE(' - ' || e.bairro, '')) AS endereco_formatado
      FROM enderecos e
      JOIN logradouros l ON l.id = e.logradouro_id
      WHERE e.id IN ($marcadores)
    ''', ids);
    
    return results.map((map) => Endereco.fromMap(map)).toList();
  }

  /// Lista todos os bairros do município
  Future<List<String>> listarBairros({String codIbge = '3516903'}) async {
    final db = await database;
    
    final results = await db.rawQuery('''
      SELECT DISTINCT bairro
      FROM enderecos
      WHERE cod_ibge = ?
        AND bairro IS NOT NULL
        AND ativo = 1
      ORDER BY bairro
    ''', [codIbge]);
    
    return results.map((r) => r['bairro'] as String).toList();
  }

  /// Estatísticas da base de dados
  Future<Map<String, int>> obterEstatisticas({
    String codIbge = '3516903',
  }) async {
    final db = await database;
    
    final total = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM enderecos WHERE cod_ibge = ?', [codIbge]),
    ) ?? 0;
    
    final comNumero = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM enderecos WHERE cod_ibge = ? AND numero IS NOT NULL',
        [codIbge],
      ),
    ) ?? 0;
    
    final verificados = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM enderecos WHERE cod_ibge = ? AND verificado = 1',
        [codIbge],
      ),
    ) ?? 0;
    
    final logradouros = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(DISTINCT logradouro_id) FROM enderecos WHERE cod_ibge = ?',
        [codIbge],
      ),
    ) ?? 0;
    
    return {
      'total': total,
      'com_numero': comNumero,
      'verificados': verificados,
      'logradouros': logradouros,
    };
  }

  /// Verifica se a malha viária está disponível
  Future<bool> malhaDisponivel() async {
    final db = await database;
    try {
      final result = await db.rawQuery('SELECT COUNT(*) FROM malha_arestas LIMIT 1');
      return Sqflite.firstIntValue(result) != null;
    } catch (e) {
      return false;
    }
  }

  /// Fecha a conexão com o banco
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
