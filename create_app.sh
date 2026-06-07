#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# Script       : create_app.sh
# Descrição    : Gerenciador Master — Claw Launcher (Tauri)
# Autor        : Rafael Batista
# Versão       : 2.1.0
# ──────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ── Cores ─────────────────────────────────────────────────────────────────────
G="\033[1;32m"; B="\033[1;34m"; Y="\033[1;33m"; R="\033[1;31m"; C="\033[1;36m"; N="\033[0m"

log()     { echo -e "${B}[INFO]${N}    $*"; }
success() { echo -e "${G}[OK]${N}      $*"; }
warn()    { echo -e "${Y}[AVISO]${N}   $*"; }
error()   { echo -e "${R}[ERRO]${N}    $*" >&2; }
step()    { echo -e "${C}[→]${N}       $*"; }
removed() { echo -e "${Y}[DEL]${N}     $*"; }

# ── Configurações ─────────────────────────────────────────────────────────────
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
REAL_HOME="${HOME}"
[[ -n "${SUDO_USER:-}" ]] && REAL_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)

ICON_SIZES=(16 32 48 64 128 256)
ICONS_BASE="${REAL_HOME}/.local/share/icons/hicolor"
APPS_DIR="${REAL_HOME}/.local/share/applications"
BIN_DIR="${REAL_HOME}/.local/bin"
LAST_CREATED_FOLDER=""

# ── Tauri Launcher ────────────────────────────────────────────────────────────
LAUNCHER_SRC="${SCRIPT_DIR}"
LAUNCHER_BIN="${BIN_DIR}/claw-launcher"

# ╔═══════════════════════════════════════════════════════════╗
# ║ Detecção de Sistema e Instalação de Dependências         ║
# ╚═══════════════════════════════════════════════════════════╝

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

setup_fedora_rpm_ostree() {
    log "═══ Configurando dependências para Fedora (rpm-ostree) ═══"
    
    step "Removendo webkit2gtk4.1-devel e libappindicator-gtk3-devel..."
    sudo rpm-ostree uninstall --idempotent \
        webkit2gtk4.1-devel \
        libappindicator-gtk3-devel || warn "Pacotes de remoção não encontrados (normal em primeira execução)"
    
    step "Instalando dependências de desenvolvimento (WebKit6, Adwaita, GTK3, GLib, Rust)..."
    sudo rpm-ostree install --idempotent --allow-inactive \
        webkitgtk6.0-devel \
        libadwaita-devel \
        gtk3-devel \
        glib2-devel \
        gobject-introspection-devel \
        libxcb-devel \
        openssl-devel \
        rust
    
    success "Dependências rpm-ostree configuradas."
    warn "⚠️  Será necessário reiniciar o sistema para aplicar as mudanças."
    warn "Execute: sudo systemctl reboot"
}

setup_fedora_dnf() {
    log "═══ Configurando dependências para Fedora (dnf) ═══"
    
    step "Removendo webkit2gtk4.1-devel e libappindicator-gtk3-devel..."
    sudo dnf remove -y \
        webkit2gtk4.1-devel \
        libappindicator-gtk3-devel || warn "Pacotes de remoção não encontrados"
    
    step "Instalando dependências de desenvolvimento (WebKit6, Adwaita, GTK3, GLib, Rust)..."
    sudo dnf install -y \
        webkitgtk6.0-devel \
        libadwaita-devel \
        gtk3-devel \
        glib2-devel \
        gobject-introspection-devel \
        libxcb-devel \
        openssl-devel \
        rust
    
    success "Dependências dnf configuradas."
}

setup_debian() {
    log "═══ Configurando dependências para Debian/Ubuntu ═══"
    
    step "Atualizando índice de pacotes..."
    sudo apt-get update
    
    step "Removendo webkit2gtk4.1-dev e libappindicator3-dev..."
    sudo apt-get remove -y \
        webkit2gtk-4.1 \
        webkit2gtk-4.1-dev \
        libappindicator3-dev || warn "Pacotes de remoção não encontrados"
    
    step "Instalando dependências de desenvolvimento (WebKit6, Adwaita, GTK3, GLib, Rust)..."
    sudo apt-get install -y \
        libwebkitgtk-6.0-dev \
        libadwaita-1-dev \
        libgtk-3-dev \
        libglib2.0-dev \
        gobject-introspection-dev \
        libxcb1-dev \
        libssl-dev \
        rust-all
    
    success "Dependências Debian/Ubuntu configuradas."
}

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
    
    # Verifica gobject-introspection
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

setup_system_dependencies() {
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
}

# ╔═══════════════════════════════════════════════════════════╗
# ║ Limpeza de Builds Anteriores                             ║
# ╚═══════════════════════════════════════════════════════════╝
clean_old_builds() {
    log "═══ Limpando builds antigos ═══"

    # Remove stale cargo lock files if they exist
    local target_dir="${LAUNCHER_SRC}/src-tauri/target"
    if [ -f "$target_dir/.package-cache" ]; then
        step "Removendo arquivos de lock pendentes..."
        rm -f "$target_dir/.package-cache" 2>/dev/null || true
        rm -f "$target_dir/.rustc_info.json" 2>/dev/null || true
    fi

    local build_dir="${LAUNCHER_SRC}/src-tauri/target/release/build"
    local incremental_dir="${LAUNCHER_SRC}/src-tauri/target/release/incremental"

    # Remove arquivos cache de compilação antigos (>30 dias)
    if [ -d "$build_dir" ]; then
        step "Removendo cache de builds antigos..."
        find "$build_dir" -type f -atime +30 -delete 2>/dev/null || true
        # Remove diretórios vazios
        find "$build_dir" -type d -empty -delete 2>/dev/null || true
    fi

    # Remove arquivos incrementais antigos
    if [ -d "$incremental_dir" ]; then
        step "Limpando cache incremental..."
        find "$incremental_dir" -type f -atime +30 -delete 2>/dev/null || true
        find "$incremental_dir" -type d -empty -delete 2>/dev/null || true
    fi

    # Remove binários antigos de .local/bin/ (backup)
    if [ -f "${LAUNCHER_BIN}.bak" ]; then
        step "Removendo backup antigo do binário..."
        rm -f "${LAUNCHER_BIN}.bak"
        removed "${LAUNCHER_BIN}.bak"
    fi

    success "═══ Limpeza concluída ═══"
}

