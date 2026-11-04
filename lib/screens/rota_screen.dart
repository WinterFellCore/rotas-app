import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:rotas_app/models/endereco.dart';
import 'package:rotas_app/providers/rota_provider.dart';
import 'package:rotas_app/widgets/mapa_widget.dart';

/// Tela de gerenciamento e otimização de rotas
class RotaScreen extends StatelessWidget {
  const RotaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minha Rota'),
        actions: [
          // Limpar rota
          Consumer<RotaProvider>(
            builder: (context, provider, _) {
              if (!provider.temParadas) return const SizedBox.shrink();
              
              return IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Limpar rota',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Limpar rota'),
                      content: const Text(
                        'Deseja remover todas as paradas da rota?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancelar'),
                        ),
                        FilledButton(
                          onPressed: () {
                            provider.limparRota();
                            Navigator.pop(context);
                          },
                          child: const Text('Limpar'),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      body: Consumer<RotaProvider>(
        builder: (context, provider, _) {
          if (!provider.temParadas) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.route,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhuma parada na rota',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Busque e adicione endereços para criar sua rota',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Mapa com a rota
              SizedBox(
                height: 300,
                child: MapaWidget(
                  enderecos: provider.paradas,
                  trajeto: provider.rotaOtimizada != null
                      ? _extrairPontosRota(provider.paradas)
                      : null,
                  posicaoUsuario: provider.partidaPersonalizada,
                ),
              ),

              // Estatísticas da rota
              if (provider.rotaOtimizada != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildEstatistica(
                        context,
                        Icons.straighten,
                        '${(provider.rotaOtimizada!.totalMetros / 1000).toStringAsFixed(1)} km',
                        'Distância',
                      ),
                      _buildEstatistica(
                        context,
                        Icons.timer,
                        '${provider.rotaOtimizada!.totalMinutos} min',
                        'Tempo',
                      ),
                      _buildEstatistica(
                        context,
                        Icons.trending_down,
                        '${provider.rotaOtimizada!.economiaPercentual.toStringAsFixed(0)}%',
                        'Economia',
                      ),
                    ],
                  ),
                ),

              // Lista de paradas
              Expanded(
                child: ReorderableListView.builder(
                  itemCount: provider.paradas.length,
                  onReorder: provider.reordenarParada,
                  itemBuilder: (context, index) {
                    final endereco = provider.paradas[index];
                    final rota = provider.rotaOtimizada;
                    double? metrosDaAnterior;
                    
                    if (rota != null && index < rota.paradas.length) {
                      metrosDaAnterior = rota.paradas[index].metrosDaAnterior;
                    }

                    return _buildParadaItem(
                      context,
                      endereco,
                      index,
                      provider,
                      metrosDaAnterior,
                    );
                  },
                ),
              ),

              // Botões de ação
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
                    // Opções
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildOpcao(
                          context,
                          'Usar malha viária',
                          provider.usarRuas,
                          (valor) => provider.setUsarRuas(valor ?? false),
                        ),
                        _buildOpcao(
                          context,
                          'Voltar ao início',
                          provider.voltarAoInicio,
                          (valor) => provider.setVoltarAoInicio(valor ?? false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Botão otimizar
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: provider.isOptimizing
                            ? null
                            : () async {
                                await provider.otimizarRota();
                                if (context.mounted && provider.erro != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(provider.erro!)),
                                  );
                                }
                              },
                        icon: provider.isOptimizing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.auto_fix_high),
                        label: Text(
                          provider.isOptimizing
                              ? 'Otimizando...'
                              : 'Otimizar Rota',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildParadaItem(
    BuildContext context,
    Endereco endereco,
    int index,
    RotaProvider provider,
    double? metrosDaAnterior,
  ) {
    return Card(
      key: ValueKey(endereco.id),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          child: Text('${index + 1}'),
        ),
        title: Text(endereco.enderecoDisplay),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (endereco.bairro != null) Text(endereco.bairro!),
            if (metrosDaAnterior != null)
              Text(
                '↑ ${(metrosDaAnterior / 1000).toStringAsFixed(1)} km da anterior',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_upward, size: 20),
              onPressed: index > 0
                  ? () => provider.moverParadaAcima(index)
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.arrow_downward, size: 20),
              onPressed: index < provider.numeroParadas - 1
                  ? () => provider.moverParadaAbaixo(index)
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => provider.removerParada(endereco.id),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEstatistica(
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
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
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

  Widget _buildOpcao(
    BuildContext context,
    String label,
    bool valor,
    ValueChanged<bool?> onChanged,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: valor,
          onChanged: onChanged,
        ),
        Text(label),
      ],
    );
  }

  List<LatLng> _extrairPontosRota(List<Endereco> paradas) {
    return paradas
        .where((e) => e.temCoordenada)
        .map((e) => LatLng(e.lat!, e.lon!))
        .toList();
  }
}
