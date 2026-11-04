import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:rotas_app/models/endereco.dart';
import 'package:rotas_app/providers/rota_provider.dart';
import 'package:rotas_app/services/database_service.dart';
import 'package:rotas_app/widgets/mapa_widget.dart';

/// Tela de busca de endereços
class BuscaScreen extends StatefulWidget {
  const BuscaScreen({super.key});

  @override
  State<BuscaScreen> createState() => _BuscaScreenState();
}

class _BuscaScreenState extends State<BuscaScreen> {
  final TextEditingController _searchController = TextEditingController();
  final DatabaseService _db = DatabaseService();
  
  List<Endereco> _resultados = [];
  Endereco? _enderecoSelecionado;
  LatLng? _posicaoUsuario;
  bool _carregando = false;
  bool _buscandoPorProximidade = false;
  String? _erro;

  // Espera o usuário parar de digitar antes de buscar
  static const Duration _atrasoBusca = Duration(milliseconds: 300);
  Timer? _debounce;
  // Identifica a busca mais recente; respostas de buscas antigas são ignoradas
  int _buscaAtual = 0;
  bool _obtendoLocalizacao = false;

  @override
  void initState() {
    super.initState();
    _obterLocalizacao(pedirPermissao: false);
  }

  /// Obtém a posição do usuário. Só abre o pedido de permissão quando o
  /// usuário toca em "Buscar próximos de mim".
  Future<bool> _obterLocalizacao({required bool pedirPermissao}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (pedirPermissao) _mostrarMensagem('Ative a localização (GPS) do aparelho');
        return false;
      }

