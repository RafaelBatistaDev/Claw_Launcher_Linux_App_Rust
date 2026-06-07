#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# Script       : install.sh
# Descrição    : Instalador completo do claw-launcher
#                Orquestra: setup-deps.sh → build.sh → instalação do binário
# Autor        : Rafael Batista
# Versão       : 1.0.2
# Uso          : ./install.sh [--skip-deps] [--skip-build] [--uninstall]
# ──────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ── Exporta PKG_CONFIG_PATH para WebKit4.1 + Libadwaita (evita falhas de pkg-config) ──
export PKG_CONFIG_PATH="/usr/lib64/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/lib/pkgconfig:/usr/local/lib/pkgconfig:/usr/share/pkgconfig:${PKG_CONFIG_PATH:-}"

# ── Cores (mesma paleta de setup-deps.sh e build.sh) ─────────────────────────
G="\033[1;32m"; B="\033[1;34m"; Y="\033[1;33m"; R="\033[1;31m"; C="\033[1;36m"; N="\033[0m"

log()     { echo -e "${B}[INFO]${N}    $*"; }
success() { echo -e "${G}[OK]${N}      $*"; }
warn()    { echo -e "${Y}[AVISO]${N}   $*"; }
error()   { echo -e "${R}[ERRO]${N}    $*" >&2; }
step()    { echo -e "${C}[→]${N}       $*"; }

# ── Configurações ─────────────────────────────────────────────────────────────
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
BINARY_NAME="claw-launcher"
BINARY_SRC="${SCRIPT_DIR}/src-tauri/target/release/${BINARY_NAME}"
INSTALL_DIR="${HOME}/.local/bin"
INSTALL_PATH="${INSTALL_DIR}/${BINARY_NAME}"
DESKTOP_DIR="${HOME}/.local/share/applications"
DESKTOP_FILE="${DESKTOP_DIR}/${BINARY_NAME}.desktop"
ICON_DIR="${HOME}/.local/share/icons/hicolor/256x256/apps"
ICON_SRC="${SCRIPT_DIR}/ICON"   # pasta com os ícones do projeto

# ── Flags ─────────────────────────────────────────────────────────────────────
SKIP_DEPS=false
SKIP_BUILD=false
DO_UNINSTALL=false

parse_args() {
    for arg in "$@"; do
        case "$arg" in
            --skip-deps)    SKIP_DEPS=true ;;
            --skip-build)   SKIP_BUILD=true ;;
            --uninstall)    DO_UNINSTALL=true ;;
            --help|-h)      usage; exit 0 ;;
            *)
                error "Argumento desconhecido: $arg"
                usage
                exit 1
                ;;
        esac
    done
}

usage() {
    echo -e "${C}Uso:${N} $0 [opções]"
    echo ""
    echo "  (sem opções)    Instalação completa"
    echo "  --skip-deps     Pula o setup-deps.sh (dependências já instaladas)"
    echo "  --skip-build    Pula o build.sh (binário já compilado)"
    echo "  --uninstall     Remove binário, .desktop e ícone"
    echo "  --help          Exibe esta ajuda"
}

# ── Validações iniciais ───────────────────────────────────────────────────────
check_project_root() {
    if [ ! -f "${SCRIPT_DIR}/build.sh" ]; then
        error "build.sh não encontrado em ${SCRIPT_DIR}"
        error "Execute install.sh a partir da raiz do projeto."
        exit 1
    fi
    if [ ! -f "${SCRIPT_DIR}/setup-deps.sh" ]; then
        error "setup-deps.sh não encontrado em ${SCRIPT_DIR}"
        error "Execute install.sh a partir da raiz do projeto."
        exit 1
    fi
    if [ ! -f "${SCRIPT_DIR}/src-tauri/Cargo.toml" ]; then
        error "src-tauri/Cargo.toml não encontrado. Estrutura do projeto inválida."
        exit 1
    fi
}

# ── Passo 1: Dependências (delega para setup-deps.sh) ────────────────────────
run_setup_deps() {
    if [ "$SKIP_DEPS" = true ]; then
        warn "Pulando setup de dependências (--skip-deps)"
        return 0
    fi

    log "═══ Passo 1/4: Instalando dependências do sistema ═══"
    step "Delegando para setup-deps.sh..."
    bash "${SCRIPT_DIR}/setup-deps.sh"

    if ! pkg-config --exists webkit2gtk-4.1 2>/dev/null; then
        warn "webkit2gtk-4.1 ainda não visível via pkg-config."
        warn "Se usou rpm-ostree, reinicie o sistema e execute novamente:"
        warn "  ./install.sh --skip-deps"
        exit 0
    fi

    success "Dependências verificadas."
}

