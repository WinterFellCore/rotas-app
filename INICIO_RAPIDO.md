# ⚡ Passo a Passo: Git + GitHub + Codemagic

## 🎯 Objetivo
Subir o app no GitHub e buildar iOS + Android no Codemagic (20 minutos).

---

## 📋 Passo 1: Preparar Git (2 min)

Abra o **PowerShell** no Windows e execute:

```powershell
# Ir para o diretório do projeto
cd C:\Users\ç\Downloads\Rotas\flutter_app

# Configurar Git (se primeira vez)
git config --global user.name "Seu Nome"
git config --global user.email "seu@email.com"

# Inicializar repositório
git init

# Adicionar todos os arquivos
git add .

# Ver o que será commitado (opcional)
git status

# Criar commit inicial
git commit -m "Initial commit: Rotas Flutter App completo

- App com SQLite, GPS, TTS
- Navegacao turn-by-turn
- Otimizacao de rotas
- Configuracao Codemagic pronta"
```

✅ **Resultado:** Repositório Git local criado com 1 commit.

---

## 🌐 Passo 2: Criar Repositório no GitHub (3 min)

1. **Acessar:** https://github.com/new

2. **Preencher:**
   - **Repository name:** `rotas-flutter-app`
   - **Description:** `App de navegação e otimização de rotas - General Salgado/SP`
   - **Visibility:** Público ou Privado (sua escolha)
   - ⚠️ **NÃO** marcar "Initialize this repository with a README"
   - ⚠️ **NÃO** adicionar .gitignore ou license (já temos)

3. **Clicar:** "Create repository"

✅ **Resultado:** Repositório vazio criado no GitHub.

---

## 🔗 Passo 3: Conectar Git Local ao GitHub (1 min)

No PowerShell, **substituir `SEU-USUARIO`** pelo seu username do GitHub:

```powershell
# Adicionar remote (SUBSTITUIR SEU-USUARIO!)
git remote add origin https://github.com/SEU-USUARIO/rotas-flutter-app.git

# Renomear branch para main (padrão GitHub)
git branch -M main

# Fazer push
git push -u origin main
```

**Possível erro:** "remote origin already exists"
```powershell
# Solução: remover e adicionar novamente
git remote remove origin
git remote add origin https://github.com/SEU-USUARIO/rotas-flutter-app.git
git push -u origin main
```

✅ **Resultado:** Código no GitHub! Acesse `https://github.com/SEU-USUARIO/rotas-flutter-app`

---

## ☁️ Passo 4: Cadastrar no Codemagic (3 min)

1. **Acessar:** https://codemagic.io/signup

2. **Clicar:** "Sign up with GitHub"

3. **Autorizar:** Permitir Codemagic acessar seus repositórios
   - Pode escolher "Only select repositories" e selecionar apenas `rotas-flutter-app`
   - Ou "All repositories" (mais fácil)

4. **Confirmar email** se solicitado

✅ **Resultado:** Conta Codemagic criada e conectada ao GitHub.

---

## 🚀 Passo 5: Adicionar App no Codemagic (2 min)

1. **No dashboard Codemagic:** https://codemagic.io/apps

2. **Clicar:** "Add application"

3. **Selecionar:**
   - Repository: `rotas-flutter-app`
   - Project type: **"Flutter App"**

4. **Clicar:** "Finish: Add application"

✅ **Resultado:** App adicionado no Codemagic.

---

## 🔧 Passo 6: Configurar e Buildar (2 min setup + 10 min build)

1. **Na página do app, clicar:** "Start your first build"

2. **Configurar:**
   - **Workflow:** `rotas-app` (build iOS + Android)
   - **Branch:** `main`
   - Deixar outras opções padrão

3. **Clicar:** "Start new build"

4. **Aguardar:** 10-15 minutos
   - Pode ver logs em tempo real
   - Progresso: Preparing → Building → Finishing

✅ **Resultado:** Build concluído! Status: ✅ Success

---

## 📥 Passo 7: Baixar e Testar (3 min)

1. **Na página do build,** rolar até seção **"Artifacts"**

2. **Downloads disponíveis:**
   - ✅ `app-release.apk` → Android APK (testar no celular)
   - ✅ `app-release.aab` → Android App Bundle (publicar Play Store)
   - ✅ `Runner.app` → iOS App (só validação, sem assinatura)

3. **Testar no Android:**
   - Transferir `app-release.apk` para celular
   - Abrir arquivo no celular
   - Permitir "Instalar de fontes desconhecidas"
   - Instalar e abrir app

✅ **Resultado:** App funcionando no Android!

---

## 🔄 Passo 8: Builds Futuros (Automático!)

Sempre que você fizer alterações:

```powershell
cd C:\Users\ç\Downloads\Rotas\flutter_app

# Fazer mudanças no código...

# Adicionar e commitar
git add .
git commit -m "Descrição da mudança"

# Push
git push
```

→ **Build automático no Codemagic!** 🎉

Você receberá email quando terminar.

---

## 📊 Resumo Final

Ao concluir, você terá:

✅ Código no GitHub  
✅ Build iOS automático (sem Mac)  
✅ Build Android automático  
✅ 500 minutos grátis/mês no Codemagic  
✅ CI/CD configurado  
✅ APK pronto para testar  

---

## 🐛 Troubleshooting

### Git push pede senha
```powershell
# Usar token pessoal do GitHub (não senha)
# Criar token em: https://github.com/settings/tokens
# Usar token como senha ao fazer push
```

### Build falhou no Codemagic
- Ver **logs completos** na interface
- Erro comum: arquivo `rotas.db` não encontrado
  - Solução: Verificar que existe em `assets/database/rotas.db`

### Codemagic não detectou codemagic.yaml
- Verificar que arquivo está na **raiz do projeto**
- Nome exato: `codemagic.yaml` (não .yml)

### Sem minutos grátis restantes
- Limite: 500 min/mês
- Aguardar próximo mês ou fazer upgrade

---

## 📞 Links Úteis

- **GitHub:** https://github.com/SEU-USUARIO/rotas-flutter-app
- **Codemagic Dashboard:** https://codemagic.io/apps
- **Docs Codemagic:** https://docs.codemagic.io
- **Seu perfil Codemagic:** https://codemagic.io/profile

---

**Tempo total: ~20 minutos** ⏱️  
**Resultado: App buildado iOS + Android** 🎉