      var permissao = await Geolocator.checkPermission();
      if (permissao == LocationPermission.denied && pedirPermissao) {
        permissao = await Geolocator.requestPermission();
      }
      if (permissao == LocationPermission.denied ||
          permissao == LocationPermission.deniedForever) {
        if (pedirPermissao) {
          _mostrarMensagem(
            permissao == LocationPermission.deniedForever
                ? 'Permissão de localização bloqueada. Libere nas configurações do aparelho'
                : 'Permissão de localização negada',
          );
        }
        return false;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      if (!mounted) return false;
      setState(() {
        _posicaoUsuario = LatLng(position.latitude, position.longitude);
      });
      return true;
    } catch (e) {
      debugPrint('Erro ao obter localização: $e');
      if (pedirPermissao) _mostrarMensagem('Não foi possível obter sua localização');
      return false;
    }
  }

  void _mostrarMensagem(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  void _aoDigitar(String value) {
    setState(() {}); // atualiza o botão de limpar
    _debounce?.cancel();
    if (value.trim().length < 3) return;
    _debounce = Timer(_atrasoBusca, () => _buscar(value));
  }

  Future<void> _buscar(String query) async {
    _debounce?.cancel();
    final idBusca = ++_buscaAtual;

    if (query.trim().isEmpty) {
      setState(() {
        _resultados = [];
        _erro = null;
        _carregando = false;
      });
      return;
    }

    setState(() {
      _carregando = true;
      _erro = null;
      _buscandoPorProximidade = false;
    });

    try {
      final resultados = await _db.buscarEnderecos(query);
      if (!mounted || idBusca != _buscaAtual) return;
      setState(() {
        _resultados = resultados;
        _carregando = false;
        if (resultados.isEmpty) {
          _erro = 'Nenhum resultado encontrado';
        }
      });
    } catch (e) {
      if (!mounted || idBusca != _buscaAtual) return;
      setState(() {
        _erro = 'Erro na busca: $e';
        _carregando = false;
      });
    }
  }

  Future<void> _buscarProximos() async {
    _debounce?.cancel();
    final idBusca = ++_buscaAtual;

    setState(() => _obtendoLocalizacao = true);
    final ok = await _obterLocalizacao(pedirPermissao: true);
    if (!mounted) return;
    setState(() => _obtendoLocalizacao = false);
    if (!ok || _posicaoUsuario == null || idBusca != _buscaAtual) return;

    setState(() {
      _carregando = true;
      _erro = null;
      _buscandoPorProximidade = true;
    });

    try {
      final proximos = await _db.buscarProximos(
        lat: _posicaoUsuario!.latitude,
        lon: _posicaoUsuario!.longitude,
        raioMetros: 500,
      );
      if (!mounted || idBusca != _buscaAtual) return;

      setState(() {
        _resultados = proximos;
        _carregando = false;
        if (proximos.isEmpty) {
          _erro = 'Nenhum endereço próximo encontrado';
        }
      });
    } catch (e) {
      if (!mounted || idBusca != _buscaAtual) return;
      setState(() {
        _erro = 'Erro ao buscar próximos: $e';
        _carregando = false;
      });
    }
  }

  void _selecionarEndereco(Endereco endereco) {
    setState(() {
      _enderecoSelecionado = endereco;
    });
    
    // Mostra detalhes em bottom sheet
    showModalBottomSheet(
      context: context,
      builder: (context) => _buildDetalhesEndereco(endereco),
    );
  }

  Widget _buildDetalhesEndereco(Endereco endereco) {
    final rotaProvider = context.read<RotaProvider>();
    final jaAdicionado = rotaProvider.paradasIds.contains(endereco.id);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                endereco.especie == 1 ? Icons.home : Icons.business,
                size: 32,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      endereco.enderecoDisplay,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (endereco.estabelecimento != null)
                      Text(
                        endereco.estabelecimento!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Informações adicionais
          if (endereco.bairro != null)
            _buildInfo('Bairro', endereco.bairro!),
          if (endereco.cep != null)
            _buildInfo('CEP', endereco.cep!),
          _buildInfo('Origem', _labelOrigem(endereco.origem)),
          if (endereco.verificado)
            _buildInfo('Status', 'Verificado em campo ✓',
                cor: Colors.green),
          
          const SizedBox(height: 16),
          
          // Ações
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: jaAdicionado
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.of(context);
                          Navigator.pop(context);
                          final ok = await rotaProvider.adicionarParada(endereco.id);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(ok
                                  ? 'Adicionado à rota'
                                  : 'Não foi possível adicionar o endereço'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                  icon: Icon(jaAdicionado ? Icons.check : Icons.add),
                  label: Text(jaAdicionado ? 'Na rota' : 'Adicionar à rota'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: () {
                  // TODO: Abrir no app de mapas
                },
                icon: const Icon(Icons.map),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfo(String label, String valor, {Color? cor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            valor,
            style: TextStyle(color: cor),
          ),
        ],
      ),
    );
  }

  String _labelOrigem(String origem) {
    switch (origem) {
      case 'cnefe':
        return 'IBGE Censo 2022';
      case 'manual':
        return 'Verificado manualmente';
      case 'interpolado':
        return 'Coordenada estimada';
      default:
        return origem;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar Endereços'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Ex: Bruno Martins 517',
              leading: const Icon(Icons.search),
              trailing: [
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _debounce?.cancel();
                      _buscaAtual++;
                      setState(() {
                        _resultados = [];
                        _erro = null;
                        _carregando = false;
                      });
                    },
                  ),
              ],
              onChanged: _aoDigitar,
              onSubmitted: _buscar,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Botão de buscar próximos (sempre visível; pede permissão ao tocar)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: FilledButton.tonalIcon(
              onPressed: _carregando || _obtendoLocalizacao ? null : _buscarProximos,
              icon: _obtendoLocalizacao
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.near_me),
              label: const Text('Buscar próximos de mim'),
            ),
          ),

          // Resultados
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator())
                : _erro != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 64),
                            const SizedBox(height: 16),
                            Text(_erro!),
                          ],
                        ),
                      )
                    : _resultados.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Digite para buscar endereços',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            children: [
                              // Mapa
                              SizedBox(
                                height: 250,
                                child: MapaWidget(
                                  centro: _enderecoSelecionado != null &&
                                          _enderecoSelecionado!.temCoordenada
                                      ? LatLng(
                                          _enderecoSelecionado!.lat!,
                                          _enderecoSelecionado!.lon!,
                                        )
                                      : _posicaoUsuario,
                                  zoom: 15,
                                  enderecos: _resultados,
                                  enderecoSelecionado: _enderecoSelecionado,
                                  posicaoUsuario: _posicaoUsuario,
                                  onEnderecoTap: _selecionarEndereco,
                                ),
                              ),
                              
                              // Lista de resultados
                              Expanded(
                                child: ListView.separated(
                                  itemCount: _resultados.length,
                                  separatorBuilder: (_, __) => const Divider(),
                                  itemBuilder: (context, index) {
                                    final endereco = _resultados[index];
                                    final selecionado =
                                        _enderecoSelecionado?.id == endereco.id;

                                    return ListTile(
                                      selected: selecionado,
                                      leading: Icon(
                                        endereco.especie == 1
                                            ? Icons.home
                                            : Icons.business,
                                      ),
                                      title: Text(endereco.enderecoDisplay),
                                      subtitle: Text(
                                        [
                                          endereco.bairro,
                                          endereco.estabelecimento,
                                        ].whereType<String>().join(' • '),
                                      ),
                                      trailing: Icon(
                                        endereco.verificado
                                            ? Icons.verified
                                            : Icons.circle,
                                        color: endereco.verificado
                                            ? Colors.green
                                            : _corOrigem(endereco.origem),
                                        size: 16,
                                      ),
                                      onTap: () => _selecionarEndereco(endereco),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
          ),
        ],
      ),
    );
  }

  Color _corOrigem(String origem) {
    switch (origem) {
      case 'cnefe':
        return Colors.blue;
      case 'manual':
        return Colors.green;
      case 'interpolado':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }
}
