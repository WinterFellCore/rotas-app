import 'dart:math' as math;
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:latlong2/latlong.dart';
import 'package:rotas_app/models/manobra.dart';
import 'package:rotas_app/models/rota_otimizada.dart';
import 'package:rotas_app/services/database_service.dart';
import 'package:rotas_app/utils/rota_optimizer.dart';

/// Otimização e trajeto pelas ruas SEM internet.
///
/// Porte de `rotas/malha.py`, `rotas/manobras.py` e das rotas `/rota/otimizar`
/// e `/rota/trajeto` de `rotas/api.py`. Usa as tabelas `malha_nos` e
/// `malha_arestas` do rotas.db que já vem dentro do app, então dá o mesmo
/// resultado que a API.
class RoteadorLocal {
  final DatabaseService _db;
  Future<_Malha?>? _malha;

  RoteadorLocal(this._db);

  // Mesmas constantes do backend (rotas/rota.py e rotas/api.py)
  static const double velocidadeMediaKmh = 22.0;
  static const int segundosPorParada = 90;
  static const double _tetoRecuo = 250.0;

  /// Carrega o grafo uma vez e guarda em memória (~22 mil nós, ~44 mil arestas).
  Future<_Malha?> _carregarMalha() {
    return _malha ??= _Malha.carregar(_db).catchError((Object e) {
      _malha = null; // permite tentar de novo
      throw e;
    });
  }

  /// Mesmo contrato de POST /rota/otimizar
  Future<RotaOtimizada> otimizar({
    required List<int> paradasIds,
    LatLng? partida,
    bool voltarAoInicio = false,
    bool usarRuas = true,
  }) async {
    final avisos = <String>[];

    final ids = <int>[];
    for (final i in paradasIds) {
      if (!ids.contains(i)) ids.add(i);
    }
    if (ids.length < paradasIds.length) {
      avisos.add('${paradasIds.length - ids.length} parada(s) repetida(s) ignorada(s)');
    }

    final linhas = {for (final e in await _db.obterEnderecosPorIds(ids)) e.id: e};
    final faltando = ids.where((i) => !linhas.containsKey(i)).toList();
    if (faltando.isNotEmpty) {
      avisos.add('${faltando.length} id(s) não encontrado(s)');
    }
    final validos = ids.where((i) => linhas[i]?.temCoordenada ?? false).toList();
    final semCoordenada = ids.where((i) => linhas.containsKey(i) && !linhas[i]!.temCoordenada).length;
    if (semCoordenada > 0) {
      avisos.add('$semCoordenada parada(s) sem coordenada ficaram de fora');
    }
    if (validos.isEmpty) {
      throw StateError('Nenhuma parada com coordenada utilizável');
    }

    final paradas = [for (final i in validos) linhas[i]!];
    final temPartida = partida != null;

    // Pontos na ordem: [partida?, paradas...]
    final pontos = <LatLng>[
      if (partida != null) partida,
      for (final e in paradas) LatLng(e.lat!, e.lon!),
    ];

    List<List<double>>? matriz;
    var modoDistancia = 'linha reta (Haversine), não pela malha viária';

    final malha = usarRuas ? await _carregarMalha() : null;
    if (usarRuas && malha == null) {
      avisos.add('Malha viária indisponível: usei linha reta.');
    }
    if (malha != null) {
      final nos = <int?>[
        if (partida != null) malha.noMaisProximo(partida.latitude, partida.longitude),
        for (final e in paradas) e.malhaNo,
      ];
      final semEncaixe = paradas.where((e) => e.malhaNo == null).length;
      if (semEncaixe > 0) {
        avisos.add('$semEncaixe parada(s) sem encaixe na malha usaram linha reta');
      }

      if (nos.every((n) => n != null)) {
        final (real, paresSemCaminho) = malha.matriz(nos.cast<int>());
        // Recuo do endereço até o nó de rua (vizinhos no mesmo nó não ficam a zero)
        final recuo = <double>[
          if (partida != null) 0.0,
          for (final e in paradas) math.min(_tetoRecuo, e.malhaMetros ?? 0.0),
        ];
        final n = nos.length;
        matriz = List.generate(n, (i) => List.generate(n, (j) {
              if (i == j) return 0.0;
              return real[i][j] + recuo[i] + recuo[j];
            }));
        modoDistancia = 'malha viária local (OpenStreetMap), respeita mão única, '
            'mais o recuo de cada endereço até a rua';
        if (paresSemCaminho > 0) {
          avisos.add('$paresSemCaminho par(es) sem caminho no grafo usaram linha reta com penalidade');
        }
      }
    }

    final m = matriz ?? RotaOptimizer.construirMatriz(pontos);

    // Quanto custaria na ordem enviada
    var metrosEnviados = 0.0;
    for (var k = 0; k < pontos.length - 1; k++) {
      metrosEnviados += m[k][k + 1];
    }
    if (voltarAoInicio && pontos.length > 1) metrosEnviados += m[pontos.length - 1][0];

    final r = RotaOptimizer.otimizar(
      [for (final e in paradas) LatLng(e.lat!, e.lon!)],
      inicio: partida,
      fechar: voltarAoInicio,
      matrizPronta: m,
    );
    if (!r.refinado && paradas.length > 1) {
      avisos.add('Muitas paradas: a ordem vem do vizinho mais próximo, sem refinamento.');
    }

    final sequencia = <EnderecoNaRota>[];
    for (var posicao = 0; posicao < r.ordem.length; posicao++) {
      double? perna;
      if (temPartida) {
        perna = posicao < r.pernas.length ? r.pernas[posicao] : null;
      } else {
        perna = posicao >= 1 ? r.pernas[posicao - 1] : null;
      }
      sequencia.add(EnderecoNaRota(
        endereco: paradas[r.ordem[posicao]],
        posicao: posicao + 1,
        metrosDaAnterior: perna,
      ));
    }

    final metrosRetorno = voltarAoInicio && r.pernas.isNotEmpty ? r.pernas.last : null;
    final economia = math.max(0.0, metrosEnviados - r.metros);
    final segundos = r.metros / 1000.0 / velocidadeMediaKmh * 3600.0 +
        segundosPorParada * math.max(0, r.ordem.length - 1);

    return RotaOtimizada(
      paradas: sequencia,
      totalMetros: r.metros,
      totalMinutos: (segundos / 60).round(),
      metrosOrdemEnviada: metrosEnviados,
      economiaMetros: economia,
      economiaPercentual: metrosEnviados > 0 ? economia / metrosEnviados * 100 : 0.0,
      voltarAoInicio: voltarAoInicio,
      metrosRetorno: metrosRetorno,
      partida: partida,
      metodo: r.metodo,
      distancia: modoDistancia,
      pelaMalha: matriz != null,
      avisos: avisos,
    );
  }

