import 'package:latlong2/latlong.dart';

/// Tipo de manobra na navegação turn-by-turn
enum TipoManobra {
  partir,
  seguir,
  esquerda,
  direita,
  retorno,
  chegar,
}

/// Instrução de manobra para navegação por voz
class Manobra {
  final TipoManobra tipo;
  final String texto;
  final double metros;
  final LatLng posicao;
  final String? nomeRua;
  final double angulo;
  final int indiceNo;

  const Manobra({
    required this.tipo,
    required this.texto,
    required this.metros,
    required this.posicao,
    this.nomeRua,
    required this.angulo,
    required this.indiceNo,
  });

  factory Manobra.fromJson(Map<String, dynamic> json) {
    return Manobra(
      tipo: _tipoFromString(json['tipo'] as String),
      texto: json['texto'] as String,
      metros: (json['metros'] as num).toDouble(),
      posicao: LatLng(
        (json['lat'] as num).toDouble(),
        (json['lon'] as num).toDouble(),
      ),
      nomeRua: json['rua'] as String?,
      angulo: (json['angulo'] as num).toDouble(),
      indiceNo: json['indice_no'] as int,
    );
  }

  static TipoManobra _tipoFromString(String tipo) {
    switch (tipo) {
      case 'partir':
        return TipoManobra.partir;
      case 'seguir':
        return TipoManobra.seguir;
      case 'esquerda':
        return TipoManobra.esquerda;
      case 'direita':
        return TipoManobra.direita;
      case 'retorno':
        return TipoManobra.retorno;
      case 'chegar':
        return TipoManobra.chegar;
      default:
        return TipoManobra.seguir;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'tipo': tipo.name,
      'texto': texto,
      'metros': metros,
      'lat': posicao.latitude,
      'lon': posicao.longitude,
      'rua': nomeRua,
      'angulo': angulo,
      'indice_no': indiceNo,
    };
  }

  /// Texto para anúncio de voz com distância
  String textoComDistancia(double metrosRestantes) {
    if (tipo == TipoManobra.partir || tipo == TipoManobra.chegar) {
      return texto;
    }

    final quando = _distanciaFalada(metrosRestantes);
    if (quando == 'agora') {
      return texto;
    }

    if (texto.isEmpty) {
      return quando;
    }

    // "Em 200 metros, vire à direita"
    final primeiraLetra = texto[0].toLowerCase();
    return '$quando, $primeiraLetra${texto.substring(1)}';
  }

  static String _distanciaFalada(double metros) {
    if (metros < 20) return 'agora';
    if (metros < 100) {
      final arredondado = (metros / 10).round() * 10;
      return 'Em $arredondado metros';
    }
    if (metros < 1000) {
      final arredondado = (metros / 50).round() * 50;
      return 'Em $arredondado metros';
    }
    final km = metros / 1000;
    if (km < 10) {
      return 'Em ${km.toStringAsFixed(1).replaceAll('.', ',')} quilômetros';
    }
    return 'Em ${km.round()} quilômetros';
  }
}
