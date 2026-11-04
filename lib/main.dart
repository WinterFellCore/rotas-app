import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rotas_app/providers/rota_provider.dart';
import 'package:rotas_app/providers/navegacao_provider.dart';
import 'package:rotas_app/providers/config_provider.dart';
import 'package:rotas_app/screens/home_screen.dart';
import 'package:rotas_app/services/database_service.dart';
import 'package:rotas_app/services/tts_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configurações salvas (nunca lança: usa padrões se falhar)
  final config = ConfigProvider();
  await config.initialize();

  // Banco de endereços: sem ele o app não funciona, então mostra o erro
  final dbService = DatabaseService();
  try {
    await dbService.initialize();
  } catch (e, st) {
    debugPrint('Erro ao abrir banco de dados: $e\n$st');
    runApp(ErroInicializacaoApp(mensagem: e.toString()));
    return;
  }

  // Voz: se falhar, o app segue sem anúncios falados
  final ttsService = TTSService();
  await ttsService.initialize();

  runApp(RotasApp(
    config: config,
    databaseService: dbService,
    ttsService: ttsService,
  ));
}

class RotasApp extends StatefulWidget {
  final ConfigProvider config;
  final DatabaseService databaseService;
  final TTSService ttsService;

  const RotasApp({
    super.key,
    required this.config,
    required this.databaseService,
    required this.ttsService,
  });

  @override
  State<RotasApp> createState() => _RotasAppState();
}

class _RotasAppState extends State<RotasApp> {
  late final RotaProvider _rotaProvider;
  late final NavegacaoProvider _navegacaoProvider;

  @override
  void initState() {
    super.initState();
    _rotaProvider = RotaProvider(widget.databaseService);
    _navegacaoProvider = NavegacaoProvider(
      ttsService: widget.ttsService,
      rotaProvider: _rotaProvider,
    );

    // Repassa as configurações salvas para a API e para a voz
    _aplicarConfiguracoes();
    widget.config.addListener(_aplicarConfiguracoes);
  }

  void _aplicarConfiguracoes() {
    final config = widget.config;
    _rotaProvider.setApiBaseUrl(config.apiBaseUrl);
    _rotaProvider.setApiKey(config.apiKey);
    _navegacaoProvider.aplicarConfiguracoesVoz(
      habilitada: config.vozHabilitada,
      velocidade: config.velocidadeVoz,
      volume: config.volumeVoz,
    );
  }

  @override
  void dispose() {
    widget.config.removeListener(_aplicarConfiguracoes);
    _navegacaoProvider.dispose();
    _rotaProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ConfigProvider>.value(value: widget.config),
        ChangeNotifierProvider<RotaProvider>.value(value: _rotaProvider),
        ChangeNotifierProvider<NavegacaoProvider>.value(
          value: _navegacaoProvider,
        ),
      ],
      child: MaterialApp(
        title: 'Rotas - General Salgado',
        debugShowCheckedModeBanner: false,
        theme: _tema(Brightness.light),
        darkTheme: _tema(Brightness.dark),
        themeMode: ThemeMode.system,
        home: const HomeScreen(),
      ),
    );
  }
}

ThemeData _tema(Brightness brilho) {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: brilho,
    ),
    useMaterial3: true,
  );
}

/// Tela mostrada quando o banco de endereços não pôde ser aberto
class ErroInicializacaoApp extends StatelessWidget {
  final String mensagem;

  const ErroInicializacaoApp({super.key, required this.mensagem});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _tema(Brightness.light),
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Não foi possível abrir a base de endereços',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Feche e abra o app novamente. Se o problema continuar, '
                  'reinstale o app.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  mensagem,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
