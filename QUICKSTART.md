# 🚀 INÍCIO RÁPIDO - CLAW Launcher

## ⚠️ 3 Passos para Começar

### 1️⃣ Compilar e Instalar o App Principal
O script [build.sh](file:///var/home/recifecrypto/GoogleDrive/Claw_Launcher_Linux_App_Rust-main/build.sh) configura automaticamente as permissões dos scripts, sincroniza as dependências Python usando `uv sync`, limpa builds anteriores e compila o binário otimizado:
```bash
./build.sh
```

### 2️⃣ Criar Instância de Aplicativo Web
Utilize o assistente para criar uma nova instância (você pode escolher um app pré-configurado ou digitar um link customizado):
```bash
./create_app.sh
# Selecione Opção 1 (pré-configurado) ou Opção 2 (customizado)
```

Ou chame diretamente:
```bash
./create_app.sh preconfigured   # Menu de Apps pré-configurados (OneNote, Instagram, etc)
./create_app.sh custom          # Criação livre com URL personalizada
```

### 3️⃣ Instalar Instância no Sistema
Instale a instância gerada para que ela seja integrada ao seu menu do sistema desktop:
```bash
./create_app.sh install
```

Pronto! O aplicativo estará acessível no menu de aplicativos do seu sistema.

---

## 📌 Comandos Úteis

### Criar Apps
```bash
./create_app.sh custom                          # Criar personalizado
./create_app.sh preconfigured                   # Criar pré-configurado
./create_app.sh create "MeuApp" "https://..."   # Criação direta via CLI
```

### Gerenciar Instalações
```bash
./create_app.sh install                         # Instalar instância criada
./create_app.sh uninstall                       # Desinstalar instância criada
./create_app.sh list                            # Listar todas as instâncias
```

### Limpeza e Purga
```bash
# Limpeza profunda dinâmica: remove binários, atalhos, caches de sessão, venv e builds locais
uv run purg_app.py
```

---

## 🚑 Se Algo Der Errado (Resolução de Problemas)

### Apps Aparecem Duplicados
O instalador agora detecta atalhos duplicados e avisa se você deseja substituir a instalação anterior.

### Cookies Não Persistem
As sessões e cookies são salvos e isolados em `~/.local/share/Claw_{APP_ID}/webkit/` garantindo que você permaneça logado.

Para testar a limpeza:
```bash
./create_app.sh
# Vá na Opção 6 (Limpar Cache) -> Escolha o App -> Os cookies serão removidos.
```

### Espaço em Disco Muito Alto
A compilação do Rust gera muitos arquivos temporários em `src-tauri/target/`. Use o utilitário de purga para limpar tudo:
```bash
uv run purg_app.py
```

---

## 🗺️ Fluxo Típico de Uso

```
┌──────────────────────────────────────┐
│ 1. Clone o repositório               │
└──────────────────┬───────────────────┘
                   │
                   ▼
┌──────────────────────────────────────┐
│ 2. Executar ./build.sh               │
│    (Configura env, compila e instala)│
└──────────────────┬───────────────────┘
                   │
                   ▼
┌──────────────────────────────────────┐
│ 3. Executar ./create_app.sh          │
│    (Cria a instância de WebApp)      │
└──────────────────┬───────────────────┘
                   │
                   ▼
┌──────────────────────────────────────┐
│ 4. Executar ./create_app.sh install  │
│    (Registra atalho e ícone)         │
└──────────────────┬───────────────────┘
                   │
                   ▼
┌──────────────────────────────────────┐
│ 5. Abra "Claw_*" no seu menu de apps │
└──────────────────────────────────────┘
```

---

## ✨ Versão
**v2.3.0**
- ✅ Corrigido: Inicialização de ícones internos na tela inicial do Launcher Tauri.
- ✅ Adicionado: Script de purga profunda (`purg_app.py`) integrando remoção automática de `.venv/` e `uv.lock`.
- ✅ Refatorado: `build.sh` agora sincroniza o ambiente Python via `uv sync` e ajusta as permissões locais.
- ✅ Corrigido: Quebra de caracteres e codificação na documentação.
