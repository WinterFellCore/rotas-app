import 'package:flutter/material.dart';
import 'package:rotas_app/screens/busca_screen.dart';
import 'package:rotas_app/screens/rota_screen.dart';
import 'package:rotas_app/screens/navegacao_screen.dart';
import 'package:rotas_app/screens/config_screen.dart';

/// Tela principal com navegação por abas
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _indiceAtual = 0;

  final List<Widget> _telas = const [
    BuscaScreen(),
    RotaScreen(),
    NavegacaoScreen(),
    ConfigScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _indiceAtual,
        children: _telas,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indiceAtual,
        onDestinationSelected: (index) {
          setState(() {
            _indiceAtual = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.search),
            label: 'Buscar',
          ),
          NavigationDestination(
            icon: Icon(Icons.route),
            label: 'Rota',
          ),
          NavigationDestination(
            icon: Icon(Icons.navigation),
            label: 'Navegar',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'Config',
          ),
        ],
      ),
    );
  }
}