  /// Mesmo contrato de POST /rota/trajeto
  Future<TrajetoDetalhado> trajeto({
    required List<int> paradasIds,
    LatLng? partida,
    bool manobras = true,
  }) async {
    final malha = await _carregarMalha();
    if (malha == null) {
      throw StateError('Malha viária não disponível no banco do app');
    }
    final avisos = <String>[];

    final ids = <int>[];
    for (final i in paradasIds) {
      if (!ids.contains(i)) ids.add(i);
    }
    final linhas = {for (final e in await _db.obterEnderecosPorIds(ids)) e.id: e};

    final pontos = <_Ponto>[];
    if (partida != null) {
      final no = malha.noMaisProximo(partida.latitude, partida.longitude);
      if (no == null) throw StateError('Não achei rua perto da partida');
      pontos.add(_Ponto('Sua posição', no, partida, null));
    }
    for (final i in ids) {
      final e = linhas[i];
      if (e == null) continue;
      if (e.malhaNo == null || !malha.temNo(e.malhaNo!)) {
        avisos.add('parada $i sem encaixe na malha, ficou de fora');
        continue;
      }
      final pos = e.temCoordenada ? LatLng(e.lat!, e.lon!) : malha.coordenada(e.malhaNo!)!;
      pontos.add(_Ponto(e.enderecoDisplay, e.malhaNo!, pos, i));
    }
    if (pontos.length < 2) {
      throw StateError('Preciso de pelo menos dois pontos (ative o GPS ou adicione outra parada)');
    }

    final trechos = <TrechoTrajeto>[];
    var totalMetros = 0.0;
    var totalSegundos = 0.0;

    for (var k = 0; k < pontos.length - 1; k++) {
      final a = pontos[k];
      final b = pontos[k + 1];
      final c = malha.caminho(a.no, b.no);
      if (c == null) {
        avisos.add("sem caminho de '${a.rotulo}' até '${b.rotulo}'");
        trechos.add(TrechoTrajeto(
          de: a.rotulo, para: b.rotulo, paraId: b.id,
          geometria: [a.pos, b.pos], manobras: const [], semCaminho: true,
        ));
        continue;
      }

      final (sequencia, metros, segundos) = c;
      final geometria = malha.geometria(sequencia);
      final ruas = <String?>[
        for (var x = 0; x < sequencia.length - 1; x++)
          malha.nomeAresta(sequencia[x], sequencia[x + 1]),
      ];

      final lista = manobras
          ? GeradorManobras.gerar(
              geometria,
              ruas,
              destino: b.rotulo,
              partida: ruas.firstWhereOrNull((n) => n != null && n.isNotEmpty),
            )
          : <Manobra>[];

      totalMetros += metros;
      totalSegundos += segundos;
      trechos.add(TrechoTrajeto(
        de: a.rotulo, para: b.rotulo, paraId: b.id,
        metros: metros, segundos: segundos.round(),
        geometria: geometria, manobras: lista, semCaminho: false,
      ));
    }

    return TrajetoDetalhado(
      trechos: trechos,
      totalMetros: totalMetros,
      totalMinutos: (totalSegundos / 60).round(),
      paradas: pontos.length - (partida != null ? 1 : 0),
      distancia: 'malha viária local (OpenStreetMap), respeita mão única',
      encaixe: 'O trajeto vai até o nó de rua mais próximo do endereço, não até o portão.',
      avisos: avisos,
    );
  }
}

