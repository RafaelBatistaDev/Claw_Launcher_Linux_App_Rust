#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# Script        : setup-deps.sh
# Descrição     : Configura dependências do sistema para WebKit4.1 + GTK3
# Autor         : Rafael Batista
# Versão        : 1.4.0 (Instala rustup automaticamente se não detectado)
# Uso           : ./setup-deps.sh [install|remove]  (padrão: install)
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

# ── Pacotes de Dependências (compartilhado entre install e remove) ────────────
# rust/cargo/rust-src/rustfmt/clippy excluídos do host rpm-ostree:
# puxam rust-std-static → glibc-devel → conflito de glibc no depsolve.
# gcc excluído pelo mesmo motivo. Instale via rustup após reboot.
PACOTES_RPM_OSTREE=(
    webkit2gtk4.1-devel
    javascriptcoregtk4.1-devel      # javascriptcoregtk-4.1 >= 2.38 (requerido pelo crate)
    libappindicator-gtk3-devel
    libadwaita-devel
    libsoup-devel
    librsvg2-devel
    gtk3-devel
    glib2-devel
    gobject-introspection-devel
    libxcb-devel
    openssl-devel
    make
    lld                             # linker LLVM — até 4x mais rápido que bfd
    clang                           # necessário para usar lld via -fuse-ld=lld
)

PACOTES_DNF=(
    webkit2gtk4.1-devel
    javascriptcoregtk4.1-devel
    libappindicator-gtk3-devel
    libadwaita-devel
    libsoup-devel
    librsvg2-devel
    gtk3-devel
    glib2-devel
    gobject-introspection-devel
    libxcb-devel
    openssl-devel
    rust cargo
    rust-src
    rustfmt
    clippy
    gcc
    make
    lld clang
)

# ── Instalação de Rust via rustup ────────────────────────────────────────────
install_rustup() {
    step "Verificando instalação do Rust/rustup..."

    # Carrega env do cargo caso já exista mas não esteja no PATH atual
    local cargo_env="$HOME/.cargo/env"
    # shellcheck source=/dev/null
    [ -f "$cargo_env" ] && source "$cargo_env"

    if command -v rustup &>/dev/null; then
        success "rustup já instalado: $(rustup --version 2>&1)"
        log "Atualizando toolchain stable..."
        rustup update stable
        rustup component add rust-src rustfmt clippy
        success "Toolchain Rust atualizado."
        return 0
    fi

    log "rustup não encontrado. Instalando via script oficial..."

    if ! command -v curl &>/dev/null; then
        error "curl não encontrado — necessário para instalar rustup."
        error "Instale curl e execute novamente."
        exit 1
    fi

    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
        --default-toolchain stable \
        --component rust-src rustfmt clippy

    # Ativa o env na sessão atual
    # shellcheck source=/dev/null
    source "$HOME/.cargo/env"

    if command -v rustup &>/dev/null; then
        success "Rust instalado com sucesso: $(rustc --version)"
        success "Cargo: $(cargo --version)"
    else
        error "Instalação do rustup falhou — verifique a conexão e tente novamente."
        exit 1
    fi
}

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

    local pacotes=("${PACOTES_RPM_OSTREE[@]}")

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
        # rustup instala em $HOME/.cargo — não depende do reboot do rpm-ostree
        install_rustup
    else
        error "Falha ao aplicar pacotes via rpm-ostree."
        exit 1
    fi
}

# ── Instalação via DNF (Fallback para Container/Toolbox) ──────────────────────
setup_fedora_dnf() {
    log "═══ Configurando dependências via DNF ═══"

    step "Instalando pacotes de desenvolvimento no container..."
    # shellcheck disable=SC2068
    sudo dnf install -y ${PACOTES_DNF[@]}

    success "Dependências instaladas com sucesso no ambiente DNF."
    log "Rust e toolchain completo instalados via dnf no container"
    log "(dnf não tem o problema de glibc-devel do rpm-ostree)."

    install_rustup
}

# ── Remoção via rpm-ostree (Host Kinoite) ─────────────────────────────────────
teardown_fedora_rpm_ostree() {
    log "═══ Removendo Dependências via rpm-ostree ═══"

    step "Verificando transação rpm-ostree em andamento..."
    if rpm-ostree status 2>&1 | grep -q "Transaction in progress"; then
        warn "Transação em andamento. Cancelando antes de prosseguir..."
        rpm-ostree cancel || true
        sleep 2
    fi

    step "Verificando quais pacotes do layer estão instalados..."

    local instalados=()
    for pkg in "${PACOTES_RPM_OSTREE[@]}"; do
        if rpm -q "$pkg" &>/dev/null; then
            instalados+=("$pkg")
        else
            log "  ✗ não instalado (ignorando): $pkg"
        fi
    done

    if [ ${#instalados[@]} -eq 0 ]; then
        success "Nenhum pacote do layer está instalado. Nada a remover."
        return 0
    fi

    echo ""
    log "Pacotes a remover (${#instalados[@]}): ${instalados[*]}"
    echo ""

    step "Solicitando privilégios para o comando rpm-ostree..."
    if sudo rpm-ostree uninstall "${instalados[@]}"; then
        success "Remoção concluída com sucesso pelo rpm-ostree."
        echo ""
        warn "📢 ATENÇÃO: Reinicie a máquina para aplicar a remoção na árvore do sistema."
        warn "Execute: sudo systemctl reboot"
    else
        error "Falha ao remover pacotes via rpm-ostree."
        exit 1
    fi
}

# ── Remoção via DNF (Fallback para Container/Toolbox) ────────────────────────
teardown_fedora_dnf() {
    log "═══ Removendo dependências via DNF ═══"

    step "Removendo pacotes de desenvolvimento do container..."
    # shellcheck disable=SC2068
    sudo dnf remove -y ${PACOTES_DNF[@]} || true

    step "Removendo dependências órfãs..."
    sudo dnf autoremove -y

    success "Dependências removidas com sucesso no ambiente DNF."
}

# ── Fluxo Principal ───────────────────────────────────────────────────────────
main() {
    local action="${1:-install}"

    case "$action" in
        install|remove) ;;
        *)
            error "Ação inválida: '$action'"
            error "Uso: $0 [install|remove]  (padrão: install)"
            exit 1
            ;;
    esac

    log "═══ Automated Installer — Claw Launcher Dependencies ═══"
    log "Ação: $action"

    local pkg_manager
    pkg_manager=$(detect_package_manager)

    log "Ambiente ativo detectado: $pkg_manager"
    echo "────────────────────────────────────────────────"

    case "$pkg_manager" in
        rpm-ostree)
            if [ "$action" = "install" ]; then
                setup_fedora_rpm_ostree
            else
                teardown_fedora_rpm_ostree
            fi
            ;;
        dnf)
            if [ "$action" = "install" ]; then
                setup_fedora_dnf
            else
                teardown_fedora_dnf
            fi
            ;;
        *)
            error "Gerenciador de pacotes não suportado ou ambiente desconhecido."
            exit 1
            ;;
    esac
}

# ── Execução Direta Forçada ───────────────────────────────────────────────────
main "$@"
