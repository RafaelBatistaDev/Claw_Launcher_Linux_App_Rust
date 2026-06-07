#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# Script       : build.sh
# Descrição    : Build script para claw-launcher (Tauri + Rust)
# Autor        : Rafael Batista
# ──────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ── Cores ─────────────────────────────────────────────────────────────────────
G="\033[1;32m"; B="\033[1;34m"; Y="\033[1;33m"; R="\033[1;31m"; C="\033[1;36m"; N="\033[0m"

log()     { echo -e "${B}[INFO]${N}    $*"; }
success() { echo -e "${G}[OK]${N}      $*"; }
warn()    { echo -e "${Y}[AVISO]${N}   $*"; }
error()   { echo -e "${R}[ERRO]${N}    $*" >&2; }
step()    { echo -e "${C}[→]${N}       $*"; }

# ── Configurações ─────────────────────────────────────────────────────────────
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_DIR="${SCRIPT_DIR}/src-tauri"
BUILD_DIR="${SCRIPT_DIR}/src-tauri/target/release"
BINARY_NAME="claw-launcher"
BINARY_PATH="${BUILD_DIR}/${BINARY_NAME}"

# Configurações de Instalação do Usuário
BIN_DIR="${HOME}/.local/bin"
LAUNCHER_BIN="${BIN_DIR}/${BINARY_NAME}"
APPS_DIR="${HOME}/.local/share/applications"
ICONS_BASE="${HOME}/.local/share/icons/hicolor"
ICON_SIZES=("16" "32" "48" "64" "128" "256" "512")

main() {
    log "═══ Configuração e Build claw-launcher ═══"

    # 1. Configurar permissões de todos os scripts da pasta
    step "Configurando permissões de execução dos scripts..."
    chmod +x "${SCRIPT_DIR}/build.sh" \
             "${SCRIPT_DIR}/setup-deps.sh" \
             "${SCRIPT_DIR}/create_app.sh" \
             "${SCRIPT_DIR}/cleanup-git.sh" \
             "${SCRIPT_DIR}/purg_app.py" 2>/dev/null || true
    success "Permissões de execução configuradas para scripts do repositório."

    # 2. Configurar ambiente virtual Python via uv
    step "Configurando o ambiente virtual Python/uv..."
    if command -v uv &>/dev/null; then
        (cd "$SCRIPT_DIR" && uv sync)
        success "Ambiente virtual Python configurado com sucesso via uv."
    else
        warn "Ferramenta 'uv' não encontrada. Pulando sincronização de dependências Python."
    fi

    # 3. Verificar dependências de compilação Rust
    if ! command -v cargo &>/dev/null; then
        error "cargo não encontrado. Instale Rust via rustup."
        exit 1
    fi

    # Informa se sccache está ativo
    if command -v sccache &>/dev/null; then
        step "sccache ativo: $(sccache --version)"
    else
        warn "sccache não encontrado — build sem cache."
    fi

    step "Versão do Rust:"
    rustc --version
    cargo --version

    # Clean (obrigatório para remover build antigo)
    step "Limpando build anterior..."
    cd "$PROJECT_DIR"
    cargo clean

    # Build release
    step "Compilando claw-launcher em release..."
    cargo build --release

    # Verifica se o binário foi criado
    if [ -f "$BINARY_PATH" ]; then
        step "Tornando binário executável..."
        chmod +x "$BINARY_PATH"
        success "Build concluído: $BINARY_PATH"
        ls -lh "$BINARY_PATH"
    else
        error "Binário não encontrado: $BINARY_PATH"
        exit 1
    fi

    # ── Instalação do Aplicativo Principal ────────────────────────────────────
    step "Iniciando instalação do aplicativo principal..."

    # Copiar binário
    mkdir -p "$BIN_DIR"
    if [ -f "$LAUNCHER_BIN" ]; then
        rm -f "${LAUNCHER_BIN}.bak" 2>/dev/null || true
        cp --remove-destination "$LAUNCHER_BIN" "${LAUNCHER_BIN}.bak" 2>/dev/null || true
        step "Backup anterior salvo em ${LAUNCHER_BIN}.bak"
    fi
    rm -f "$LAUNCHER_BIN" 2>/dev/null || true
    cp "$BINARY_PATH" "$LAUNCHER_BIN"
    chmod +x "$LAUNCHER_BIN"
    success "Binário instalado em ${LAUNCHER_BIN}"

    # Criar diretórios globais do Claw para sessões e logs
    step "Criando diretórios globais do Claw para sessões e logs..."
    mkdir -p "${HOME}/.claw/cache"
    mkdir -p "${HOME}/.claw/logs"
    success "Diretórios globais ~/.claw/cache e ~/.claw/logs criados."

    # Salvar o caminho do repositório para o launcher encontrar os ícones/scripts
    mkdir -p "${HOME}/.config/claw-launcher"
    echo "${SCRIPT_DIR}" > "${HOME}/.config/claw-launcher/repo_path.txt"
    step "Caminho do repositório salvo em ~/.config/claw-launcher/repo_path.txt"

    # Instalar ícones
    step "Instalando ícone do claw-launcher..."
    local icon_src="${SCRIPT_DIR}/ICON/claw-launcher.png"
    if [ ! -f "$icon_src" ]; then
        icon_src="${SCRIPT_DIR}/src-tauri/icons/icon.png"
    fi

    if [ -f "$icon_src" ]; then
        for size in "${ICON_SIZES[@]}"; do
            local icon_dir="${ICONS_BASE}/${size}x${size}/apps"
            mkdir -p "$icon_dir"
            if command -v convert &>/dev/null; then
                convert "$icon_src" -resize "${size}x${size}" "${icon_dir}/${BINARY_NAME}.png" 2>/dev/null \
                    || cp "$icon_src" "${icon_dir}/${BINARY_NAME}.png"
            else
                cp "$icon_src" "${icon_dir}/${BINARY_NAME}.png"
            fi
        done
        success "Ícones instalados com sucesso."
    else
        warn "Ícone fonte não encontrado."
    fi

    # Instalar .desktop
    step "Instalando arquivo .desktop..."
    mkdir -p "$APPS_DIR"
    cat > "${APPS_DIR}/${BINARY_NAME}.desktop" << DESKTOP
[Desktop Entry]
Name=Claw Launcher
Comment=Gerenciador de WebApps isolados
Exec=${LAUNCHER_BIN}
Icon=${BINARY_NAME}
Terminal=false
Type=Application
Categories=Utility;System;
DESKTOP
    chmod 644 "${APPS_DIR}/${BINARY_NAME}.desktop"
    success ".desktop do claw-launcher instalado em ${APPS_DIR}"

    # Atualizar cache de atalhos e ícones
    step "Atualizando bancos de dados do desktop..."
    update-desktop-database "$APPS_DIR" 2>/dev/null || true
    gtk-update-icon-cache -f -t "$ICONS_BASE" 2>/dev/null || true

    success "═══ Instalação do Aplicativo Principal Concluída! ═══"
}

main "$@"