class _Ponto {
  final String rotulo;
  final int no;
  final LatLng pos;
  final int? id;
  _Ponto(this.rotulo, this.no, this.pos, this.id);
}

/// Grafo viário em memória, com índices compactos para o Dijkstra.
class _Malha {
  static const double _penalidadeSemCaminho = 1.6;
  static const double _limiteMetros = 60000.0;

  final Map<int, int> _indice; // id do nó -> índice
  final List<int> _ids;
  final Float64List _lat;
  final Float64List _lon;
  // Adjacência: para cada índice, listas paralelas de vizinho/metros/segundos/nome
  final List<List<int>> _viz;
  final List<List<double>> _metros;
  final List<List<double>> _segundos;
  final List<List<int>> _nome;
  final List<String?> _nomes;

  _Malha(this._indice, this._ids, this._lat, this._lon, this._viz, this._metros,
      this._segundos, this._nome, this._nomes);

  static Future<_Malha?> carregar(DatabaseService db) async {
    final con = await db.database;
    final List<Map<String, Object?>> nos;
    final List<Map<String, Object?>> arestas;
    try {
      nos = await con.rawQuery('SELECT id, lat, lon FROM malha_nos');
      arestas = await con.rawQuery('SELECT de, para, metros, segundos, nome FROM malha_arestas');
    } catch (_) {
      return null; // banco sem malha
    }
    if (arestas.isEmpty) return null;

    final n = nos.length;
    final indice = <int, int>{};
    final ids = List<int>.filled(n, 0);
    final lat = Float64List(n);
    final lon = Float64List(n);
    for (var i = 0; i < n; i++) {
      final r = nos[i];
      final id = (r['id'] as num).toInt();
      indice[id] = i;
      ids[i] = id;
      lat[i] = (r['lat'] as num).toDouble();
      lon[i] = (r['lon'] as num).toDouble();
    }

    final viz = List.generate(n, (_) => <int>[]);
    final metros = List.generate(n, (_) => <double>[]);
    final segundos = List.generate(n, (_) => <double>[]);
    final nome = List.generate(n, (_) => <int>[]);
    final nomes = <String?>[null];
    final indiceNome = <String?, int>{null: 0};

    for (final r in arestas) {
      final de = indice[(r['de'] as num).toInt()];
      final para = indice[(r['para'] as num).toInt()];
      if (de == null || para == null) continue;
      final nm = r['nome'] as String?;
      final k = indiceNome.putIfAbsent(nm, () {
        nomes.add(nm);
        return nomes.length - 1;
      });
      viz[de].add(para);
      metros[de].add((r['metros'] as num).toDouble());
      segundos[de].add(((r['segundos'] as num?) ?? 0).toDouble());
      nome[de].add(k);
    }

    return _Malha(indice, ids, lat, lon, viz, metros, segundos, nome, nomes);
  }

