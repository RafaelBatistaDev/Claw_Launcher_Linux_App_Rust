#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# Script       : setup-deps.sh
# Descrição    : Configura dependências do sistema para Tauri + WebKit6 + Adwaita
# Autor        : Rafael Batista
# Versão       : 1.0.0
# ──────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ── Cores ─────────────────────────────────────────────────────────────────────
G="\033[1;32m"; B="\033[1;34m"; Y="\033[1;33m"; R="\033[1;31m"; C="\033[1;36m"; N="\033[0m"

log()     { echo -e "${B}[INFO]${N}    $*"; }
success() { echo -e "${G}[OK]${N}      $*"; }
warn()    { echo -e "${Y}[AVISO]${N}   $*"; }
error()   { echo -e "${R}[ERRO]${N}    $*" >&2; }
step()    { echo -e "${C}[→]${N}       $*"; }

# ── Detecção de Sistema Operacional ───────────────────────────────────────────
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    elif [ -f /etc/redhat-release ]; then
        echo "fedora"
    elif [ -f /etc/debian_version ]; then
        echo "debian"
    else
        echo "unknown"
    fi
}

detect_package_manager() {
    if command -v rpm-ostree &>/dev/null; then
        echo "rpm-ostree"
    elif command -v dnf &>/dev/null; then
        echo "dnf"
    elif command -v yum &>/dev/null; then
        echo "yum"
    elif command -v apt-get &>/dev/null; then
        echo "apt-get"
    else
        echo "unknown"
    fi
}

# ── Instalação de Dependências (Fedora/RHEL via rpm-ostree) ──────────────────
setup_fedora_rpm_ostree() {
    log "═══ Configurando dependências para Fedora (rpm-ostree) ═══"
    
    step "Removendo webkit2gtk4.1-devel e libappindicator-gtk3-devel..."
    sudo rpm-ostree uninstall --idempotent \
        webkit2gtk4.1-devel \
        libappindicator-gtk3-devel || warn "Pacotes de remoção não encontrados (normal em primeira execução)"
    
    step "Instalando webkitgtk6.0-devel, libadwaita-devel e dependências de desenvolvimento..."
    sudo rpm-ostree install --idempotent \
        webkitgtk6.0-devel \
        libadwaita-devel \
        gtk3-devel \
        glib2-devel \
        gobject-introspection-devel \
        libxcb-devel \
        openssl-devel \
        rust \
        lld \
        clang
    
    success "Dependências rpm-ostree configuradas."
    warn "⚠️  Será necessário reiniciar o sistema para aplicar as mudanças."
    warn "Execute: sudo systemctl reboot"
}

# ── Instalação de Dependências (Fedora/RHEL via dnf) ────────────────────────
setup_fedora_dnf() {
    log "═══ Configurando dependências para Fedora (dnf) ═══"
    
    step "Removendo webkit2gtk4.1-devel e libappindicator-gtk3-devel..."
    sudo dnf remove -y \
        webkit2gtk4.1-devel \
        libappindicator-gtk3-devel || warn "Pacotes de remoção não encontrados"
    
    step "Instalando webkitgtk6.0-devel, libadwaita-devel e dependências de desenvolvimento..."
    sudo dnf install -y \
        webkitgtk6.0-devel \
        libadwaita-devel \
        gtk3-devel \
        glib2-devel \
        gobject-introspection-devel \
        libxcb-devel \
        openssl-devel \
        rust \
        lld \
        clang
    
    success "Dependências dnf configuradas."
}

