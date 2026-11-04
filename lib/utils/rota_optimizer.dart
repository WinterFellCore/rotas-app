import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

/// Algoritmo de otimização de rotas (TSP)
/// Portado do rotas/rota.py
class RotaOptimizer {
  static const double _raioTerraM = 6371000.0;
  static const int _maxParadasRefino = 300;

  /// Calcula distância Haversine entre dois pontos
  static double haversine(double lat1, double lon1, double lat2, double lon2) {
    final p1 = _grausParaRadianos(lat1);
    final p2 = _grausParaRadianos(lat2);
    final dp = p2 - p1;
    final dl = _grausParaRadianos(lon2 - lon1);

    final a = math.pow(math.sin(dp / 2), 2) +
        math.cos(p1) * math.cos(p2) * math.pow(math.sin(dl / 2), 2);

    return 2 * _raioTerraM * math.asin(math.sqrt(a));
  }

  static double _grausParaRadianos(double graus) {
    return graus * math.pi / 180.0;
  }

  /// Constrói matriz de distâncias
  static List<List<double>> construirMatriz(List<LatLng> pontos) {
    final n = pontos.length;
    final matriz = List.generate(n, (_) => List.filled(n, 0.0));

    for (int i = 0; i < n; i++) {
      for (int j = i + 1; j < n; j++) {
        final dist = haversine(
          pontos[i].latitude,
          pontos[i].longitude,
          pontos[j].latitude,
          pontos[j].longitude,
        );
        matriz[i][j] = dist;
        matriz[j][i] = dist;
      }
    }

    return matriz;
  }

  /// Calcula custo total de uma ordem
  static double calcularCusto(
    List<int> ordem,
    List<List<double>> matriz,
    bool fechar,
  ) {
    double total = 0.0;

    for (int k = 0; k < ordem.length - 1; k++) {
      total += matriz[ordem[k]][ordem[k + 1]];
    }

    if (fechar && ordem.length > 1) {
      total += matriz[ordem.last][ordem.first];
    }

    return total;
  }

  /// Algoritmo do vizinho mais próximo
  static List<int> vizinhoMaisProximo(
    List<List<double>> matriz, {
    int inicio = 0,
  }) {
    final n = matriz.length;
    if (n == 0) return [];

    final visitado = List.filled(n, false);
    final ordem = <int>[inicio];
    visitado[inicio] = true;
    int atual = inicio;

    for (int i = 0; i < n - 1; i++) {
      int melhor = -1;
      double melhorDist = double.infinity;

      for (int j = 0; j < n; j++) {
        if (!visitado[j] && matriz[atual][j] < melhorDist) {
          melhor = j;
          melhorDist = matriz[atual][j];
        }
      }

      if (melhor < 0) break;

      visitado[melhor] = true;
      ordem.add(melhor);
      atual = melhor;
    }

    return ordem;
  }

  /// Calcula ganho do 2-opt
  static double _ganho2Opt(
    List<int> ordem,
    List<List<double>> matriz,
    int i,
    int j,
    bool fechar,
  ) {
    final n = ordem.length;
    final a = ordem[i - 1];
    final b = ordem[i];
    final c = ordem[j];

    if (j + 1 < n) {
      final e = ordem[j + 1];
      return (matriz[a][c] + matriz[b][e]) - (matriz[a][b] + matriz[c][e]);
    } else if (fechar) {
      final e = ordem[0];
      return (matriz[a][c] + matriz[b][e]) - (matriz[a][b] + matriz[c][e]);
    } else {
      return matriz[a][c] - matriz[a][b];
    }
  }

  /// Algoritmo 2-opt (remove cruzamentos)
  static List<int> doisOpt(
    List<int> ordem,
    List<List<double>> matriz,
    bool fechar, {
    int maxPasses = 60,
  }) {
    final result = List<int>.from(ordem);
    final n = result.length;

    if (n < 4) return result;

    for (int pass = 0; pass < maxPasses; pass++) {
      bool melhorou = false;

      for (int i = 1; i < n - 1; i++) {
        for (int j = i + 1; j < n; j++) {
          if (_ganho2Opt(result, matriz, i, j, fechar) < -1e-9) {
            // Inverte o trecho [i..j]
            final sublist = result.sublist(i, j + 1).reversed.toList();
            result.replaceRange(i, j + 1, sublist);
            melhorou = true;
          }
        }
      }

      if (!melhorou) break;
    }

    return result;
  }

