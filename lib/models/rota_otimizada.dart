import 'package:rotas_app/models/endereco.dart';
import 'package:rotas_app/models/manobra.dart';
import 'package:latlong2/latlong.dart';

/// Resultado de otimização de rota
class RotaOtimizada {
  final List<EnderecoNaRota> paradas;
  final double totalMetros;
  final int totalMinutos;
  final double metrosOrdemEnviada;
  final double economiaMetros;
  final double economiaPercentual;
  final bool voltarAoInicio;
  final double? metrosRetorno;
  final LatLng? partida;
  final String metodo;
  final String distancia;
  final bool pelaMalha;
  final List<String> avisos;

  const RotaOtimizada({
    required this.paradas,
    required this.totalMetros,
    required this.totalMinutos,
    required this.metrosOrdemEnviada,
    required this.economiaMetros,
    required this.economiaPercentual,
    required this.voltarAoInicio,
    this.metrosRetorno,
    this.partida,
    required this.metodo,
    required this.distancia,
    required this.pelaMalha,
    required this.avisos,
  });

  factory RotaOtimizada.fromJson(Map<String, dynamic> json) {
    final ordensLista = json['ordem'] as List;
    final paradas = ordensLista
        .map((e) => EnderecoNaRota.fromJson(e as Map<String, dynamic>))
        .toList();

    LatLng? partidaPos;
    if (json['partida'] != null) {
      final p = json['partida'] as Map<String, dynamic>;
      partidaPos = LatLng(
        (p['lat'] as num).toDouble(),
        (p['lon'] as num).toDouble(),
      );
    }

    return RotaOtimizada(
      paradas: paradas,
      totalMetros: (json['total_metros'] as num).toDouble(),
      totalMinutos: json['total_minutos'] as int,
      metrosOrdemEnviada: (json['metros_na_ordem_enviada'] as num).toDouble(),
      economiaMetros: (json['economia_metros'] as num).toDouble(),
      economiaPercentual: (json['economia_percentual'] as num).toDouble(),
      voltarAoInicio: json['voltar_ao_inicio'] as bool,
      metrosRetorno: json['metros_retorno'] != null
          ? (json['metros_retorno'] as num).toDouble()
          : null,
      partida: partidaPos,
      metodo: json['metodo'] as String,
      distancia: json['distancia'] as String,
      pelaMalha: json['pela_malha'] as bool,
      avisos: (json['avisos'] as List).map((e) => e as String).toList(),
    );
  }
}

/// Endereço posicionado em uma rota otimizada
class EnderecoNaRota {
  final Endereco endereco;
  final int posicao;
  final double? metrosDaAnterior;

  const EnderecoNaRota({
    required this.endereco,
    required this.posicao,
    this.metrosDaAnterior,
  });

  factory EnderecoNaRota.fromJson(Map<String, dynamic> json) {
    return EnderecoNaRota(
      endereco: Endereco.fromMap(json),
      posicao: json['posicao'] as int,
      metrosDaAnterior: json['metros_da_anterior'] != null
          ? (json['metros_da_anterior'] as num).toDouble()
          : null,
    );
  }
}

/// Trajeto detalhado com manobras turn-by-turn
class TrajetoDetalhado {
  final List<TrechoTrajeto> trechos;
  final double totalMetros;
  final int totalMinutos;
  final int paradas;
  final String distancia;
  final String encaixe;
  final List<String> avisos;

  const TrajetoDetalhado({
    required this.trechos,
    required this.totalMetros,
    required this.totalMinutos,
    required this.paradas,
    required this.distancia,
    required this.encaixe,
    required this.avisos,
  });

  factory TrajetoDetalhado.fromJson(Map<String, dynamic> json) {
    final trechosLista = json['trechos'] as List;
    final trechos = trechosLista
        .map((e) => TrechoTrajeto.fromJson(e as Map<String, dynamic>))
        .toList();

    return TrajetoDetalhado(
      trechos: trechos,
      totalMetros: (json['total_metros'] as num).toDouble(),
      totalMinutos: json['total_minutos'] as int,
      paradas: json['paradas'] as int,
      distancia: json['distancia'] as String,
      encaixe: json['encaixe'] as String,
      avisos: (json['avisos'] as List).map((e) => e as String).toList(),
    );
  }

  /// Lista plana de todas as manobras
  List<Manobra> get todasManobras {
    return trechos.expand((t) => t.manobras).toList();
  }

  /// Geometria completa do trajeto (todas as coordenadas)
  List<LatLng> get geometriaCompleta {
    final pontos = <LatLng>[];
    for (final trecho in trechos) {
      for (final coord in trecho.geometria) {
        pontos.add(coord);
      }
    }
    return pontos;
  }
}

/// Trecho entre duas paradas
class TrechoTrajeto {
  final String de;
  final String para;
  final int? paraId;
  final double? metros;
  final int? segundos;
  final List<LatLng> geometria;
  final List<Manobra> manobras;
  final bool semCaminho;

  const TrechoTrajeto({
    required this.de,
    required this.para,
    this.paraId,
    this.metros,
    this.segundos,
    required this.geometria,
    required this.manobras,
    required this.semCaminho,
  });

  factory TrechoTrajeto.fromJson(Map<String, dynamic> json) {
    final geomLista = json['geometria'] as List;
    final geometria = geomLista
        .map((e) => LatLng(
              (e[0] as num).toDouble(),
              (e[1] as num).toDouble(),
            ))
        .toList();

    final manobrasLista = json['manobras'] as List? ?? [];
    final manobras = manobrasLista
        .map((e) => Manobra.fromJson(e as Map<String, dynamic>))
        .toList();

    return TrechoTrajeto(
      de: json['de'] as String,
      para: json['para'] as String,
      paraId: json['para_id'] as int?,
      metros: json['metros'] != null ? (json['metros'] as num).toDouble() : null,
      segundos: json['segundos'] as int?,
      geometria: geometria,
      manobras: manobras,
      semCaminho: json['sem_caminho'] as bool,
    );
  }
}