# ── Passo 2: Build (delega para build.sh) ─────────────────────────────────────
run_build() {
    if [ "$SKIP_BUILD" = true ]; then
        warn "Pulando compilação (--skip-build)"
        if [ ! -f "$BINARY_SRC" ]; then
            error "Binário não encontrado em ${BINARY_SRC}"
            error "Execute sem --skip-build para compilar primeiro."
            exit 1
        fi
        return 0
    fi

    log "═══ Passo 2/4: Compilando claw-launcher ═══"
    step "Delegando para build.sh..."
    bash "${SCRIPT_DIR}/build.sh" --no-clean

    if [ ! -f "$BINARY_SRC" ]; then
        error "build.sh concluiu mas o binário não foi encontrado em ${BINARY_SRC}"
        exit 1
    fi

    success "Binário compilado: ${BINARY_SRC}"
}

# ── Passo 3: Instalar binário ────────────────────────────────────────────────
install_binary() {
    log "═══ Passo 3/4: Instalando binário ═══"

    mkdir -p "$INSTALL_DIR"
    rm -f "$INSTALL_PATH"
    cp "$BINARY_SRC" "$INSTALL_PATH"
    chmod 755 "$INSTALL_PATH"

    success "Binário instalado: ${INSTALL_PATH}"
    log "Tamanho: $(du -sh "$INSTALL_PATH" | cut -f1)"

    local shell_rc="${HOME}/.bashrc"
    [ -f "${HOME}/.zshrc" ] && shell_rc="${HOME}/.zshrc"

    if [ -f "$shell_rc" ]; then
        if ! grep -Fq "${INSTALL_DIR}" "$shell_rc"; then
            echo "export PATH=\"\${HOME}/.local/bin:\${PATH}\"" >> "$shell_rc"
            warn "Adicionado ao ${shell_rc}. Execute: source ${shell_rc}"
        fi
    else
        if ! echo "$PATH" | grep -q "${INSTALL_DIR}"; then
            warn "${INSTALL_DIR} não está no PATH e nenhum arquivo de configuração (*.bashrc/*.zshrc) foi encontrado."
        fi
    fi
}

# ── Passo 4: Criar .desktop e ícone ──────────────────────────────────────────
install_desktop() {
    log "═══ Passo 4/4: Criando entrada no menu de aplicações ═══"

    mkdir -p "$DESKTOP_DIR"
    mkdir -p "$ICON_DIR"

    local icon_name="${BINARY_NAME}"
    local icon_installed="${ICON_DIR}/${icon_name}.png"

    local icon_file="${ICON_SRC}/claw-launcher.png"
    if [ -f "$icon_file" ]; then
        cp "$icon_file" "$icon_installed"
        chmod 644 "$icon_installed"
        success "Ícone instalado: ${icon_installed}"
    elif [ -d "$ICON_SRC" ]; then
        local fallback_file
        fallback_file=$(find "$ICON_SRC" -name "*.png" 2>/dev/null | sort | head -n 1 || true)
        if [ -n "$fallback_file" ] && [ -f "$fallback_file" ]; then
            cp "$fallback_file" "$icon_installed"
            chmod 644 "$icon_installed"
            success "Ícone instalado (fallback): ${icon_installed}"
        else
            warn "Nenhum arquivo PNG válido encontrado em ${ICON_SRC} — .desktop sem ícone."
            icon_name=""
        fi
    else
        warn "Pasta de ícones não encontrada em ${ICON_SRC} — .desktop sem ícone."
        icon_name=""
    fi

    cat > "$DESKTOP_FILE" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Claw Launcher
Comment=WebApp Launcher para Fedora Kinoite
Exec=${INSTALL_PATH}
Icon=${icon_name}
Terminal=false
Categories=Network;WebBrowser;Utility;
Keywords=webapp;launcher;browser;
StartupWMClass=claw-launcher
StartupNotify=true
EOF

    chmod 644 "$DESKTOP_FILE"
    success "Arquivo .desktop criado: ${DESKTOP_FILE}"

    update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
    gtk-update-icon-cache -f -t "$ICON_DIR/../../../" 2>/dev/null || true

    success "Menu de aplicações atualizado."
}