  bool temNo(int id) => _indice.containsKey(id);

  LatLng? coordenada(int id) {
    final i = _indice[id];
    return i == null ? null : LatLng(_lat[i], _lon[i]);
  }

  int? noMaisProximo(double lat, double lon) {
    var melhor = -1;
    var melhorD = double.infinity;
    for (var i = 0; i < _ids.length; i++) {
      final d = RotaOptimizer.haversine(lat, lon, _lat[i], _lon[i]);
      if (d < melhorD) {
        melhorD = d;
        melhor = i;
      }
    }
    return melhor < 0 ? null : _ids[melhor];
  }

  /// Dijkstra por metros a partir do índice `origem`, parando quando todos os
  /// `destinos` (índices) forem fechados. Devolve (metros, anterior).
  (Map<int, double>, Map<int, int>) _dijkstra(int origem, Set<int>? destinos) {
    final pendentes = destinos == null ? null : (Set<int>.of(destinos)..remove(origem));
    final custo = <int, double>{origem: 0.0};
    final anterior = <int, int>{};
    final fechados = <int>{};
    final fila = HeapPriorityQueue<(double, int)>((a, b) => a.$1.compareTo(b.$1));
    fila.add((0.0, origem));

    while (fila.isNotEmpty) {
      final (c, no) = fila.removeFirst();
      if (!fechados.add(no)) continue;

      if (pendentes != null) {
        pendentes.remove(no);
        if (pendentes.isEmpty) break;
      }
      if (c > _limiteMetros) continue;

      final vs = _viz[no];
      final ms = _metros[no];
      for (var k = 0; k < vs.length; k++) {
        final v = vs[k];
        final novo = c + ms[k];
        if (novo < (custo[v] ?? double.infinity)) {
          custo[v] = novo;
          anterior[v] = no;
          fila.add((novo, v));
        }
      }
    }
    return (custo, anterior);
  }

  /// Caminho por ids de nó: (sequência de ids, metros, segundos)
  (List<int>, double, double)? caminho(int origemId, int destinoId) {
    final o = _indice[origemId];
    final d = _indice[destinoId];
    if (o == null || d == null) return null;
    if (o == d) return ([origemId], 0.0, 0.0);

    final (metros, anterior) = _dijkstra(o, {d});
    if (!metros.containsKey(d)) return null;

    final seq = <int>[d];
    var atual = d;
    while (atual != o) {
      atual = anterior[atual]!;
      seq.add(atual);
    }
    final ordem = seq.reversed.toList();

    var segundos = 0.0;
    for (var k = 0; k < ordem.length - 1; k++) {
      final a = ordem[k];
      final vs = _viz[a];
      for (var x = 0; x < vs.length; x++) {
        if (vs[x] == ordem[k + 1]) {
          segundos += _segundos[a][x];
          break;
        }
      }
    }
    return ([for (final i in ordem) _ids[i]], metros[d]!, segundos);
  }

  String? nomeAresta(int deId, int paraId) {
    final de = _indice[deId];
    final para = _indice[paraId];
    if (de == null || para == null) return null;
    final vs = _viz[de];
    for (var x = 0; x < vs.length; x++) {
      if (vs[x] == para) return _nomes[_nome[de][x]];
    }
    return null;
  }

  List<LatLng> geometria(List<int> sequencia) => [
        for (final id in sequencia)
          if (_indice[id] case final i?) LatLng(_lat[i], _lon[i]),
      ];

