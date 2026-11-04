import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:rotas_app/providers/config_provider.dart';
import 'package:rotas_app/providers/navegacao_provider.dart';
import 'package:rotas_app/providers/rota_provider.dart';
import 'package:rotas_app/widgets/mapa_widget.dart';

/// Tela de navegação turn-by-turn com voz
class NavegacaoScreen extends StatelessWidget {
  const NavegacaoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Navegação'),
      ),
      body: Consumer2<RotaProvider, NavegacaoProvider>(
        builder: (context, rotaProvider, navProvider, _) {
          // Verifica se tem trajeto carregado
          if (rotaProvider.trajetoDetalhado == null) {
            return _buildSemTrajeto(context, rotaProvider);
          }

          // Modo navegação ativa
          if (navProvider.navegando) {
            return _buildNavegando(context, rotaProvider, navProvider);
          }

          // Pronto para navegar
          return _buildProntoParaNavegar(context, rotaProvider, navProvider);
        },
      ),
    );
  }

  Widget _buildSemTrajeto(BuildContext context, RotaProvider rotaProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.navigation,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Carregue a rota primeiro',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Crie uma rota e otimize antes de navegar',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: rotaProvider.temParadas && !rotaProvider.isLoadingTrajeto
                  ? () async {
                      // Começa o trajeto onde você está (funciona sem internet)
                      final aqui = await _posicaoAtual();
                      await rotaProvider.carregarTrajeto(partida: aqui);
                      if (context.mounted && rotaProvider.erro != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(rotaProvider.erro!)),
                        );
                      }
                    }
                  : null,
              icon: rotaProvider.isLoadingTrajeto
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.route),
              label: Text(
                rotaProvider.isLoadingTrajeto
                    ? 'Carregando...'
                    : 'Carregar Trajeto',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProntoParaNavegar(
    BuildContext context,
    RotaProvider rotaProvider,
    NavegacaoProvider navProvider,
  ) {
    final trajeto = rotaProvider.trajetoDetalhado!;

    return Column(
      children: [
        // Mapa com o trajeto completo
        Expanded(
          child: MapaWidget(
            trajeto: trajeto.geometriaCompleta,
            manobras: trajeto.todasManobras,
            posicaoUsuario: navProvider.posicaoAtualLatLng,
          ),
        ),

        // Informações do trajeto
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildInfo(
                    context,
                    Icons.straighten,
                    '${(trajeto.totalMetros / 1000).toStringAsFixed(1)} km',
                    'Distância total',
                  ),
                  _buildInfo(
                    context,
                    Icons.timer,
                    '${trajeto.totalMinutos} min',
                    'Tempo estimado',
                  ),
                  _buildInfo(
                    context,
                    Icons.location_on,
                    '${trajeto.paradas}',
                    'Paradas',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Botão iniciar navegação
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: navProvider.iniciando
                      ? null
                      : () async {
                          final erro = await navProvider.iniciarNavegacao();
                          if (erro != null && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(erro)),
                            );
                          }
                        },
                  icon: navProvider.iniciando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow),
                  label: Text(
                    navProvider.iniciando ? 'Iniciando...' : 'Iniciar Navegação',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNavegando(
    BuildContext context,
    RotaProvider rotaProvider,
    NavegacaoProvider navProvider,
  ) {
    final trajeto = rotaProvider.trajetoDetalhado!;
    final manobraAtual = navProvider.manobraAtual;

    return Column(
      children: [
        // Mapa com posição atual
        Expanded(
          child: MapaWidget(
            centro: navProvider.posicaoAtualLatLng,
            zoom: 17,
            trajeto: trajeto.geometriaCompleta,
            manobras: trajeto.todasManobras,
            posicaoUsuario: navProvider.posicaoAtualLatLng,
            mostrarControles: false,
          ),
        ),

        // Painel de instrução atual
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (manobraAtual != null) ...[
                // Distância para próxima manobra
                Text(
                  _formatarDistancia(navProvider.distanciaParaProximaManobra),
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                
                // Ícone da manobra
                Icon(
                  _iconeParaManobra(manobraAtual.tipo),
                  size: 48,
                  color: Colors.white,
                ),
                const SizedBox(height: 8),
                
                // Instrução textual
                Text(
                  manobraAtual.texto,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                      ),
                  textAlign: TextAlign.center,
                ),
              ] else
                const Text(
                  'Aguardando localização...',
                  style: TextStyle(color: Colors.white),
                ),
              
              const SizedBox(height: 16),
              
              // Controles
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Repetir instrução
                  IconButton.filledTonal(
                    onPressed: navProvider.repetirManobra,
                    icon: const Icon(Icons.replay),
                    iconSize: 32,
                  ),
                  
                  // Parar navegação
                  IconButton.filled(
                    onPressed: () async {
                      await navProvider.pararNavegacao();
                    },
                    icon: const Icon(Icons.stop),
                    iconSize: 32,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                  ),
                  
                  // Alternar voz
                  IconButton.filledTonal(
                    onPressed: () {
                      // Salva no ConfigProvider, que repassa ao NavegacaoProvider
                      context
                          .read<ConfigProvider>()
                          .setVozHabilitada(!navProvider.vozHabilitada);
                    },
                    icon: Icon(
                      navProvider.vozHabilitada
                          ? Icons.volume_up
                          : Icons.volume_off,
                    ),
                    iconSize: 32,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfo(
    BuildContext context,
    IconData icone,
    String valor,
    String label,
  ) {
    return Column(
      children: [
        Icon(icone, color: Theme.of(context).primaryColor),
        const SizedBox(height: 4),
        Text(
          valor,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  /// Posição do GPS para ser o início do trajeto. Null se não houver.
  Future<LatLng?> _posicaoAtual() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permissao = await Geolocator.checkPermission();
      if (permissao == LocationPermission.denied) {
        permissao = await Geolocator.requestPermission();
      }
      if (permissao == LocationPermission.denied ||
          permissao == LocationPermission.deniedForever) {
        return null;
      }
      final p = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 12),
      );
      return LatLng(p.latitude, p.longitude);
    } catch (_) {
      try {
        final p = await Geolocator.getLastKnownPosition();
        return p == null ? null : LatLng(p.latitude, p.longitude);
      } catch (_) {
        return null;
      }
    }
  }

  String _formatarDistancia(double metros) {
    if (metros < 1000) {
      return '${metros.round()} m';
    } else {
      return '${(metros / 1000).toStringAsFixed(1)} km';
    }
  }

  IconData _iconeParaManobra(tipo) {
    switch (tipo.toString()) {
      case 'TipoManobra.partir':
        return Icons.straight;
      case 'TipoManobra.esquerda':
        return Icons.turn_left;
      case 'TipoManobra.direita':
        return Icons.turn_right;
      case 'TipoManobra.retorno':
        return Icons.u_turn_left;
      case 'TipoManobra.chegar':
        return Icons.flag;
      default:
        return Icons.straight;
    }
  }
}
