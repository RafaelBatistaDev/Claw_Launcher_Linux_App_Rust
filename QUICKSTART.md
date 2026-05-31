# π INΓCIO RΓPIDO - CLAW Launcher v2.2.0

## β‘ 3 Passos para ComeΓ§ar

### 1οΈβ£ Compilar
```bash
cd ./Claw_Launcher_Linux_App_Rust-main
chmod +x *.sh
./create_app.sh build      # Menu interativo (configura e valida deps automaticamente)
```
```bash
# Kill any cargo or rustc processes running in the background
pkill -9 cargo
pkill -9 rustc
```
```bash
#Iniciar

cd ./Claw_Launcher_Linux_App_Rust-main
claw-launcher
```


PerguntarΓ‘ se deseja limpar builds antigos β Digite `s` para limpar

### 2οΈβ£ Criar InstΓ’ncia
```bash
./create_app.sh
# Menu β OpΓ§Γ£o 1 ou 2
# Escolha URL do site
```

Ou direto:
```bash
./create_app.sh preconfigured  # Apps prΓ©-configurados
./create_app.sh custom         # URL personalizada
```

### 3οΈβ£ Instalar no Sistema
```bash
./create_app.sh install
```

Pronto! App instalado e acessΓ­vel no menu de aplicativos

---

## π Comandos Γteis

### Criar Apps
```bash
./create_app.sh custom                          # Criar personalizado
./create_app.sh preconfigured                   # PrΓ©-configurados
./create_app.sh create "MeuApp" "https://..." # Via CLI
```

### Gerenciar InstalaΓ§Γ΅es
```bash
./create_app.sh install                         # Instalar
./create_app.sh uninstall                       # Desinstalar
./create_app.sh list                            # Listar todos
```

### Limpeza
```bash
./create_app.sh clean                           # Limpar builds
./create_app.sh build                           # Compilar (com opΓ§Γ£o de limpar)
```
### Setup de Dependências (integrado ao create_app.sh)
```bash
./create_app.sh                # Opção 10 no menu: Setup de Dependências
# Configura WebKit6 + Libadwaita automaticamente durante build se necessário
```
### CompilaΓ§Γ£o
```bash
./create_app.sh build                           # Build + instalar binΓ‘rio
cd src-tauri && cargo build --release           # Build direto Cargo
```

---

## π Se Algo Der Errado

### Apps Aparecem Duplicados
β **FIXO!** Script agora detecta e pergunta antes de sobrescrever

### Cookies NΓ£o Persistem
β **FIXO!** Agora salvos em `~/.local/share/{APP_ID}/webkit/`

Para testar:
```bash
./create_app.sh # β OpΓ§Γ£o 6: Limpar cache
# Escolha app β Cookies serΓ£o removidos
# Reabra app β DeverΓ‘ estar deslogado
```

### Links Abrem em Janelas Isoladas
β **FIXO!** Links agora abrem na mesma janela com comportamento de navegador

### EspaΓ§o em Disco Cheio
```bash
./create_app.sh clean     # Remove builds >30 dias (economiza 500MB-1GB)
```

---

## π DocumentaΓ§Γ£o Completa

Se precisa de mais informaΓ§Γ΅es:

| Documento | Assunto |
|-----------|---------|
| [RESUMO_FINAL.md](RESUMO_FINAL.md) | VisΓ£o geral de tudo |
| [CHANGELOG_FIXES.md](CHANGELOG_FIXES.md) | Detalhes tΓ©cnicos |
| [TEST_GUIDE.sh](TEST_GUIDE.sh) | Testar funcionalidades |
| [CLEAN_BUILDS_GUIDE.md](CLEAN_BUILDS_GUIDE.md) | Limpeza de builds |
| [GITIGNORE_GUIDE.md](GITIGNORE_GUIDE.md) | ConfiguraΓ§Γ£o Git |

---

## π― Fluxo TΓ­pico de Uso

```
βββββββββββββββββββββββββββββββββββββββ
β 1. Clone o repositΓ³rio              β
βββββββββββββββ¬ββββββββββββββββββββββββ
              β
βββββββββββββββββββββββββββββββββββββββ
β 2. ./create_app.sh build            β
β    (Compila + Instala binΓ‘rio)      β
βββββββββββββββ¬ββββββββββββββββββββββββ
              β
βββββββββββββββββββββββββββββββββββββββ
β 3. ./create_app.sh preconfigured    β
β    (Cria primeira instΓ’ncia)        β
βββββββββββββββ¬ββββββββββββββββββββββββ
              β
βββββββββββββββββββββββββββββββββββββββ
β 4. ./create_app.sh install          β
β    (Instala no sistema)             β
βββββββββββββββ¬ββββββββββββββββββββββββ
              β
βββββββββββββββββββββββββββββββββββββββ
β 5. Procure por "Claw_*" no menu     β
β    de aplicativos e abra!           β
βββββββββββββββββββββββββββββββββββββββ
```

---

## πΎ Como Compartilhar Projeto

### Limpar RepositΓ³rio (IMPORTANTE!)
```bash
bash cleanup-git.sh
# β OpΓ§Γ£o 5: Apenas .gitignore (seguro)
# ou
# β OpΓ§Γ£o 4: Limpeza completa (se tem histΓ³rico grande)

git add -A
git commit -m "v2.2.0: .gitignore refatorado"
git push origin main
```

### Novo UsuΓ‘rio Clonar
```bash
git clone <repo>
cd CLAW_Launcher_Rust
./create_app.sh build
./create_app.sh custom
```

Cada usuΓ‘rio cria suas instΓ’ncias localmente β Nada Γ© compartilhado!

---

## π ConfirmaΓ§Γ£o: Tudo Funcionando?

```bash
# Verificar binΓ‘rio compilado
ls -lh src-tauri/target/release/claw-launcher
# Output: claw-launcher (8.3MB) β

# Verificar .gitignore
cat .gitignore | head -20
# Output: Bem documentado β

# Listar documentaΓ§Γ£o
ls -1 *.md cleanup-git.sh
# Output: 7 arquivos de docs β

# Testar menu
./create_app.sh
# Deve mostrar 10 opΓ§Γ΅es (0-9) β
```

---

## π Suporte RΓ‘pido

**Pergunta:** Como removo um app?
```bash
./create_app.sh
# β OpΓ§Γ£o 4: Desinstalar instΓ’ncia
```

**Pergunta:** Posso mudar a URL de um app?
```bash
# Edite instance_NomeApp/instance.conf
vi instance_NomeApp/instance.conf
# Mude URL= ...
# Reinstale: ./create_app.sh install
```

**Pergunta:** Preciso recompilar. Como nΓ£o deixar arrastando arquivo antigos?
```bash
./create_app.sh build
# β Limpar builds antigos antes de compilar? s
```

---

## β¨ VersΓ£o

**v2.2.0** - 25 de maio de 2026

MudanΓ§as:
- β Corrigido: DuplicaΓ§Γ£o de apps
- β Corrigido: PersistΓͺncia de cookies
- β Corrigido: Comportamento de links/pop-ups
- β Adicionado: Limpeza de builds
- β Refatorado: .gitignore (99% reduΓ§Γ£o)

---

π **Pronto para usar!** π

Qualquer dΓΊvida, consulte a documentaΓ§Γ£o completa nos arquivos `.md`