  /// Matriz n×n de metros reais entre os nós (ids). Simétrica pela média,
  /// como no backend. Devolve também quantos pares ficaram sem caminho.
  (List<List<double>>, int) matriz(List<int> nosIds) {
    final n = nosIds.length;
    final d = List.generate(n, (_) => List<double>.filled(n, 0.0));
    final idx = [for (final id in nosIds) _indice[id]];
    final unicos = idx.whereType<int>().toSet();
    final cache = <int, Map<int, double>>{};
    for (final u in unicos) {
      cache[u] = _dijkstra(u, unicos).$1;
    }

    var semCaminho = 0;
    for (var i = 0; i < n; i++) {
      for (var j = 0; j < n; j++) {
        if (i == j) continue;
        final a = idx[i];
        final b = idx[j];
        double? valor = (a != null && b != null) ? (a == b ? 0.0 : cache[a]?[b]) : null;
        if (valor == null) {
          if (a != null && b != null) {
            valor = RotaOptimizer.haversine(_lat[a], _lon[a], _lat[b], _lon[b]) *
                _penalidadeSemCaminho;
          } else {
            valor = 0.0;
          }
          semCaminho++;
        }
        d[i][j] = valor;
      }
    }

    for (var i = 0; i < n; i++) {
      for (var j = i + 1; j < n; j++) {
        final media = (d[i][j] + d[j][i]) / 2;
        d[i][j] = media;
        d[j][i] = media;
      }
    }
    return (d, semCaminho ~/ 2);
  }
}

/// Porte de rotas/manobras.py: deduz instruções curva a curva da geometria.
class GeradorManobras {
  static const double _anguloMinimo = 25.0;
  static const double _anguloLeve = 45.0;
  static const double _anguloForte = 120.0;
  static const double _anguloRetorno = 155.0;
  static const double _metrosMinimos = 12.0;
  static const double _janelaCurvaM = 40.0;
  static const double _descarteCurvaM = 70.0;

