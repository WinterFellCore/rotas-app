import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:rotas_app/models/endereco.dart';
import 'package:rotas_app/models/manobra.dart';

void main() {
  group('Endereco.fromMap', () {
    test('aceita inteiros em lat/lon e campos ausentes', () {
      final e = Endereco.fromMap({
        'id': 10,
        'lat': -20,
        'lon': '-50.37',
        'verificado': true,
      });

      expect(e.id, 10);
      expect(e.lat, -20.0);
      expect(e.lon, -50.37);
      expect(e.verificado, isTrue);
      expect(e.ativo, isTrue);
      expect(e.origem, 'cnefe');
    });

    test('falha sem id', () {
      expect(() => Endereco.fromMap({}), throwsFormatException);
    });
  });

  group('Manobra.textoComDistancia', () {
    Manobra manobra(String texto) => Manobra(
          tipo: TipoManobra.direita,
          texto: texto,
          metros: 0,
          posicao: const LatLng(0, 0),
          angulo: 0,
          indiceNo: 0,
        );

    test('inclui distância', () {
      expect(
        manobra('Vire à direita').textoComDistancia(200),
        'Em 200 metros, vire à direita',
      );
    });

    test('não quebra com texto vazio', () {
      expect(manobra('').textoComDistancia(200), 'Em 200 metros');
    });
  });
}