build_launcher() {
    if [ ! -d "$LAUNCHER_SRC" ]; then
        error "Diretório não encontrado: ${LAUNCHER_SRC}"
        return 1
    fi

    # Verifica dependências antes de compilar
    log "Verificando dependências antes de compilar..."
    if ! pkg-config --exists webkitgtk-6.0 libadwaita-1 2>/dev/null; then
        warn "⚠️  Dependências do sistema incompletas!"
        read -r -p "Configurar agora? (s/N): " setup_choice
        if [[ "$setup_choice" =~ ^[Ss]$ ]]; then
            setup_system_dependencies || { error "Falha na configuração de deps"; return 1; }
        else
            warn "Continuando mesmo assim..."
        fi
    fi

    # ╔═══════════════════════════════════════════════════════════╗
    # ║ Opção de limpeza antes de compilar                       ║
    # ╚═══════════════════════════════════════════════════════════╝
    read -r -p "Limpar builds antigos antes de compilar? (s/N): " clean_choice
    if [[ "$clean_choice" =~ ^[Ss]$ ]]; then
        clean_old_builds
    fi

    step "Compilando claw-launcher (Rust)..."
    (cd "${LAUNCHER_SRC}/src-tauri" && cargo build --release)
    
    mkdir -p "$BIN_DIR"
    
    # Faz backup do binário anterior
    if [ -f "$LAUNCHER_BIN" ]; then
        cp "$LAUNCHER_BIN" "${LAUNCHER_BIN}.bak"
        step "Backup anterior salvo em ${LAUNCHER_BIN}.bak"
    fi
    
    # Copia novo binário
    cp "${LAUNCHER_SRC}/src-tauri/target/release/claw-launcher" "$LAUNCHER_BIN"
    chmod +x "$LAUNCHER_BIN"
    success "Instalado em ${LAUNCHER_BIN}"
    
    # Instala ícone do claw-launcher no sistema
    step "Instalando ícone do claw-launcher..."
    _install_claw_icon
}

check_launcher() {
    if [ ! -x "$LAUNCHER_BIN" ]; then
        warn "claw-launcher não encontrado. Compilando agora..."
        build_launcher
    fi
}

# ── Helpers ───────────────────────────────────────────────────────────────────

remove_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        rm -f "$file"
        removed "$file"
    else
        warn "Não encontrado (já removido?): $file"
    fi
}

update_caches() {
    step "Atualizando caches do sistema..."
    update-desktop-database "${APPS_DIR}"       2>/dev/null || true
    gtk-update-icon-cache -f -t "${ICONS_BASE}" 2>/dev/null || true
    if command -v kbuildsycoca6 &>/dev/null; then kbuildsycoca6 --noincremental 2>/dev/null; fi
    if command -v kbuildsycoca5 &>/dev/null; then kbuildsycoca5 --noincremental 2>/dev/null; fi
    success "Caches atualizados."
}

# ── Instâncias ────────────────────────────────────────────────────────────────

get_instances() {
    find "$SCRIPT_DIR" -maxdepth 1 -type d -name "instance_*" | while read -r dir; do
        echo "${dir##*/instance_}"
    done | sort | uniq
}

generate_unique_app_id() {
    local base_id="$1"
    local candidate="$base_id"
    local index=1
    while [ -d "${SCRIPT_DIR}/instance_${candidate}" ]; do
        candidate="${base_id}_${index}"
        index=$((index + 1))
    done
    echo "$candidate"
}

# ── Cache ─────────────────────────────────────────────────────────────────────

clear_app_cache() {
    local app_id="$1"
    log "═══ Limpando cache: ${app_id} ═══"

    step "Removendo dados de perfil..."
    local share_dir="${REAL_HOME}/.local/share/${app_id}"
    if [[ -d "$share_dir" ]]; then
        remove_file "${share_dir}/config.json"
        remove_file "${share_dir}/window.json"
        [[ -d "${share_dir}/storage" ]]           && { rm -rf "${share_dir}/storage"; removed "${share_dir}/storage/"; }
        [[ -d "${share_dir}/cache"   ]]           && { rm -rf "${share_dir}/cache";   removed "${share_dir}/cache/";   }
        [[ -d "${share_dir}/webkit" ]]            && { rm -rf "${share_dir}/webkit"; removed "${share_dir}/webkit/";  }
        [[ -d "${share_dir}/org.webkit"* ]]       && { rm -rf "${share_dir}/org.webkit"*; removed "${share_dir}/org.webkit*/"; }
        rmdir --ignore-fail-on-non-empty "${share_dir}" 2>/dev/null || true
    else
        warn "Sem dados de perfil: ${share_dir}"
    fi

    step "Removendo cache XDG..."
    local cache_dir="${REAL_HOME}/.cache/${app_id}"
    if [[ -d "$cache_dir" ]]; then
        rm -rf "$cache_dir"
        removed "${cache_dir}/"
    else
        warn "Sem cache XDG: ${cache_dir}"
    fi

    step "Removendo histórico de sessão..."
    local config_dir="${REAL_HOME}/.config/${app_id}"
    if [[ -d "$config_dir" ]]; then
        rm -rf "$config_dir"
        removed "${config_dir}/"
    fi

    success "═══ Cache limpo para ${app_id} ═══"
}

