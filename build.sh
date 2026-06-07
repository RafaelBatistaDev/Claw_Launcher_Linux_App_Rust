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

main() {
    log "═══ Build claw-launcher (Tauri + Rust) ═══"

    # Verifica Rust
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

    # Clean (opcional)
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

    success "═══ Build finalizado com sucesso! ═══"
}

main "$@"