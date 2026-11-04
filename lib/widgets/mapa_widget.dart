import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:rotas_app/models/endereco.dart';
import 'package:rotas_app/models/manobra.dart';

/// Widget de mapa com flutter_map (OpenStreetMap)
class MapaWidget extends StatefulWidget {
  final LatLng? centro;
  final double zoom;
  final List<Endereco>? enderecos;
  final List<LatLng>? trajeto;
  final List<Manobra>? manobras;
  final Endereco? enderecoSelecionado;
  final LatLng? posicaoUsuario;
  final Function(Endereco)? onEnderecoTap;
  final Function(LatLng)? onMapTap;
  final bool mostrarControles;

  const MapaWidget({
    super.key,
    this.centro,
    this.zoom = 15.0,
    this.enderecos,
    this.trajeto,
    this.manobras,
    this.enderecoSelecionado,
    this.posicaoUsuario,
    this.onEnderecoTap,
    this.onMapTap,
    this.mostrarControles = true,
  });

  @override
  State<MapaWidget> createState() => _MapaWidgetState();
}

class _MapaWidgetState extends State<MapaWidget> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void didUpdateWidget(MapaWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Se mudou o centro, move o mapa
    if (widget.centro != oldWidget.centro && widget.centro != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(widget.centro!, widget.zoom);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final centro = widget.centro ??
        widget.posicaoUsuario ??
        const LatLng(-20.6456, -50.3723); // General Salgado

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: centro,
            initialZoom: widget.zoom,
            minZoom: 5.0,
            maxZoom: 19.0,
            onTap: (_, position) {
              if (widget.onMapTap != null) {
                widget.onMapTap!(position);
              }
            },
          ),
          children: [
            // Camada de tiles (OpenStreetMap)
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.rotas.rotas_app',
              maxZoom: 19,
            ),

            // Camada de trajeto (linha da rota)
            if (widget.trajeto != null && widget.trajeto!.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: widget.trajeto!,
                    strokeWidth: 4.0,
                    color: Colors.blue,
                  ),
                ],
              ),

            // Camada de marcadores de manobras
            if (widget.manobras != null && widget.manobras!.isNotEmpty)
              MarkerLayer(
                markers: widget.manobras!
                    .asMap()
                    .entries
                    .map((entry) => _buildMarcadorManobra(entry.key, entry.value))
                    .toList(),
              ),

            // Camada de marcadores de endereços
            if (widget.enderecos != null && widget.enderecos!.isNotEmpty)
              MarkerLayer(
                markers: widget.enderecos!
                    .where((e) => e.temCoordenada)
                    .map(_buildMarcadorEndereco)
                    .toList(),
              ),

            // Marcador da posição do usuário
            if (widget.posicaoUsuario != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: widget.posicaoUsuario!,
                    width: 50,
                    height: 50,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.3),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.blue, width: 3),
                      ),
                      child: const Icon(
                        Icons.navigation,
                        color: Colors.blue,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),

            // Atribuição exigida pela política de uso do OpenStreetMap
            const SimpleAttributionWidget(
              source: Text('OpenStreetMap contributors'),
            ),
          ],
        ),

        // Controles do mapa
        if (widget.mostrarControles)
          Positioned(
            right: 16,
            bottom: 100,
            child: Column(
              children: [
                // Botão de zoom in
                FloatingActionButton.small(
                  heroTag: 'zoom_in',
                  onPressed: () {
                    final zoom = _mapController.camera.zoom;
                    _mapController.move(
                      _mapController.camera.center,
                      zoom + 1,
                    );
                  },
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                // Botão de zoom out
                FloatingActionButton.small(
                  heroTag: 'zoom_out',
                  onPressed: () {
                    final zoom = _mapController.camera.zoom;
                    _mapController.move(
                      _mapController.camera.center,
                      zoom - 1,
                    );
                  },
                  child: const Icon(Icons.remove),
                ),
                const SizedBox(height: 8),
                // Botão de centralizar na posição do usuário
                if (widget.posicaoUsuario != null)
                  FloatingActionButton.small(
                    heroTag: 'center_user',
                    onPressed: () {
                      _mapController.move(widget.posicaoUsuario!, 16);
                    },
                    child: const Icon(Icons.my_location),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  /// Constrói marcador de endereço
  Marker _buildMarcadorEndereco(Endereco endereco) {
    final selecionado = widget.enderecoSelecionado?.id == endereco.id;
    final cor = _corPorOrigem(endereco.origem);

    return Marker(
      point: LatLng(endereco.lat!, endereco.lon!),
      width: selecionado ? 60 : 40,
      height: selecionado ? 60 : 40,
      child: GestureDetector(
        onTap: () {
          if (widget.onEnderecoTap != null) {
            widget.onEnderecoTap!(endereco);
          }
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Halo pulsante para endereço selecionado
            if (selecionado)
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: cor.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
              ),
            // Marcador principal
            Container(
              width: selecionado ? 44 : 32,
              height: selecionado ? 44 : 32,
              decoration: BoxDecoration(
                color: cor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selecionado ? Colors.white : cor.withOpacity(0.5),
                  width: selecionado ? 3 : 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  _iconeParaEspecie(endereco.especie),
                  color: Colors.white,
                  size: selecionado ? 24 : 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Constrói marcador de manobra
  Marker _buildMarcadorManobra(int indice, Manobra manobra) {
    return Marker(
      point: manobra.posicao,
      width: 32,
      height: 32,
      child: Container(
        decoration: BoxDecoration(
          color: _corParaTipoManobra(manobra.tipo),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Center(
          child: Text(
            '${indice + 1}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  /// Cor baseada na origem do endereço
  Color _corPorOrigem(String origem) {
    switch (origem) {
      case 'cnefe':
        return Colors.blue; // Coordenada do recenseador
      case 'manual':
        return Colors.green; // Verificado em campo
      case 'interpolado':
        return Colors.orange; // Estimado
      default:
        return Colors.grey;
    }
  }

  /// Ícone baseado na espécie
  IconData _iconeParaEspecie(int? especie) {
    switch (especie) {
      case 1: // Domicílio
        return Icons.home;
      case 2: // Estabelecimento
        return Icons.business;
      case 3: // Estabelecimento agropecuário
        return Icons.agriculture;
      default:
        return Icons.location_on;
    }
  }

  /// Cor baseada no tipo de manobra
  Color _corParaTipoManobra(TipoManobra tipo) {
    switch (tipo) {
      case TipoManobra.partir:
        return Colors.green;
      case TipoManobra.chegar:
        return Colors.red;
      case TipoManobra.esquerda:
      case TipoManobra.direita:
        return Colors.orange;
      case TipoManobra.retorno:
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }
}