clear_cache_menu() {
    echo -e "\n${B}=== Limpar Cache / Dados de Navegação ===${N}"
    
    local profiles=()
    # Faz uma varredura real no sistema para encontrar onde existem dados do Claw
    while IFS= read -r dir; do
        [ -d "$dir" ] && profiles+=("${dir##*/}")
    done < <(find "${REAL_HOME}/.local/share" -maxdepth 1 -type d -name "Claw_*" 2>/dev/null | sort)

    if [ ${#profiles[@]} -eq 0 ]; then
        warn "Nenhum dado de aplicativo (Claw_*) encontrado em ~/.local/share/"
        return
    fi

    echo -e "Selecione o aplicativo para limpar cookies, sessões e cache:"
    for i in "${!profiles[@]}"; do
        printf "  %s) %s\n" "$((i+1))" "${profiles[i]}"
    done
    echo "  0) Cancelar"
    
    read -r -p "Escolha o número: " choice

    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#profiles[@]} ]; then
        local app_id="${profiles[$((choice-1))]}"
        read -r -p "Isso removerá logins e cookies de $app_id. Confirmar? (s/N): " confirm
        if [[ "$confirm" =~ ^[Ss]$ ]]; then
            clear_app_cache "$app_id"
        else
            warn "Operação cancelada."
        fi
    else
        warn "Operação cancelada."
    fi
}

# ── Ícones ────────────────────────────────────────────────────────────────────

list_icon_options() {
    if [ -d "${SCRIPT_DIR}/ICON" ]; then
        find "${SCRIPT_DIR}/ICON" -maxdepth 1 -type f -iname '*.png' | sort | sed 's|.*/||; s/\.png$//'
    fi
}

choose_icon() {
    local preferred_icon="$1"
    local icons=()
    if [ -d "${SCRIPT_DIR}/ICON" ]; then
        mapfile -t icons < <(find "${SCRIPT_DIR}/ICON" -maxdepth 1 -type f -iname '*.png' | sort | sed 's|.*/||; s/\.png$//')
    fi

    if [ -n "$preferred_icon" ] && [ -f "${SCRIPT_DIR}/ICON/${preferred_icon}.png" ]; then
        echo "$preferred_icon"; return 0
    fi

    [ ${#icons[@]} -eq 0 ] && return 1

    echo -e "${B}Ícones disponíveis em ICON/${N}"
    for i in "${!icons[@]}"; do
        printf "  %s) %s\n" "$((i+1))" "${icons[i]}"
    done
    echo "  0) Usar ícone padrão"

    while true; do
        read -r -p "Escolha um ícone por número ou nome (ENTER para padrão): " icon_choice
        [ -z "$icon_choice" ] && return 1
        if [[ "$icon_choice" =~ ^[0-9]+$ ]]; then
            [ "$icon_choice" -eq 0 ] && return 1
            if [ "$icon_choice" -ge 1 ] && [ "$icon_choice" -le ${#icons[@]} ]; then
                echo "${icons[$((icon_choice-1))]}"; return 0
            fi
        fi
        if [ -f "${SCRIPT_DIR}/ICON/${icon_choice}.png" ]; then
            echo "$icon_choice"; return 0
        fi
        warn "Ícone '${icon_choice}' não encontrado."
    done
}

install_icons() {
    local app_id="$1"
    local icon_src="$2"

    [ -z "$icon_src" ] || [ ! -f "$icon_src" ] && { warn "Ícone não encontrado: ${icon_src}"; return; }

    step "Instalando ícones..."
    for size in "${ICON_SIZES[@]}"; do
        local icon_dir="${ICONS_BASE}/${size}x${size}/apps"
        mkdir -p "$icon_dir"
        if command -v convert &>/dev/null; then
            convert "$icon_src" -resize "${size}x${size}" "${icon_dir}/${app_id}.png" 2>/dev/null \
                && success "Ícone ${size}x${size} instalado." \
                || cp "$icon_src" "${icon_dir}/${app_id}.png"
        else
            cp "$icon_src" "${icon_dir}/${app_id}.png"
        fi
    done
}

# ── Links ─────────────────────────────────────────────────────────────────────

# Mapeamento de links com ícones e nomes descritivos
declare -A LINK_MAP=(
    ["https://onenote.cloud.microsoft/pt-br/"]="OneNote:onenote"
    ["https://vscode.dev/?vscode-lang=pt-br"]="VSCode:vscode"
    ["https://gemini.google.com/app?hl=pt-BR"]="Gemini:Gemini"
    ["https://claude.ai/new"]="Claude:claudecode"
    ["https://chat.deepseek.com/"]="DeepSeek:deepseek"
    ["https://mail.google.com/mail/?authuser=0"]="Gmail:gmail"
    ["https://github.com/"]="GitHub:github"
    ["https://www.linkedin.com/"]="LinkedIn:linkedin"
    ["https://web.telegram.org/k/#/login"]="Telegram:Telegram"
    ["https://web.whatsapp.com/"]="WhatsApp:whatsapp"
    ["https://www.instagram.com/"]="Instagram:instagram"
    ["https://www.netflix.com/br/"]="Netflix:netflix"
    ["https://www.youtube.com/?app=desktop"]="YouTube:youtube"
    ["https://www.roblox.com/pt/login"]="Roblox:roblox"
    ["https://etherscan.io/"]="Etherscan:etherscan"
    ["https://app.myetherwallet.com/access?type=default"]="MyEtherWallet:myetherwallet"
    ["https://heliowallet.com/"]="HelioWallet:HelioWallet"
    ["https://onedrive.live.com/?view=0"]="OneDrive:onedrive"
)

list_link_options() {
    local list_file="${SCRIPT_DIR}/ICON/Links.txt"
    {
        # Links padrões sugeridos (aparecem mesmo se o arquivo não existir)
        echo "https://claude.ai/new"
        echo "https://www.roblox.com/pt/login"
        echo "https://www.instagram.com/"
        echo "https://chat.deepseek.com/"
        echo "https://www.linkedin.com/"
        echo "https://web.telegram.org/k/#/login"
        echo "https://etherscan.io/"
        echo "https://vscode.dev/?vscode-lang=pt-br"
        echo "https://gemini.google.com/app?hl=pt-BR"
        echo "https://app.myetherwallet.com/access?type=default"
        echo "https://web.whatsapp.com/"
        echo "https://github.com/"
        echo "https://www.netflix.com/br/"
        echo "https://www.youtube.com/?app=desktop"
        echo "https://mail.google.com/mail/?authuser=0"
        echo "https://onedrive.live.com/?view=0"
        echo "https://heliowallet.com/"
        echo "https://onenote.cloud.microsoft/pt-br/"

        if [ -f "$list_file" ]; then
            grep -Eo '^https?://[^[:space:]]+' "$list_file"
        fi
    } | sed 's/[[:space:]]*$//; /^[[:space:]]*$/d' | awk '!seen[$0]++'
}

# Obtém nome do app e ícone do mapeamento
get_app_info_from_url() {
    local url="$1"
    if [[ -v LINK_MAP["$url"] ]]; then
        echo "${LINK_MAP[$url]}"
    else
        local host
        host=$(echo "$url" | sed -E 's#^https?://##; s#/.*$##; s/^www\.//i')
        echo "$(guess_app_name_from_url "$url"):$(guess_icon_name_from_url "$url")"
    fi
}

choose_link() {
    local options
    mapfile -t options < <(list_link_options)

    if [ ${#options[@]} -gt 0 ]; then
        echo
        echo -e "${B}Links disponíveis em ICON/Links.txt:${N}"
        for i in "${!options[@]}"; do
            printf "  %s) %s\n" "$((i+1))" "${options[i]}"
        done
        echo

        while true; do
            read -r -p "Número, URL ou ENTER para digitar manualmente: " link_choice
            [ -z "$link_choice" ] && { read -r -p "URL do Site: " link_choice; }

            if [[ "$link_choice" =~ ^[0-9]+$ ]] && \
               [ "$link_choice" -ge 1 ] && \
               [ "$link_choice" -le ${#options[@]} ]; then
                echo "${options[$((link_choice-1))]}"; return
            fi

            [[ "$link_choice" =~ ^https?:// ]] && { echo "$link_choice"; return; }
            warn "URL inválida. Use número da lista ou link com http(s)://"
        done
    fi

    read -r -p "URL do Site (ex: https://chat.openai.com): " link_choice
    echo "$link_choice"
}

save_link_option() {
    local url="$1"
    local list_file="${SCRIPT_DIR}/ICON/Links.txt"
    [[ -z "$url" || ! "$url" =~ ^https?:// ]] && return
    mkdir -p "${SCRIPT_DIR}/ICON"
    if [ ! -f "$list_file" ] || ! grep -Fxq "$url" "$list_file"; then
        printf '%s\n' "$url" >> "$list_file"
        success "Link salvo em ICON/Links.txt."
    fi
}

guess_app_name_from_url() {
    local url="$1"
    local host
    host=$(echo "$url" | sed -E 's#^https?://##; s#/.*$##; s/^www\.//i')
    case "$host" in
        *deepseek*)                echo "DeepSeek" ;;
        *github.dev*|*vscode.dev*) echo "VSCode" ;;
        *github.com*)              echo "GitHub" ;;
        *mail.google.com*)         echo "Gmail" ;;
        *gemini.google.com*)       echo "Gemini" ;;
        *chat.openai.com*)         echo "ChatGPT" ;;
        *claude.ai*)               echo "Claude" ;;
        *linkedin.com*)            echo "LinkedIn" ;;
        *instagram.com*)           echo "Instagram" ;;
        *telegram.org*)            echo "Telegram" ;;
        *whatsapp.com*)            echo "WhatsApp" ;;
        *onedrive.live.com*)       echo "OneDrive" ;;
        *netflix.com*)             echo "Netflix" ;;
        *youtube.com*)             echo "YouTube" ;;
        *roblox.com*)              echo "Roblox" ;;
        *myetherwallet.com*)       echo "MyEtherWallet" ;;
        *heliowallet.com*)         echo "HelioWallet" ;;
        *etherscan.io*)            echo "Etherscan" ;;
        *onenote.cloud.microsoft*) echo "OneNote" ;;
        *) echo "$host" | sed -E 's/[^a-zA-Z0-9]+/ /g; s/^ //; s/ $//' ;;
    esac
}