  static double rumo(double lat1, double lon1, double lat2, double lon2) {
    final p1 = lat1 * math.pi / 180;
    final p2 = lat2 * math.pi / 180;
    final dl = (lon2 - lon1) * math.pi / 180;
    final y = math.sin(dl) * math.cos(p2);
    final x = math.cos(p1) * math.sin(p2) - math.sin(p1) * math.cos(p2) * math.cos(dl);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  static double diferencaAngular(double de, double para) {
    return (para - de + 540) % 360 - 180;
  }

  static String _classificar(double angulo) {
    final a = angulo.abs();
    if (a >= _anguloRetorno) return 'retorno';
    if (a < _anguloMinimo) return 'seguir';
    return angulo > 0 ? 'direita' : 'esquerda';
  }

  static String _frase(String tipo, double angulo, String? rua) {
    final a = angulo.abs();
    final onde = rua != null ? ' na $rua' : '';
    if (tipo == 'retorno') return 'Faça o retorno$onde';
    if (tipo == 'seguir') return rua != null ? 'Siga em frente$onde' : 'Siga em frente';
    final lado = angulo > 0 ? 'direita' : 'esquerda';
    if (a < _anguloLeve) return 'Mantenha-se à $lado$onde';
    if (a < _anguloForte) return 'Vire à $lado$onde';
    return 'Vire acentuadamente à $lado$onde';
  }

  static String _complemento(_ManobraMutavel m) {
    final onde = m.rua != null ? ' na ${m.rua}' : '';
    if (m.tipo == 'retorno') return 'faça o retorno$onde';
    if (m.tipo == 'seguir') return 'siga em frente$onde';
    final lado = m.angulo > 0 ? 'direita' : 'esquerda';
    if (m.angulo.abs() < _anguloLeve) return 'mantenha-se à $lado$onde';
    return 'à $lado$onde';
  }

  static List<_ManobraMutavel> _juntarProximas(List<_ManobraMutavel> manobras) {
    if (manobras.length < 3) return manobras;
    const curvas = {'direita', 'esquerda', 'retorno', 'seguir'};
    final saida = [manobras.first];
    for (final atual in manobras.skip(1)) {
      final anterior = saida.last;
      final podeJuntar = curvas.contains(anterior.tipo) &&
          curvas.contains(atual.tipo) &&
          anterior.metros < _janelaCurvaM &&
          !anterior.texto.contains(' e em seguida ');
      if (podeJuntar) {
        anterior.texto = '${anterior.texto} e em seguida ${_complemento(atual)}';
        anterior.metros += atual.metros;
        anterior.angulo += atual.angulo;
        continue;
      }
      saida.add(atual);
    }
    return saida;
  }

  static List<Manobra> gerar(
    List<LatLng> coordenadas,
    List<String?> ruas, {
    String? destino,
    String? partida,
  }) {
    final n = coordenadas.length;
    if (n < 2) return [];

    // Rua vazia conta como sem nome
    final nomes = <String?>[
      for (var k = 0; k < n - 1; k++)
        k < ruas.length && (ruas[k]?.isNotEmpty ?? false) ? ruas[k] : null,
    ];
    final rumos = [
      for (var k = 0; k < n - 1; k++)
        rumo(coordenadas[k].latitude, coordenadas[k].longitude,
            coordenadas[k + 1].latitude, coordenadas[k + 1].longitude),
    ];
    final distancias = [
      for (var k = 0; k < n - 1; k++)
        RotaOptimizer.haversine(coordenadas[k].latitude, coordenadas[k].longitude,
            coordenadas[k + 1].latitude, coordenadas[k + 1].longitude),
    ];
    double soma(int de, int ate) {
      var t = 0.0;
      for (var k = de; k < ate && k < distancias.length; k++) {
        t += distancias[k];
      }
      return t;
    }

    final manobras = <_ManobraMutavel>[
      _ManobraMutavel(
        tipo: 'partir',
        texto: partida != null ? 'Siga pela $partida' : 'Siga em frente',
        pos: coordenadas.first,
        rua: nomes.first ?? partida,
        indiceNo: 0,
      ),
    ];

    var acumulado = 0.0;
    var metrosAcumulados = 0.0;
    var inicioTrecho = 0;

    for (var k = 1; k < n - 1; k++) {
      final giro = diferencaAngular(rumos[k - 1], rumos[k]);
      final mudouRua = nomes[k] != nomes[k - 1];
      final segmentoCurto = distancias[k - 1] < _metrosMinimos;

      acumulado += giro;
      metrosAcumulados += distancias[k - 1];

      if (metrosAcumulados > _descarteCurvaM && !mudouRua) {
        acumulado = giro;
        metrosAcumulados = distancias[k - 1];
        if (giro.abs() < _anguloMinimo) continue;
      }

      final esquinaFechada = giro.abs() >= _anguloMinimo;
      final curvaConcentrada =
          acumulado.abs() >= _anguloMinimo && metrosAcumulados <= _janelaCurvaM;
      final trocaDeVia = mudouRua && !segmentoCurto;
      if (!(esquinaFechada || curvaConcentrada || trocaDeVia)) continue;

      final anguloManobra =
          esquinaFechada && giro.abs() >= acumulado.abs() ? giro : acumulado;
      final tipo = _classificar(anguloManobra);
      if (tipo == 'seguir' && !mudouRua) {
        acumulado = 0.0;
        metrosAcumulados = 0.0;
        continue;
      }

      final percorrido = soma(inicioTrecho, k);
      if (percorrido < _metrosMinimos && manobras.last.tipo != 'partir') {
        manobras.last.metros += percorrido;
        acumulado = 0.0;
        metrosAcumulados = 0.0;
        inicioTrecho = k;
        continue;
      }

      manobras.last.metros += percorrido;
      manobras.add(_ManobraMutavel(
        tipo: tipo,
        texto: _frase(tipo, anguloManobra, nomes[k]),
        pos: coordenadas[k],
        rua: nomes[k],
        angulo: anguloManobra,
        indiceNo: k,
      ));
      acumulado = 0.0;
      metrosAcumulados = 0.0;
      inicioTrecho = k;
    }

    manobras.last.metros += soma(inicioTrecho, distancias.length);
    manobras.add(_ManobraMutavel(
      tipo: 'chegar',
      texto: destino != null ? 'Chegou em $destino' : 'Chegou ao destino',
      pos: coordenadas.last,
      rua: nomes.isNotEmpty ? nomes.last : null,
      indiceNo: n - 1,
    ));

    return [for (final m in _juntarProximas(manobras)) m.paraManobra()];
  }
}

class _ManobraMutavel {
  String tipo;
  String texto;
  double metros = 0.0;
  final LatLng pos;
  final String? rua;
  double angulo;
  final int indiceNo;

  _ManobraMutavel({
    required this.tipo,
    required this.texto,
    required this.pos,
    this.rua,
    this.angulo = 0.0,
    required this.indiceNo,
  });

  Manobra paraManobra() => Manobra(
        tipo: TipoManobra.values.firstWhere((t) => t.name == tipo,
            orElse: () => TipoManobra.seguir),
        texto: texto,
        metros: metros,
        posicao: pos,
        nomeRua: rua,
        angulo: angulo,
        indiceNo: indiceNo,
      );
}