# ── Instalação de Dependências (Debian/Ubuntu) ────────────────────────────────
setup_debian() {
    log "═══ Configurando dependências para Debian/Ubuntu ═══"
    
    step "Atualizando índice de pacotes..."
    sudo apt-get update
    
    step "Removendo webkit2gtk4.1-dev e libappindicator3-dev..."
    sudo apt-get remove -y \
        webkit2gtk-4.1 \
        webkit2gtk-4.1-dev \
        libappindicator3-dev || warn "Pacotes de remoção não encontrados"
    
    step "Instalando libwebkitgtk-6.0-dev, libadwaita-1-dev e dependências de desenvolvimento..."
    sudo apt-get install -y \
        libwebkitgtk-6.0-dev \
        libadwaita-1-dev \
        libgtk-3-dev \
        libglib2.0-dev \
        gobject-introspection-dev \
        libxcb1-dev \
        libssl-dev \
        rust-all \
        lld \
        clang
    
    success "Dependências Debian/Ubuntu configuradas."
}

# ── Validação de Dependências Instaladas ──────────────────────────────────────
verify_dependencies() {
    log "═══ Verificando instalação de dependências ═══"
    
    local missing=0
    
    # Verifica WebKit6
    if pkg-config --exists webkitgtk-6.0 2>/dev/null; then
        success "✓ webkitgtk6.0-devel instalado"
    else
        error "✗ webkitgtk6.0-devel NÃO encontrado"
        ((missing++))
    fi
    
    # Verifica libadwaita
    if pkg-config --exists libadwaita-1 2>/dev/null; then
        success "✓ libadwaita-devel instalado"
    else
        error "✗ libadwaita-devel NÃO encontrado"
        ((missing++))
    fi
    
    # Verifica glib2
    if pkg-config --exists glib-2.0 2>/dev/null; then
        success "✓ glib2-devel instalado"
    else
        error "✗ glib2-devel NÃO encontrado"
        ((missing++))
    fi
    
    # Verifica gobject
    if pkg-config --exists gobject-2.0 2>/dev/null; then
        success "✓ gobject-introspection-devel instalado"
    else
        error "✗ gobject-introspection-devel NÃO encontrado"
        ((missing++))
    fi
    
    # Verifica se WebKit4.1 foi removido (aviso se ainda presente)
    if pkg-config --exists webkit2gtk-4.1 2>/dev/null; then
        warn "⚠️  webkit2gtk-4.1-devel ainda está instalado (pode causar conflitos)"
    else
        success "✓ webkit2gtk-4.1-devel removido com sucesso"
    fi
    
    # Verifica se libappindicator foi removido (aviso se ainda presente)
    if pkg-config --exists appindicator3-0.1 2>/dev/null; then
        warn "⚠️  libappindicator3-dev ainda está instalado (pode causar conflitos)"
    else
        success "✓ libappindicator-gtk3-devel removido com sucesso"
    fi
    
    if [ $missing -eq 0 ]; then
        success "═══ Todas as dependências estão correctamente instaladas ═══"
        return 0
    else
        error "═══ $missing dependência(s) ausente(s) ═══"
        return 1
    fi
}