guess_icon_name_from_url() {
    local url="$1"
    local host
    host=$(echo "$url" | sed -E 's#^https?://##; s#/.*$##; s/^www\.//i')
    case "$host" in
        *deepseek*)                echo "deepseek" ;;
        *github.dev*|*vscode.dev*) echo "vscode" ;;
        *github.com*)              echo "github" ;;
        *mail.google.com*)         echo "gmail" ;;
        *gemini.google.com*)       echo "Gemini" ;;
        *claude.ai*)               echo "claudecode" ;;
        *linkedin.com*)            echo "linkedin" ;;
        *instagram.com*)           echo "instagram" ;;
        *telegram.org*)            echo "Telegram" ;;
        *whatsapp.com*)            echo "whatsapp" ;;
        *onedrive.live.com*)       echo "onedrive" ;;
        *netflix.com*)             echo "netflix" ;;
        *youtube.com*)             echo "youtube" ;;
        *roblox.com*)              echo "roblox" ;;
        *myetherwallet.com*)       echo "myetherwallet" ;;
        *heliowallet.com*)         echo "HelioWallet" ;;
        *etherscan.io*)            echo "etherscan" ;;
        *onenote.cloud.microsoft*) echo "onenote" ;;
        *) echo "$host" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/_/g' ;;
    esac
}

# ── Criação de Instância ──────────────────────────────────────────────────────

