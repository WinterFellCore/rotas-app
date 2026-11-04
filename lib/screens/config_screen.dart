import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rotas_app/providers/config_provider.dart';
import 'package:rotas_app/services/database_service.dart';

/// Tela de configurações do app
class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  final DatabaseService _db = DatabaseService();
  Map<String, int>? _estatisticas;
  bool _carregandoStats = false;

  @override
  void initState() {
    super.initState();
    _carregarEstatisticas();
  }

  Future<void> _carregarEstatisticas() async {
    setState(() => _carregandoStats = true);
    try {
      final stats = await _db.obterEstatisticas();
      if (!mounted) return;
      setState(() {
        _estatisticas = stats;
        _carregandoStats = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar estatísticas: $e');
      if (!mounted) return;
      setState(() => _carregandoStats = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
      ),
      body: ListView(
        children: [
          // Estatísticas da base de dados
          _buildSecao('Base de Dados'),
          if (_carregandoStats)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_estatisticas != null) ...[
            _buildEstatisticaItem(
              'Total de endereços',
              _estatisticas!['total'].toString(),
              Icons.home,
            ),
            _buildEstatisticaItem(
              'Com número',
              _estatisticas!['com_numero'].toString(),
              Icons.numbers,
            ),
            _buildEstatisticaItem(
              'Verificados',
              _estatisticas!['verificados'].toString(),
              Icons.verified,
            ),
            _buildEstatisticaItem(
              'Logradouros',
              _estatisticas!['logradouros'].toString(),
              Icons.signpost,
            ),
          ],

          const Divider(),

          // Configurações da API
          _buildSecao('API Backend'),
          Consumer<ConfigProvider>(
            builder: (context, config, _) {
              return Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.cloud),
                    title: const Text('URL da API'),
                    subtitle: Text(config.apiBaseUrl),
                    trailing: const Icon(Icons.edit),
                    onTap: () => _editarApiUrl(context, config),
                  ),
                  ListTile(
                    leading: const Icon(Icons.key),
                    title: const Text('API Key'),
                    subtitle: Text(
                      config.apiKey != null ? '••••••••' : 'Não configurada',
                    ),
                    trailing: const Icon(Icons.edit),
                    onTap: () => _editarApiKey(context, config),
                  ),
                ],
              );
            },
          ),

          const Divider(),

          // Configurações de voz
          _buildSecao('Navegação por Voz'),
          Consumer<ConfigProvider>(
            builder: (context, config, _) {
              return Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.volume_up),
                    title: const Text('Voz habilitada'),
                    subtitle: const Text('Anuncia instruções durante navegação'),
                    value: config.vozHabilitada,
                    onChanged: (valor) => config.setVozHabilitada(valor),
                  ),
                  ListTile(
                    leading: const Icon(Icons.speed),
                    title: const Text('Velocidade da voz'),
                    subtitle: Slider(
                      value: config.velocidadeVoz,
                      min: 0.3,
                      max: 1.0,
                      divisions: 7,
                      label: config.velocidadeVoz.toStringAsFixed(1),
                      onChanged: (valor) => config.setVelocidadeVoz(valor),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.volume_down),
                    title: const Text('Volume da voz'),
                    subtitle: Slider(
                      value: config.volumeVoz,
                      min: 0.0,
                      max: 1.0,
                      divisions: 10,
                      label: (config.volumeVoz * 100).round().toString(),
                      onChanged: (valor) => config.setVolumeVoz(valor),
                    ),
                  ),
                ],
              );
            },
          ),

          const Divider(),

          // Sobre
          _buildSecao('Sobre'),
          const ListTile(
            leading: Icon(Icons.info),
            title: Text('Rotas - General Salgado'),
            subtitle: Text('Versão 1.0.0\nBase de endereços do CNEFE 2022 (IBGE)'),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('Código fonte'),
            subtitle: const Text('Projeto open source'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () {
              // TODO: Abrir repositório
            },
          ),

          const Divider(),

          // Ações
          _buildSecao('Ações'),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('Resetar configurações'),
            onTap: () => _resetarConfiguracoes(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSecao(String titulo) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        titulo,
        style: TextStyle(
          color: Theme.of(context).primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildEstatisticaItem(String label, String valor, IconData icone) {
    return ListTile(
      leading: Icon(icone),
      title: Text(label),
      trailing: Text(
        valor,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }

  Future<void> _editarApiUrl(BuildContext context, ConfigProvider config) async {
    final controller = TextEditingController(text: config.apiBaseUrl);
    
    final resultado = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('URL da API'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'URL',
            hintText: 'https://www.zefi.solutions',
          ),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (resultado != null && resultado.isNotEmpty) {
      await config.setApiBaseUrl(resultado);
    }
  }

  Future<void> _editarApiKey(BuildContext context, ConfigProvider config) async {
    final controller = TextEditingController(text: config.apiKey ?? '');
    
    final resultado = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('API Key'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Chave',
            hintText: 'Deixe vazio para usar sem autenticação',
          ),
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (resultado != null) {
      await config.setApiKey(resultado.isEmpty ? null : resultado);
    }
  }

  Future<void> _resetarConfiguracoes(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resetar configurações'),
        content: const Text(
          'Todas as configurações serão restauradas aos valores padrão. '
          'Deseja continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Resetar'),
          ),
        ],
      ),
    );

    if (confirmar == true && context.mounted) {
      final config = context.read<ConfigProvider>();
      await config.resetar();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configurações resetadas')),
        );
      }
    }
  }
}