# ── Configuração de PKG_CONFIG_PATH ──────────────────────────────────────────
setup_pkg_config_path() {
    log "═══ Configurando PKG_CONFIG_PATH ═══"
    
    local pkg_config_paths=()
    local shell_config="${HOME}/.bashrc"
    
    # Detecta shell (bash, zsh, fish)
    if [ -f "${HOME}/.zshrc" ]; then
        shell_config="${HOME}/.zshrc"
    elif [ -f "${HOME}/.config/fish/config.fish" ]; then
        shell_config="${HOME}/.config/fish/config.fish"
    fi
    
    # Procura por arquivos .pc de WebKit em locais comuns
    step "Procurando arquivos .pc de WebKit e libadwaita..."
    
    for path in /usr/lib64/pkgconfig /usr/lib/x86_64-linux-gnu/pkgconfig \
                /usr/lib/pkgconfig /usr/local/lib/pkgconfig \
                /usr/share/pkgconfig /opt/local/lib/pkgconfig; do
        if [ -d "$path" ]; then
            if ls "$path"/webkit*.pc "$path"/libadwaita*.pc 2>/dev/null | grep -q .; then
                pkg_config_paths+=("$path")
                success "Encontrado: $path"
            fi
        fi
    done
    
    if [ ${#pkg_config_paths[@]} -eq 0 ]; then
        warn "Nenhum arquivo .pc encontrado. Isso pode indicar que os pacotes não foram instalados."
        warn "Tente executar novamente este script ou verifique: rpm-ostree status"
        return 1
    fi
    
    # Constrói PKG_CONFIG_PATH único
    local new_pkg_config_path=$(printf '%s:' "${pkg_config_paths[@]}" | sed 's/:$//')
    new_pkg_config_path="${new_pkg_config_path}:${PKG_CONFIG_PATH:-}"
    
    # Exporta imediatamente para a sessão atual
    export PKG_CONFIG_PATH="$new_pkg_config_path"
    success "PKG_CONFIG_PATH configurado para esta sessão."
    log "Valor: $PKG_CONFIG_PATH"
    
    # Adiciona ao arquivo de configuração de shell se ainda não existir
    if ! grep -q "PKG_CONFIG_PATH.*webkit" "$shell_config" 2>/dev/null; then
        step "Adicionando PKG_CONFIG_PATH ao $shell_config..."
        cat >> "$shell_config" << 'EOF'

# ── PKG_CONFIG_PATH para WebKit6 + Libadwaita (Claw Launcher) ──────────────
export PKG_CONFIG_PATH="/usr/lib64/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/lib/pkgconfig:/usr/local/lib/pkgconfig:/usr/share/pkgconfig:${PKG_CONFIG_PATH}"
EOF
        success "PKG_CONFIG_PATH persistido em $shell_config"
        warn "Execute: source $shell_config (ou reinicie o terminal)"
    else
        success "PKG_CONFIG_PATH já está configurado em $shell_config"
    fi
}

# ── Configuração de Otimização de Build (LLD + sccache) ──────────────────────
setup_cargo_optimizations() {
    log "═══ Configurando otimizações de build (LLD + sccache) ═══"
    
    local cargo_config="${HOME}/.cargo/config.toml"
    mkdir -p "${HOME}/.cargo"

    step "Verificando sccache..."
    if ! command -v sccache &>/dev/null; then
        log "Instalando sccache via Cargo..."
        cargo install sccache || warn "Falha ao instalar sccache. Continuando..."
    fi

    step "Configurando $cargo_config..."
    cat > "$cargo_config" << 'EOF'
[build]
rustc-wrapper = "sccache"

[target.x86_64-unknown-linux-gnu]
linker = "clang"
rustflags = ["-C", "link-arg=-fuse-ld=lld"]

[target.aarch64-unknown-linux-gnu]
linker = "clang"
rustflags = ["-C", "link-arg=-fuse-ld=lld"]
EOF
    success "Otimizações aplicadas: Linker LLD ativado e sccache configurado."
}

# ── Menu Principal ────────────────────────────────────────────────────────────
main() {
    log "═══ Setup de Dependências — Claw Launcher ═══"
    log "Sistema Operacional: $(uname -s)"
    
    local distro=$(detect_distro)
    local pkg_manager=$(detect_package_manager)
    
    log "Distro detectada: $distro"
    log "Gerenciador de pacotes: $pkg_manager"
    echo ""
    
    # Redireciona para instalação apropriada
    case "$pkg_manager" in
        rpm-ostree)
            setup_fedora_rpm_ostree
            ;;
        dnf)
            setup_fedora_dnf
            ;;
        apt-get)
            setup_debian
            ;;
        *)
            error "Gerenciador de pacotes não suportado: $pkg_manager"
            error "Instale manualmente:"
            error "  • webkitgtk6.0-devel (ou libwebkitgtk-6.0-dev)"
            error "  • libadwaita-devel (ou libadwaita-1-dev)"
            return 1
            ;;
    esac
    
    echo ""
    verify_dependencies
    
    echo ""
    setup_pkg_config_path

    echo ""
    setup_cargo_optimizations
}

# ── Entry Point ───────────────────────────────────────────────────────────────
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