install_new_instance() {
    check_launcher

    local raw_name="${1:-}"
    local url="${2:-}"
    local preferred_icon="${3:-}"

    if [ -z "$raw_name" ]; then
        echo -e "${B}Instalando nova instância...${N}"
        read -r -p "Nome do Aplicativo (ex: ChatGPT): " raw_name
    fi

    [ -z "$url" ] && url=$(choose_link)
    if [ -z "$url" ]; then
        error "URL inválida."
        return 1
    fi

    save_link_option "$url"

    local clean_id
    clean_id=$(echo "$raw_name" | sed 's/[^a-zA-Z0-9]/_/g')
    [ -z "$clean_id" ] && { error "Nome inválido."; return 1; }

    local app_id="Claw_${clean_id}"
    app_id=$(generate_unique_app_id "$app_id")
    local folder="instance_${app_id}"
    LAST_CREATED_FOLDER=""

    # Resolve ícone
    local icon_src="${SCRIPT_DIR}/ICON/${clean_id}.png"
    if [ ! -f "$icon_src" ] && [ -n "$preferred_icon" ] && [ -f "${SCRIPT_DIR}/ICON/${preferred_icon}.png" ]; then
        icon_src="${SCRIPT_DIR}/ICON/${preferred_icon}.png"
    fi
    if [ ! -f "$icon_src" ]; then
        local icon_choice
        icon_choice=$(choose_icon "$preferred_icon") || true
        if [ -n "${icon_choice:-}" ] && [ -f "${SCRIPT_DIR}/ICON/${icon_choice}.png" ]; then
            icon_src="${SCRIPT_DIR}/ICON/${icon_choice}.png"
        else
            icon_src=""
        fi
    fi

    # Ícone padrão se nenhum encontrado
    [ -z "$icon_src" ] && [ -f "${SCRIPT_DIR}/Claw_Launcher_Linux-256.png" ] && \
        icon_src="${SCRIPT_DIR}/Claw_Launcher_Linux-256.png"

    log "═══ Criando instância: ${raw_name} ═══"
    log "  APP_ID : ${app_id}"
    log "  URL    : ${url}"
    log "  Ícone  : ${icon_src:-nenhum}"

    # 1. Pasta da instância
    step "Criando pasta da instância..."
    mkdir -p "${SCRIPT_DIR}/${folder}"
    success "Pasta: ${SCRIPT_DIR}/${folder}"

    # 2. Salvar metadados da instância
    step "Salvando metadados..."
    cat > "${SCRIPT_DIR}/${folder}/instance.conf" << CONF
APP_ID="${app_id}"
APP_NAME="${raw_name}"
URL="${url}"
ICON_SRC="${icon_src}"
CONF
    success "Metadados salvos em instance.conf"

    # 3. Copiar ícone para a pasta da instância
    if [ -n "$icon_src" ] && [ -f "$icon_src" ]; then
        cp "$icon_src" "${SCRIPT_DIR}/${folder}/${app_id}.png"
        success "Ícone copiado: ${app_id}.png"
    fi

    # 4. Arquivo .desktop com Exec= usando claw-launcher
    step "Gerando arquivo .desktop..."
    mkdir -p "$APPS_DIR"
    cat > "${SCRIPT_DIR}/${folder}/${app_id}.desktop" << DESKTOP
[Desktop Entry]
Name=${raw_name}
Comment=${raw_name} - Dashboard IA
Exec=${LAUNCHER_BIN} --app-id ${app_id} --url ${url} --name ${raw_name} %U
Icon=${app_id}
Terminal=false
Type=Application
StartupNotify=true
StartupWMClass=${app_id}
Categories=Network;WebBrowser;
DESKTOP
    success "Arquivo .desktop gerado."

    LAST_CREATED_FOLDER="$folder"
    success "═══ Instância '${raw_name}' pronta! ═══"
    echo -e "Para instalar no sistema: ${C}cd ${folder} && bash ../create_app.sh install${N}"
}

# ── Instalar Instância no Sistema ─────────────────────────────────────────────

install_instance_to_system() {
    local folder="$1"
    local app_id url raw_name icon_src

    # Carrega metadados
    if [ -f "${folder}/instance.conf" ]; then
        # shellcheck disable=SC1090
        source "${folder}/instance.conf"
    else
        error "instance.conf não encontrado em: ${folder}"
        return 1
    fi

    log "Instalando ${APP_NAME} no sistema..."

    # ╔═══════════════════════════════════════════════════════════╗
    # ║ VERIFICAÇÃO: Evita duplicação de apps                   ║
    # ╚═══════════════════════════════════════════════════════════╝
    if [ -f "${APPS_DIR}/${APP_ID}.desktop" ]; then
        warn "App '${APP_ID}' já está instalado no sistema."
        read -r -p "Deseja substituir? (s/N): " replace_choice
        if [[ ! "$replace_choice" =~ ^[Ss]$ ]]; then
            warn "Instalação cancelada."
            return 0
        fi
        step "Removendo instalação anterior..."
        remove_file "${APPS_DIR}/${APP_ID}.desktop"
        for size in "${ICON_SIZES[@]}"; do
            remove_file "${ICONS_BASE}/${size}x${size}/apps/${APP_ID}.png"
        done
    fi

    # Instalar ícones
    local icon_file="${folder}/${APP_ID}.png"
    if [ -f "$icon_file" ]; then
        install_icons "$APP_ID" "$icon_file"
    else
        warn "Ícone não encontrado: ${icon_file}"
    fi

    # Instalar .desktop (apenas uma vez)
    local desktop_src="${folder}/${APP_ID}.desktop"
    if [ -f "$desktop_src" ]; then
        mkdir -p "$APPS_DIR"
        cp "$desktop_src" "${APPS_DIR}/${APP_ID}.desktop"
        chmod 644 "${APPS_DIR}/${APP_ID}.desktop"
        success ".desktop instalado em ${APPS_DIR}/"
    else
        error ".desktop não encontrado: ${desktop_src}"
        return 1
    fi

    # Cria dados/cache estruturado para WebKit
    local data_dir="${REAL_HOME}/.local/share/${APP_ID}"
    local cache_dir="${REAL_HOME}/.cache/${APP_ID}"
    
    step "Inicializando estrutura de persistência..."
    mkdir -p "${data_dir}/webkit"
    mkdir -p "${data_dir}/storage"
    mkdir -p "${cache_dir}/webkit"
    mkdir -p "${cache_dir}/http"
    success "Diretórios de armazenamento criados."

    update_caches
    success "═══ ${APP_NAME} instalado com sucesso ═══"
}

# ── App Pré-configurado (Opção 1) ────────────────────────────────────────────