  /// Algoritmo Or-opt (move trechos curtos)
  static List<int> orOpt(
    List<int> ordem,
    List<List<double>> matriz,
    bool fechar, {
    int maxTrecho = 3,
    int maxPasses = 30,
  }) {
    final result = List<int>.from(ordem);
    final n = result.length;

    if (n < 4) return result;

    const eps = 1e-9;

    for (int pass = 0; pass < maxPasses; pass++) {
      bool melhorou = false;

      for (int tamanho = 1; tamanho <= math.min(maxTrecho, n - 2); tamanho++) {
        for (int i = 1; i <= n - tamanho; i++) {
          final fim = i + tamanho - 1;
          final trecho = result.sublist(i, fim + 1);
          final primeiro = trecho.first;
          final ultimo = trecho.last;

          final anterior = result[i - 1];
          double ganhoRemocao;

          if (fim + 1 < n) {
            final seguinte = result[fim + 1];
            ganhoRemocao = matriz[anterior][primeiro] +
                matriz[ultimo][seguinte] -
                matriz[anterior][seguinte];
          } else if (fechar) {
            final seguinte = result[0];
            ganhoRemocao = matriz[anterior][primeiro] +
                matriz[ultimo][seguinte] -
                matriz[anterior][seguinte];
          } else {
            ganhoRemocao = matriz[anterior][primeiro];
          }

          final resto = [...result.sublist(0, i), ...result.sublist(fim + 1)];
          final m = resto.length;

          for (int k = 1; k <= m; k++) {
            if (k == i) continue;

            final a = resto[k - 1];
            double custoInsercao;

            if (k < m) {
              final b = resto[k];
              final baseAb = matriz[a][b];
              final custoDireto =
                  matriz[a][primeiro] + matriz[ultimo][b] - baseAb;
              final custoInvertido =
                  matriz[a][ultimo] + matriz[primeiro][b] - baseAb;
              custoInsercao = math.min(custoDireto, custoInvertido);
            } else if (fechar) {
              final b = resto[0];
              final baseAb = matriz[a][b];
              final custoDireto =
                  matriz[a][primeiro] + matriz[ultimo][b] - baseAb;
              final custoInvertido =
                  matriz[a][ultimo] + matriz[primeiro][b] - baseAb;
              custoInsercao = math.min(custoDireto, custoInvertido);
            } else {
              custoInsercao =
                  math.min(matriz[a][primeiro], matriz[a][ultimo]);
            }

            if (custoInsercao - ganhoRemocao < -eps) {
              final inverter = k < m
                  ? matriz[a][ultimo] + matriz[primeiro][resto[k]] <
                      matriz[a][primeiro] + matriz[ultimo][resto[k]]
                  : matriz[a][ultimo] < matriz[a][primeiro];

              final pedaco = inverter ? trecho.reversed.toList() : trecho;
              result.clear();
              result.addAll([...resto.sublist(0, k), ...pedaco, ...resto.sublist(k)]);
              melhorou = true;
              break;
            }
          }

          if (melhorou) break;
        }
        if (melhorou) break;
      }

      if (!melhorou) break;
    }

    return result;
  }

  /// Otimiza a ordem das paradas
  static ResultadoOtimizacao otimizar(
    List<LatLng> paradas, {
    LatLng? inicio,
    bool fechar = false,
    bool refinar = true,
    // Matriz já calculada sobre [inicio?, ...paradas] (ex.: distância pelas
    // ruas). Sem ela usa linha reta.
    List<List<double>>? matrizPronta,
  }) {
    final n = paradas.length;

    if (n == 0) {
      return ResultadoOtimizacao(
        ordem: [],
        metros: 0.0,
        metrosInicial: 0.0,
        pernas: [],
        metodo: 'vazio',
        refinado: false,
      );
    }

    if (n == 1) {
      double dist = 0.0;
      if (inicio != null) {
        dist = matrizPronta != null
            ? matrizPronta[0][1]
            : haversine(
                inicio.latitude,
                inicio.longitude,
                paradas[0].latitude,
                paradas[0].longitude,
              );
        if (fechar) dist *= 2;
      }
      return ResultadoOtimizacao(
        ordem: [0],
        metros: dist,
        metrosInicial: dist,
        pernas: inicio != null ? [dist] : [],
        metodo: 'trivial',
        refinado: false,
      );
    }

    // Adiciona ponto de partida como índice 0
    final pontos = inicio != null ? [inicio, ...paradas] : paradas;
    final deslocamento = inicio != null ? 1 : 0;

    final matriz = matrizPronta ?? construirMatriz(pontos);
    var ordem = vizinhoMaisProximo(matriz, inicio: 0);
    final metrosInicial = calcularCusto(ordem, matriz, fechar);

    final refinado = refinar && pontos.length <= _maxParadasRefino;
    if (refinado) {
      ordem = doisOpt(ordem, matriz, fechar);
      ordem = orOpt(ordem, matriz, fechar);
      ordem = doisOpt(ordem, matriz, fechar); // Segunda passada
    }

    final metros = calcularCusto(ordem, matriz, fechar);

    // Calcula pernas
    final pernas = <double>[];
    for (int k = 0; k < ordem.length - 1; k++) {
      pernas.add(matriz[ordem[k]][ordem[k + 1]]);
    }
    if (fechar && ordem.length > 1) {
      pernas.add(matriz[ordem.last][ordem.first]);
    }

    // Remove âncora e reindexa
    final ordemFinal = deslocamento > 0
        ? ordem.where((i) => i >= deslocamento).map((i) => i - deslocamento).toList()
        : ordem;

    return ResultadoOtimizacao(
      ordem: ordemFinal,
      metros: metros,
      metrosInicial: metrosInicial,
      pernas: pernas,
      metodo: refinado ? 'vizinho+2opt+oropt' : 'vizinho',
      refinado: refinado,
    );
  }
}

/// Resultado da otimização
class ResultadoOtimizacao {
  final List<int> ordem;
  final double metros;
  final double metrosInicial;
  final List<double> pernas;
  final String metodo;
  final bool refinado;

  const ResultadoOtimizacao({
    required this.ordem,
    required this.metros,
    required this.metrosInicial,
    required this.pernas,
    required this.metodo,
    required this.refinado,
  });

  double get melhoria {
    if (metrosInicial <= 0) return 0.0;
    return math.max(0.0, (metrosInicial - metros) / metrosInicial);
  }
}
