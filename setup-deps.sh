#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# Script        : setup-deps.sh
# Descrição     : Configura dependências do sistema para WebKit4.1 + GTK3
# Autor         : Rafael Batista
# Versão        : 1.2.0 (Remove rust/gcc do layer; adiciona guards de GPG e transação)
# ──────────────────────────────────────────────────────────────────────────────

# set -e removido temporariamente no escopo global para evitar quebras silenciosas
set -uo pipefail

# ── Cores ─────────────────────────────────────────────────────────────────────
G="\033[1;32m"; B="\033[1;34m"; Y="\033[1;33m"; R="\033[1;31m"; C="\033[1;36m"; N="\033[0m"

log()     { echo -e "${B}[INFO]${N}    $*"; }
success() { echo -e "${G}[OK]${N}      $*"; }
warn()    { echo -e "${Y}[AVISO]${N}   $*"; }
error()   { echo -e "${R}[ERRO]${N}    $*" >&2; }
step()    { echo -e "${C}[→]${N}       $*"; }

# ── Detecção de Ambiente ──────────────────────────────────────────────────────
detect_package_manager() {
    if [ -f /run/.containerenv ] || [ -f /.dockerenv ]; then
        if command -v dnf &>/dev/null; then
            echo "dnf"
            return
        fi
    fi

    if command -v rpm-ostree &>/dev/null; then
        echo "rpm-ostree"
    elif command -v dnf &>/dev/null; then
        echo "dnf"
    else
        echo "unknown"
    fi
}

# ── Instalação via rpm-ostree (Host Kinoite) ──────────────────────────────────
setup_fedora_rpm_ostree() {
    log "═══ Iniciando Layering de Dependências via rpm-ostree ═══"

    # rust/cargo/gcc removidos: puxam rust-std-static → glibc-devel → conflito
    # de glibc no depsolve do rpm-ostree. Rust é instalado via rustup após reboot.
    local pacotes=(
        webkit2gtk4.1-devel
        libappindicator-gtk3-devel
        libsoup-devel
        gtk3-devel
        glib2-devel
        gobject-introspection-devel
        libxcb-devel
        openssl-devel
        lld
        clang
    )

    step "Verificando transação rpm-ostree em andamento..."
    if rpm-ostree status 2>&1 | grep -q "Transaction in progress"; then
        warn "Transação em andamento detectada. Cancelando antes de prosseguir..."
        rpm-ostree cancel || true
        sleep 2
    fi

    step "Limpando cache de metadados RPM Fusion (evita erro de chave GPG corrompida)..."
    sudo rm -rf /var/cache/rpm-ostree/repomd/rpmfusion-free-updates-44-x86_64/
    sudo rm -rf /var/cache/rpm-ostree/repomd/rpmfusion-free-44-x86_64/
    sudo rm -rf /var/cache/rpm-ostree/repomd/rpmfusion-nonfree-updates-44-x86_64/
    sudo rm -rf /var/cache/rpm-ostree/repomd/rpmfusion-nonfree-44-x86_64/

    step "Verificando quais pacotes já estão instalados no layer..."

    local faltando=()
    for pkg in "${pacotes[@]}"; do
        # verifica tanto no layer (rpm-ostree) quanto no sistema base (rpm -q)
        if rpm -q "$pkg" &>/dev/null; then
            log "  ✓ já instalado: $pkg"
        else
            faltando+=("$pkg")
        fi
    done

    if [ ${#faltando[@]} -eq 0 ]; then
        success "Todos os pacotes já estão instalados. Nada a fazer."
        return 0
    fi

    echo ""
    log "Pacotes faltando (${#faltando[@]}): ${faltando[*]}"
    echo ""

    step "Solicitando privilégios para o comando rpm-ostree..."
    if sudo rpm-ostree install --idempotent "${faltando[@]}"; then
        success "Layering concluído com sucesso pelo rpm-ostree."
        echo ""
        warn "📢 ATENÇÃO: Para aplicar as alterações na árvore imutável do sistema,"
        warn "é obrigatório reiniciar a máquina."
        warn "Execute: sudo systemctl reboot"
        echo ""
        log "Após o reboot, instale Rust via rustup (não via rpm-ostree):"
        log "  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
        log "  source \"\$HOME/.cargo/env\""
    else
        error "Falha ao aplicar pacotes via rpm-ostree."
        exit 1
    fi
}

# ── Instalação via DNF (Fallback para Container/Toolbox) ──────────────────────
setup_fedora_dnf() {
    log "═══ Configurando dependências via DNF ═══"

    step "Instalando pacotes de desenvolvimento no container..."
    sudo dnf install -y \
        webkit2gtk4.1-devel \
        libappindicator-gtk3-devel \
        libsoup-devel \
        gtk3-devel \
        glib2-devel \
        gobject-introspection-devel \
        libxcb-devel \
        openssl-devel \
        rust cargo \
        lld clang

    success "Dependências instaladas com sucesso no ambiente DNF."
    log "Rust instalado via dnf no container (dnf não tem o problema de glibc-devel do rpm-ostree)."
}

# ── Fluxo Principal ───────────────────────────────────────────────────────────
main() {
    log "═══ Automated Installer — Claw Launcher Dependencies ═══"

    local pkg_manager
    pkg_manager=$(detect_package_manager)

    log "Ambiente ativo detectado: $pkg_manager"
    echo "────────────────────────────────────────────────"

    case "$pkg_manager" in
        rpm-ostree)
            setup_fedora_rpm_ostree
            ;;
        dnf)
            setup_fedora_dnf
            ;;
        *)
            error "Gerenciador de pacotes não suportado ou ambiente desconhecido."
            exit 1
            ;;
    esac
}

# ── Execução Direta Forçada ───────────────────────────────────────────────────
main "$@"