create_preconfigured_app() {
    check_launcher

    local options
    mapfile -t options < <(list_link_options)

    if [ ${#options[@]} -eq 0 ]; then
        warn "Nenhum link pré-configurado em ICON/Links.txt."
        return
    fi

    echo
    echo -e "${B}=== OPÇÃO 1: Instalação de Links Pré-configurados ===${N}"
    echo -e "${B}Apps disponíveis com ícones:${N}"
    for i in "${!options[@]}"; do
        local url="${options[i]}"
        local app_info
        app_info=$(get_app_info_from_url "$url")
        local app_name="${app_info%:*}"
        local icon_name="${app_info#*:}"
        local icon_file="${SCRIPT_DIR}/ICON/${icon_name}.png"
        
        if [ -f "$icon_file" ]; then
            printf "  %s) %-20s 🎨 %-15s %s\n" "$((i+1))" "$app_name" "[${icon_name}]" "$url"
        else
            printf "  %s) %-20s %-15s %s\n" "$((i+1))" "$app_name" "[sem ícone]" "$url"
        fi
    done
    echo "  0) Cancelar"
    echo

    read -r -p "Escolha o app para instalar [Padrão: 1]: " choice
    choice="${choice:-1}"
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#options[@]} ]; then
        local url="${options[$((choice-1))]}"
        local app_info
        app_info=$(get_app_info_from_url "$url")
        local raw_name="${app_info%:*}"
        local icon_name="${app_info#*:}"

        if install_new_instance "$raw_name" "$url" "$icon_name"; then
            if [ -n "$LAST_CREATED_FOLDER" ]; then
                step "Instalando no sistema..."
                install_instance_to_system "${SCRIPT_DIR}/${LAST_CREATED_FOLDER}"
                success "App '${raw_name}' criado e instalado."
            fi
        fi
    else
        warn "Operação cancelada."
    fi
}

# ── Instalação Livre (Opção 2) ────────────────────────────────────────────────

create_custom_app() {
    check_launcher
    
    echo
    echo -e "${B}=== OPÇÃO 2: Instalação Personalizada (Livre) ===${N}"
    echo -e "${B}Crie um novo app com URL e nome personalizados${N}"
    echo

    read -r -p "Nome do Aplicativo (ex: ChatGPT, Gemini, etc.): " raw_name
    if [ -z "$raw_name" ]; then
        error "Nome não pode estar vazio."
        return 1
    fi

    read -r -p "URL do site (ex: https://chat.openai.com): " url
    if [ -z "$url" ] || ! [[ "$url" =~ ^https?:// ]]; then
        error "URL inválida. Deve começar com http:// ou https://"
        return 1
    fi

    save_link_option "$url"
    
    echo -e "\n${B}Escolha um ícone para: ${C}${raw_name}${N}"
    local icon_choice
    icon_choice=$(choose_icon) || true
    local icon_name="${icon_choice:-${raw_name}}"

    if install_new_instance "$raw_name" "$url" "$icon_name"; then
        if [ -n "$LAST_CREATED_FOLDER" ]; then
            step "Instalando no sistema..."
            install_instance_to_system "${SCRIPT_DIR}/${LAST_CREATED_FOLDER}"
            success "App '${raw_name}' criado e instalado com sucesso!"
        fi
    fi
}

# ── Instalar / Desinstalar ────────────────────────────────────────────────────

install_instance() {
    local options=()
    while IFS= read -r line; do [ -n "$line" ] && options+=("$line"); done < <(get_instances)
    [ ${#options[@]} -eq 0 ] && { warn "Nenhuma instância criada."; return; }

    echo -e "${B}Selecione a instância para instalar:${N}"
    select opt in "${options[@]}" "Cancelar"; do
        [[ "$opt" == "Cancelar" || -z "$opt" ]] && return
        
        # ╔═══════════════════════════════════════════════════════════╗
        # ║ VERIFICAÇÃO: Evita duplicação ao instalar                ║
        # ╚═══════════════════════════════════════════════════════════╝
        local app_id="$opt"
        if [ -f "${APPS_DIR}/${app_id}.desktop" ]; then
            warn "App '${app_id}' já está instalado no sistema!"
            read -r -p "Deseja reinstalar? (s/N): " reinstall_choice
            if [[ ! "$reinstall_choice" =~ ^[Ss]$ ]]; then
                warn "Operação cancelada."
                break
            fi
        fi
        
        install_instance_to_system "${SCRIPT_DIR}/instance_${opt}"
        break
    done
}

uninstall_instance() {
    local options=()
    while IFS= read -r line; do [ -n "$line" ] && options+=("$line"); done < <(get_instances)
    [ ${#options[@]} -eq 0 ] && { warn "Nenhuma instância encontrada."; return; }

    echo -e "${B}Selecione a instância para desinstalar:${N}"
    select opt in "${options[@]}" "Cancelar"; do
        [[ "$opt" == "Cancelar" || -z "$opt" ]] && return

        local folder="${SCRIPT_DIR}/instance_${opt}"
        local app_id="$opt"

        log "═══ Desinstalando ${app_id} ═══"

        step "Removendo .desktop..."
        remove_file "${APPS_DIR}/${app_id}.desktop"

        step "Removendo ícones..."
        for size in "${ICON_SIZES[@]}"; do
            remove_file "${ICONS_BASE}/${size}x${size}/apps/${app_id}.png"
        done

        step "Limpando dados de usuário..."
        # Opção para limpar dados ao desinstalar
        read -r -p "Limpar dados/cookies/sessão do app? (s/N): " clean_data
        if [[ "$clean_data" =~ ^[Ss]$ ]]; then
            clear_app_cache "$app_id"
        else
            warn "Dados de usuário preservados em ~/.local/share/${app_id}/ e ~/.cache/${app_id}/"
        fi

        update_caches
        success "App desinstalado do sistema."

        read -r -p "Deletar também a pasta de origem? (s/N): " del_folder
        if [[ "$del_folder" =~ ^[Ss]$ ]]; then
            rm -rf "$folder"
            removed "${folder}/"
        fi
        break
    done
}

list_all() {
    echo -e "${B}Instâncias disponíveis:${N}"
    local found=0
    while IFS= read -r name; do
        if [ -n "$name" ]; then
            local conf="${SCRIPT_DIR}/instance_${name}/instance.conf"
            if [ -f "$conf" ]; then
                local app_url=""
                app_url=$(grep '^URL=' "$conf" | cut -d'"' -f2)
                printf "  ${C}•${N} %-25s %s\n" "$name" "$app_url"
            else
                echo "  • instance_${name}"
            fi
            found=1
        fi
    done < <(get_instances)
    [ $found -eq 0 ] && warn "Nenhuma instância criada."
}

purge_all() {
    echo -e "${R}⚠️  PERIGO: Isso removerá o binário, todas as instâncias instaladas e TODOS os dados (cookies/sessões)!${N}"
    read -r -p "Deseja continuar e apagar TUDO para começar do zero? (s/N): " confirm
    if [[ ! "$confirm" =~ ^[Ss]$ ]]; then
        warn "Operação cancelada."
        return
    fi

    log "═══ Iniciando limpeza total (Reset de Fábrica) ═══"

    step "Removendo arquivos .desktop e ícones do sistema..."
    find "$APPS_DIR" -name "Claw_*.desktop" -type f -delete 2>/dev/null || true
    for size in "${ICON_SIZES[@]}"; do
        find "${ICONS_BASE}/${size}x${size}/apps" -name "Claw_*.png" -type f -delete 2>/dev/null || true
    done

    step "Removendo pastas instance_*..."
    find "$SCRIPT_DIR" -maxdepth 1 -type d -name "instance_*" -exec rm -rf {} + 2>/dev/null || true

    step "Removendo binário do launcher e backups..."
    remove_file "$LAUNCHER_BIN"
    remove_file "${LAUNCHER_BIN}.bak"

    step "Limpando cookies, sessões e caches (~/.local/share/Claw_* e ~/.cache/Claw_*)..."
    rm -rf "${REAL_HOME}/.local/share"/Claw_* 2>/dev/null || true
    rm -rf "${REAL_HOME}/.cache"/Claw_* 2>/dev/null || true

    step "Limpando diretório target (artefatos de compilação)..."
    rm -rf "${LAUNCHER_SRC}/src-tauri/target" 2>/dev/null || true

    update_caches
    success "═══ Sistema resetado! Tudo pronto para começar do zero. ═══"
}

# ── Menu ──────────────────────────────────────────────────────────────────────

manage_onenote() {
    local app_id="Claw_OneNote"
    local desktop_file="${APPS_DIR}/${app_id}.desktop"

    if [ -f "$desktop_file" ]; then
        log "═══ Gerenciar OneNote ═══"
        warn "O OneNote já está instalado no sistema."
        read -r -p "Deseja desinstalá-lo agora? (s/N): " choice
        if [[ "$choice" =~ ^[Ss]$ ]]; then
            step "Removendo .desktop e ícones..."
            remove_file "$desktop_file"
            for size in "${ICON_SIZES[@]}"; do
                remove_file "${ICONS_BASE}/${size}x${size}/apps/${app_id}.png"
            done
            update_caches
            success "OneNote desinstalado com sucesso."
        fi
    else
        log "═══ Instalação Expressa: OneNote ═══"
        install_new_instance "OneNote" "https://onenote.cloud.microsoft/pt-br/" "onenote"
        [ -n "$LAST_CREATED_FOLDER" ] && install_instance_to_system "${SCRIPT_DIR}/${LAST_CREATED_FOLDER}"
    fi
}

# ── Variantes não-interativas (chamadas pela GUI) ─────────────────────────────

_create_install_gui() {
    install_new_instance "$1" "$2" "$3"
    [ -n "$LAST_CREATED_FOLDER" ] && \
        install_instance_to_system "${SCRIPT_DIR}/${LAST_CREATED_FOLDER}"
}

_uninstall_gui() {
    local app_id="$1" clean_data="${2:-n}" del_folder="${3:-n}"
    log "Desinstalando ${app_id}..."
    remove_file "${APPS_DIR}/${app_id}.desktop"
    for size in "${ICON_SIZES[@]}"; do
        remove_file "${ICONS_BASE}/${size}x${size}/apps/${app_id}.png"
    done
    [[ "$clean_data" == "s" ]] && clear_app_cache "$app_id"
    update_caches
    if [[ "$del_folder" == "s" ]]; then
        local folder="${SCRIPT_DIR}/instance_${app_id}"
        [ -d "$folder" ] && rm -rf "$folder" && removed "$folder"
    fi
    success "Desinstalado: ${app_id}"
}

_purge_force() {
    log "═══ Reset de Fábrica ═══"
    find "$APPS_DIR" -name "Claw_*.desktop" -type f -delete 2>/dev/null || true
    for size in "${ICON_SIZES[@]}"; do
        find "${ICONS_BASE}/${size}x${size}/apps" -name "Claw_*.png" -delete 2>/dev/null || true
    done
    find "$SCRIPT_DIR" -maxdepth 1 -type d -name "instance_*" -exec rm -rf {} + 2>/dev/null || true
    remove_file "$LAUNCHER_BIN"; remove_file "${LAUNCHER_BIN}.bak"
    rm -rf "${REAL_HOME}/.local/share"/Claw_* 2>/dev/null || true
    rm -rf "${REAL_HOME}/.cache"/Claw_* 2>/dev/null || true
    rm -rf "${LAUNCHER_SRC}/src-tauri/target" 2>/dev/null || true
    update_caches
    success "═══ Sistema resetado! ═══"
}

# ── Verificação de Dependências do Sistema ────────────────────────────────────

check_system_deps() {
    log "═══ Verificando dependências do sistema ═══"
    
    local missing=0
    
    # Verifica WebKit6
    if ! pkg-config --exists webkitgtk-6.0 2>/dev/null; then
        warn "✗ webkitgtk6.0-devel NOT FOUND"
        ((missing++))
    else
        success "✓ webkitgtk6.0-devel instalado"
    fi
    
    # Verifica libadwaita
    if ! pkg-config --exists libadwaita-1 2>/dev/null; then
        warn "✗ libadwaita-devel NOT FOUND"
        ((missing++))
    else
        success "✓ libadwaita-devel instalado"
    fi
    
    if [ $missing -gt 0 ]; then
        echo ""
        warn "⚠️  Faltam $missing dependência(s) do sistema!"
        read -r -p "Configurar dependências agora? (s/N): " setup_deps
        if [[ "$setup_deps" =~ ^[Ss]$ ]]; then
            setup_system_dependencies
        else
            warn "Continuando sem configurar dependências (build pode falhar)..."
        fi
    else
        success "Todas as dependências do sistema estão OK."
    fi
}

_list_json() {
    local first=1
    echo "["
    while IFS= read -r name; do
        [ -z "$name" ] && continue
        local conf="${SCRIPT_DIR}/instance_${name}/instance.conf"
        local app_name="$name" url="" installed="false"
        [ -f "$conf" ] && {
            app_name=$(grep '^APP_NAME=' "$conf" | cut -d'"' -f2)
            url=$(grep '^URL=' "$conf" | cut -d'"' -f2)
        }
        [ -f "${APPS_DIR}/${name}.desktop" ] && installed="true"
        [ $first -eq 0 ] && printf ","
        printf '{"app_id":"%s","name":"%s","url":"%s","installed":%s}\n' \
            "$name" "$app_name" "$url" "$installed"
        first=0
    done < <(get_instances)
    echo "]"
}

_build_silent() {
    step "Compilando claw-launcher..."
    (cd "${LAUNCHER_SRC}/src-tauri" && cargo build --release) || { error "Falha na compilação."; return 1; }
    rm -f "$LAUNCHER_BIN"
    cp "${LAUNCHER_SRC}/src-tauri/target/release/claw-launcher" "$LAUNCHER_BIN"
    chmod +x "$LAUNCHER_BIN"
    success "Instalado em ${LAUNCHER_BIN}"
    _install_claw_icon
}

_install_claw_icon() {
    local icon_src="${SCRIPT_DIR}/ICON/claw-launcher.png"
    local app_id="claw-launcher"
    
    if [ ! -f "$icon_src" ]; then
        icon_src="${SCRIPT_DIR}/src-tauri/icons/icon.png"
    fi
    
    [ -z "$icon_src" ] || [ ! -f "$icon_src" ] && { warn "Ícone do claw-launcher não encontrado"; return; }
    
    for size in "${ICON_SIZES[@]}"; do
        local icon_dir="${ICONS_BASE}/${size}x${size}/apps"
        mkdir -p "$icon_dir"
        if command -v convert &>/dev/null; then
            convert "$icon_src" -resize "${size}x${size}" "${icon_dir}/${app_id}.png" 2>/dev/null \
                && success "Ícone ${size}x${size} instalado." \
                || cp "$icon_src" "${icon_dir}/${app_id}.png"
        else
            cp "$icon_src" "${icon_dir}/${app_id}.png"
        fi
    done
    
    # Instala .desktop file para o próprio claw-launcher
    mkdir -p "$APPS_DIR"
    cat > "${APPS_DIR}/${app_id}.desktop" << DESKTOP
[Desktop Entry]
Name=Claw Launcher
Comment=Gerenciador de WebApps isolados
Exec=${LAUNCHER_BIN}
Icon=${app_id}
Terminal=false
Type=Application
Categories=Utility;System;
DESKTOP
    chmod 644 "${APPS_DIR}/${app_id}.desktop"
    success ".desktop do claw-launcher instalado"
    
    update_caches
}

show_menu() {
    echo -e "\n${B}╔════════════════════════════════════════════════════════╗${N}"
    echo -e "${B}║${N}            ${C}GERENCIADOR CLAW LAUNCHER${N}              ${B}║${N}"
    echo -e "${B}╚════════════════════════════════════════════════════════╝${N}"
    echo "  1. Instalar app pré-configurado / Install pre-configured app"
    echo "  2. Criar nova instância personalizada / Create custom instance"
    echo "  3. Instalar no sistema / Install to system"
    echo "  4. Desinstalar instância / Uninstall instance"
    echo "  5. Listar instâncias / List instances"
    echo "  6. Limpar cache / Clear cache"
    echo "  7. Instalar/Remover OneNote / Install/Remove OneNote (Default)"
    echo "  ──────────────────────────────────────────────────────"
    echo "  8. Compilar e instalar / Build and install (Rust)"
    echo "  9. Limpar builds antigos / Clean old builds"
    echo "  10. Setup de Dependências / Setup system dependencies"
    echo "  11. PURGAR TUDO / PURGE ALL (Reset Factory)"
    echo "  0. Sair / Exit"
    echo ""
    # Mostra status do binário
    if [ -x "$LAUNCHER_BIN" ]; then
        local ver
        ver=$("$LAUNCHER_BIN" --version 2>/dev/null || echo "instalado")
        echo -e "  ${G}●${N} claw-launcher: ${ver} (OK)"
    else
        echo -e "  ${R}●${N} claw-launcher: não instalado / not installed"
    fi
    echo -e "  Language: $(echo $LANG | cut -d. -f1)"
    echo ""
}

# ── Entry Point ───────────────────────────────────────────────────────────────

if [ $# -gt 0 ]; then
    case "$1" in
        create|install-new)                 install_new_instance "${2:-}" "${3:-}" "${4:-}" ;;
        create-install)                     _create_install_gui "${2:-}" "${3:-}" "${4:-}" ;;
        custom)                             create_custom_app ;;
        preconfigured|create-preconfigured) create_preconfigured_app ;;
        install)                            install_instance ;;
        uninstall)                          uninstall_instance ;;
        uninstall-id)                       _uninstall_gui "${2:-}" "${3:-n}" "${4:-n}" ;;
        list)                               list_all ;;
        list-json)                          _list_json ;;
        clear-cache-id)                     clear_app_cache "${2:-}" ;;
        build)                              build_launcher ;;
        build-silent)                       _build_silent ;;
        clean|clean-builds)                 clean_old_builds ;;
        setup-deps)                         setup_system_dependencies ;;
        purge-force)                        _purge_force ;;
        *) error "Uso: $0 {create|install-new|custom|preconfigured|install|uninstall|list|build|clean|setup-deps}"; exit 1 ;;
    esac
else
    # Verifica dependências do sistema na primeira execução
    check_system_deps
    
    # Sessão gráfica disponível → abre GUI
    if [ -x "$LAUNCHER_BIN" ] && [ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]; then
        CLAW_SCRIPT_DIR="$SCRIPT_DIR" exec "$LAUNCHER_BIN"
    fi
    while true; do
        show_menu
        read -r -p "Opção: " opt
        case "$opt" in
            1) create_preconfigured_app ;;
            2) create_custom_app ;;
            3) install_instance ;;
            4) uninstall_instance ;;
            5) list_all ;;
            6) clear_cache_menu ;;
            7) manage_onenote ;;
            8) build_launcher ;;
            9) clean_old_builds ;;
            10) setup_system_dependencies ;;
            11) purge_all ;;
            0) exit 0 ;;
            *) warn "Opção inválida" ;;
        esac
    done
fi