# ── Desinstalação ─────────────────────────────────────────────────────────────
uninstall() {
    log "═══ Desinstalando claw-launcher ═══"

    local removed=0

    if [ -f "$INSTALL_PATH" ]; then
        rm -f "$INSTALL_PATH"
        success "Binário removido: ${INSTALL_PATH}"
        ((removed++))
    else
        warn "Binário não encontrado: ${INSTALL_PATH}"
    fi

    if [ -f "$DESKTOP_FILE" ]; then
        rm -f "$DESKTOP_FILE"
        success ".desktop removido: ${DESKTOP_FILE}"
        ((removed++))
    else
        warn ".desktop não encontrado: ${DESKTOP_FILE}"
    fi

    if [ -f "${ICON_DIR}/${BINARY_NAME}.png" ]; then
        rm -f "${ICON_DIR}/${BINARY_NAME}.png"
        success "Ícone removido."
        ((removed++))
    fi

    local share_claw="${HOME}/.local/share/claw-launcher"
    if [ -d "$share_claw" ]; then
        rm -rf "$share_claw"
        success "Recursos removidos de ${share_claw}"
        ((removed++))
    fi

    update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true

    if [ $removed -gt 0 ]; then
        success "═══ Desinstalação concluída ($removed item(s) removido(s)) ═══"
    else
        warn "Nenhum arquivo encontrado para remover."
    fi
}

# ── Passo 3.5: Instalar recursos do Claw Launcher ────────────────────────────
install_resources() {
    log "═══ Passo Extra: Instalando recursos do Claw Launcher ═══"

    local share_claw="${HOME}/.local/share/claw-launcher"
    mkdir -p "$share_claw"

    # Salva a raiz do projeto de forma absoluta para o create_app.sh saber onde criar as instâncias
    echo "PROJECT_ROOT=\"${SCRIPT_DIR}\"" > "${share_claw}/project_root.conf"
    chmod 644 "${share_claw}/project_root.conf"

    # Copia o script principal, o de dependências e a pasta de ícones
    cp "${SCRIPT_DIR}/create_app.sh" "${share_claw}/"
    chmod 755 "${share_claw}/create_app.sh"

    if [ -f "${SCRIPT_DIR}/setup-deps.sh" ]; then
        cp "${SCRIPT_DIR}/setup-deps.sh" "${share_claw}/"
        chmod 755 "${share_claw}/setup-deps.sh"
    fi

    if [ -d "${SCRIPT_DIR}/ICON" ]; then
        cp -r "${SCRIPT_DIR}/ICON" "${share_claw}/"
        success "Recursos e pasta ICON copiados para: ${share_claw}"
    else
        warn "Pasta ICON não encontrada em ${SCRIPT_DIR} para copiar."
    fi
}

# ── Resumo pós-instalação ─────────────────────────────────────────────────────
print_summary() {
    echo ""
    echo -e "${G}╔══════════════════════════════════════════════╗${N}"
    echo -e "${G}║       Claw Launcher instalado com sucesso!   ║${N}"
    echo -e "${G}╚══════════════════════════════════════════════╝${N}"
    echo ""
    echo -e "  ${C}Binário :${N} ${INSTALL_PATH}"
    echo -e "  ${C}.desktop:${N} ${DESKTOP_FILE}"
    echo -e "  ${C}Ícone   :${N} ${ICON_DIR}/${BINARY_NAME}.png"
    echo ""
    echo -e "  Para executar: ${B}claw-launcher${N}"
    echo -e "  Ou abra pelo menu de aplicações do seu desktop."
    echo ""
}

# ── Entry Point com Guarda de Sourcing ────────────────────────────────────────
main() {
    parse_args "$@"

    if [ "$DO_UNINSTALL" = true ]; then
        uninstall
        exit 0
    fi

    log "═══ Instalador Claw Launcher ═══"
    check_project_root

    run_setup_deps
    run_build
    install_binary
    install_resources
    install_desktop
    print_summary
}

# Só executa a lógica principal se o arquivo for chamado diretamente.
# Se for incluído via 'source' ou '.', apenas exporta as variáveis e funções.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi