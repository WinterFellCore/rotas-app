import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:rotas_app/models/manobra.dart';
import 'package:rotas_app/providers/rota_provider.dart';
import 'package:rotas_app/services/tela_service.dart';
import 'package:rotas_app/services/tts_service.dart';

/// Provider para navegação turn-by-turn com voz
class NavegacaoProvider extends ChangeNotifier {
  final TTSService _ttsService;
  final RotaProvider _rotaProvider;

  // Estado de navegação
  bool _navegando = false;
  bool _iniciando = false;
  Position? _posicaoAtual;
  StreamSubscription<Position>? _positionStream;

  // Manobra atual
  Manobra? _manobraAtual;
  int _indiceManobraAtual = 0;
  double _distanciaParaProximaManobra = 0;

  // Parada atual na rota
  int _indiceParadaAtual = 0;

  // Configurações de voz (sincronizadas a partir do ConfigProvider)
  bool _vozHabilitada = true;
  double _velocidadeVoz = 0.5;
  double _volumeVoz = 1.0;

  // Controle de anúncios (para não repetir)
  final Set<String> _anunciosFeitos = {};

  // Distâncias para anúncios (em metros)
  static const double _distanciaAvisoLonge = 400.0;
  static const double _distanciaAvisoPerto = 60.0;
  static const double _distanciaManobraConcluida = 20.0;

  NavegacaoProvider({
    required TTSService ttsService,
    required RotaProvider rotaProvider,
  })  : _ttsService = ttsService,
        _rotaProvider = rotaProvider;

  // Getters
  bool get navegando => _navegando;
  bool get iniciando => _iniciando;
  Position? get posicaoAtual => _posicaoAtual;
  Manobra? get manobraAtual => _manobraAtual;
  int get indiceManobraAtual => _indiceManobraAtual;
  double get distanciaParaProximaManobra => _distanciaParaProximaManobra;
  int get indiceParadaAtual => _indiceParadaAtual;
  bool get vozHabilitada => _vozHabilitada;
  double get velocidadeVoz => _velocidadeVoz;
  double get volumeVoz => _volumeVoz;

  LatLng? get posicaoAtualLatLng => _posicaoAtual != null
      ? LatLng(_posicaoAtual!.latitude, _posicaoAtual!.longitude)
      : null;

  /// Inicia navegação.
  ///
  /// Retorna `null` em caso de sucesso ou uma mensagem de erro para
  /// mostrar ao usuário.
  Future<String?> iniciarNavegacao() async {
    if (_navegando || _iniciando) return null;

    final trajeto = _rotaProvider.trajetoDetalhado;
    if (trajeto == null) {
      return 'Carregue o trajeto antes de iniciar a navegação';
    }
    final manobras = trajeto.todasManobras;
    if (manobras.isEmpty) {
      return 'O trajeto não tem instruções de navegação';
    }

    _iniciando = true;
    notifyListeners();

    try {
      final erroPermissao = await _verificarPermissaoLocalizacao();
      if (erroPermissao != null) return erroPermissao;

      // Android 13+: pede permissão para mostrar a notificação do serviço
      // de navegação. Sem ela o GPS continua, mas a notificação fica oculta.
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await ph.Permission.notification.request();
      }

      _indiceManobraAtual = 0;
      _indiceParadaAtual = 0;
      _anunciosFeitos.clear();
      _manobraAtual = manobras.first;

      // Posição inicial
      try {
        _posicaoAtual = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 15),
        );
        _distanciaParaProximaManobra = _distanciaAte(_posicaoAtual!, _manobraAtual!);
      } catch (e) {
        debugPrint('Erro ao obter posição inicial: $e');
      }

      // Stream de posição que continua com a tela bloqueada
      _positionStream = Geolocator.getPositionStream(
        locationSettings: _configuracoesLocalizacao(),
      ).listen(
        _atualizarPosicao,
        onError: (Object e) => debugPrint('Erro no stream de posição: $e'),
      );

      // Mantém a tela ligada enquanto navega
      await TelaService.manterLigada(true);

      _navegando = true;
      _anunciarManobra(_manobraAtual!, _distanciaParaProximaManobra);
      return null;
    } catch (e) {
      debugPrint('Erro ao iniciar navegação: $e');
      await _positionStream?.cancel();
      _positionStream = null;
      return 'Não foi possível iniciar a navegação';
    } finally {
      _iniciando = false;
      notifyListeners();
    }
  }

  /// Configuração do GPS por plataforma.
  ///
  /// Android: serviço em primeiro plano com notificação, para o sistema não
  /// suspender o GPS quando a tela bloqueia.
  /// iOS: atualizações em segundo plano (UIBackgroundModes: location).
  LocationSettings _configuracoesLocalizacao() {
    const precisao = LocationAccuracy.bestForNavigation;
    const filtroMetros = 5;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: precisao,
        distanceFilter: filtroMetros,
        intervalDuration: const Duration(seconds: 1),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Navegação em andamento',
          notificationText: 'O Rotas está acompanhando sua localização',
          enableWakeLock: true,
        ),
      );
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: precisao,
        distanceFilter: filtroMetros,
        activityType: ActivityType.automotiveNavigation,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    }

    return const LocationSettings(
      accuracy: precisao,
      distanceFilter: filtroMetros,
    );
  }

  /// Para navegação
  Future<void> pararNavegacao() async {
    _navegando = false;
    await _positionStream?.cancel();
    _positionStream = null;
    await _ttsService.parar();
    await TelaService.manterLigada(false);
    _anunciosFeitos.clear();
    notifyListeners();
  }

  double _distanciaAte(Position posicao, Manobra manobra) {
    return Geolocator.distanceBetween(
      posicao.latitude,
      posicao.longitude,
      manobra.posicao.latitude,
      manobra.posicao.longitude,
    );
  }

  /// Atualiza posição e calcula proximidade de manobras
  void _atualizarPosicao(Position position) {
    if (!_navegando) return;
    _posicaoAtual = position;

    if (_manobraAtual == null) {
      notifyListeners();
      return;
    }

    _distanciaParaProximaManobra = _distanciaAte(position, _manobraAtual!);

    _verificarAnuncios();

    if (_distanciaParaProximaManobra < _distanciaManobraConcluida) {
      _avancarParaProximaManobra();
    }

    notifyListeners();
  }

  /// Verifica e anuncia manobras conforme distância
  void _verificarAnuncios() {
    if (!_vozHabilitada || _manobraAtual == null) return;

    final chave = '${_indiceManobraAtual}_${_manobraAtual!.tipo.name}';

    // Anúncio longe (400m)
    if (_distanciaParaProximaManobra < _distanciaAvisoLonge &&
        _distanciaParaProximaManobra > _distanciaAvisoPerto) {
      final chaveAvisoLonge = '${chave}_longe';
      if (!_anunciosFeitos.contains(chaveAvisoLonge)) {
        _anunciarManobra(_manobraAtual!, _distanciaParaProximaManobra);
        _anunciosFeitos.add(chaveAvisoLonge);
      }
    }

    // Anúncio perto (60m)
    if (_distanciaParaProximaManobra < _distanciaAvisoPerto) {
      final chaveAvisoPerto = '${chave}_perto';
      if (!_anunciosFeitos.contains(chaveAvisoPerto)) {
        _anunciarManobra(_manobraAtual!, _distanciaParaProximaManobra);
        _anunciosFeitos.add(chaveAvisoPerto);
      }
    }
  }

  /// Anuncia uma manobra por voz
  void _anunciarManobra(Manobra manobra, double distanciaMetros) {
    if (!_vozHabilitada) return;

    final texto = manobra.textoComDistancia(distanciaMetros);
    if (texto.isEmpty) return;
    _ttsService.falar(texto);
  }

  /// Avança para próxima manobra
  void _avancarParaProximaManobra() {
    final manobras = _rotaProvider.trajetoDetalhado?.todasManobras;
    if (manobras == null || manobras.isEmpty) return;

    if (_indiceManobraAtual < manobras.length - 1) {
      final anterior = _indiceManobraAtual;
      _indiceManobraAtual++;
      _manobraAtual = manobras[_indiceManobraAtual];

      if (manobras[anterior].tipo == TipoManobra.chegar) {
        _indiceParadaAtual++;
      }

      // Limpa anúncios da manobra anterior
      _anunciosFeitos.removeWhere((k) => k.startsWith('${anterior}_'));

      if (_posicaoAtual != null) {
        _distanciaParaProximaManobra = _distanciaAte(_posicaoAtual!, _manobraAtual!);
      }
    } else {
      // Chegou ao destino final
      _anunciarManobra(_manobraAtual!, 0);
      _manobraAtual = null;
      unawaited(pararNavegacao());
    }
  }

  /// Aplica as configurações de voz salvas (chamado pelo ConfigProvider)
  Future<void> aplicarConfiguracoesVoz({
    required bool habilitada,
    required double velocidade,
    required double volume,
  }) async {
    final mudou = habilitada != _vozHabilitada ||
        velocidade != _velocidadeVoz ||
        volume != _volumeVoz;
    if (!mudou) return;

    if (velocidade != _velocidadeVoz) {
      await _ttsService.setVelocidade(velocidade);
    }
    if (volume != _volumeVoz) {
      await _ttsService.setVolume(volume);
    }
    _vozHabilitada = habilitada;
    _velocidadeVoz = velocidade;
    _volumeVoz = volume;
    if (!habilitada) {
      await _ttsService.parar();
    }
    notifyListeners();
  }

  /// Repete manobra atual
  void repetirManobra() {
    if (_manobraAtual != null) {
      _anunciarManobra(_manobraAtual!, _distanciaParaProximaManobra);
    }
  }

  /// Verifica permissão de localização. Retorna mensagem de erro ou null.
  Future<String?> _verificarPermissaoLocalizacao() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return 'Ative a localização (GPS) do aparelho para navegar';
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      return 'Permissão de localização negada';
    }
    if (permission == LocationPermission.deniedForever) {
      return 'Permissão de localização bloqueada. Libere nas configurações do aparelho';
    }
    return null;
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _ttsService.parar();
    TelaService.manterLigada(false);
    super.dispose();
  }
}
