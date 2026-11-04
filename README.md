# 🗺️ Rotas - App Flutter

App móvel de navegação e otimização de rotas para General Salgado/SP.

## ✨ Funcionalidades

- 🔍 Busca de endereços (FTS5 full-text search)
- 📍 Gestão de rotas (adicionar/remover/reordenar paradas)
- 🧭 Navegação turn-by-turn (GPS + voz)
- 🚗 Otimização de rotas (algoritmo de menor distância)
- 🗺️ Mapa interativo (OpenStreetMap)
- 💾 Offline-first (SQLite com 40k+ endereços)

## 🚀 Instalação e Build

### No Windows

```powershell
# Instalar dependências
cd flutter_app
C:\tools\flutter\bin\flutter.bat pub get

# Build Android
C:\tools\flutter\bin\flutter.bat build apk          # APK para testar
C:\tools\flutter\bin\flutter.bat build appbundle    # AAB para Play Store
```

**Nota:** Windows não builda iOS. Use Codemagic (veja abaixo).

### No Mac

```bash
# Instalar dependências
flutter pub get

# Build iOS
flutter build ios --release --no-codesign    # Sem certificado
flutter build ipa --release                   # Com certificado (App Store)

# Build Android
flutter build apk
flutter build appbundle
```

## ☁️ Build iOS na Nuvem (Sem Mac) - Codemagic

Veja o guia completo em: **[INICIO_RAPIDO.md](INICIO_RAPIDO.md)**

### Resumo rápido:

1. Subir código no GitHub
2. Conectar em https://codemagic.io
3. Build automático iOS + Android
4. 500 minutos grátis/mês

## 📦 Estrutura

```
lib/
├── main.dart              # Entry point
├── models/                # Endereco, Manobra, RotaOtimizada
├── services/              # DatabaseService, ApiService, TTSService
├── providers/             # RotaProvider, NavegacaoProvider, ConfigProvider
├── screens/               # BuscaScreen, RotaScreen, NavegacaoScreen, etc
└── widgets/               # MapaWidget
```

## 🗄️ Banco de Dados

- **Arquivo:** `assets/database/rotas.db` (~7 MB)
- **Conteúdo:** 40k+ endereços (CNEFE 2022 + OSM)
- **Busca:** FTS5 full-text search

## 📱 Testar

### Android (Windows ou Mac)
```bash
# Com celular conectado via USB
flutter run

# Ou instalar o APK manualmente
```

### iOS (Só Mac)
```bash
# Com iPhone conectado
flutter run -d iphone

# Ou via Codemagic (nuvem)
```

## 📄 Licença

MIT

---

**Build automatizado via Codemagic** | **Veja [INICIO_RAPIDO.md](INICIO_RAPIDO.md)**
