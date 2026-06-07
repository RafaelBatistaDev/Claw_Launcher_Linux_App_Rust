#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Limpeza Profunda e Purga — CLAW Launcher
Desinstala o app principal, instâncias, atalhos, caches, remove a pasta de build
e limpa arquivos temporários do repositório, mantendo apenas o essencial.
"""

import sys
import subprocess
import logging
import shutil
from pathlib import Path
from datetime import datetime

# ── 1. Constantes e Diretórios ────────────────────────────────
USER_HOME = Path.home()
BIN_DIR = USER_HOME / ".local" / "bin"
LOG_DIR = USER_HOME / ".local" / "log"
SHARE_DIR = USER_HOME / ".local" / "share"
LOG_FILE = LOG_DIR / f"purga_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
LAUNCHER_BIN = BIN_DIR / "claw-launcher"
LAUNCHER_BAK = BIN_DIR / "claw-launcher.bak"
APPS_DIR = SHARE_DIR / "applications"
ICONS_BASE = SHARE_DIR / "icons" / "hicolor"

# ── 2. Cores ANSI ─────────────────────────────────────────────
class Color:
    G = "\033[1;32m"   # Verde   — sucesso
    B = "\033[1;34m"   # Azul    — info
    Y = "\033[1;33m"   # Amarelo — aviso
    R = "\033[1;31m"   # Vermelho — erro
    C = "\033[1;36m"   # Ciano   — destaque
    N = "\033[0m"      # Reset

# ── 3. Funções de Log ─────────────────────────────────────────
def _setup_logging() -> logging.Logger:
    """Configura logger com handlers para console e arquivo."""
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    logger = logging.getLogger("purga")
    logger.setLevel(logging.DEBUG)

    fh = logging.FileHandler(LOG_FILE, encoding="utf-8")
    fh.setFormatter(logging.Formatter("[%(levelname)s] %(asctime)s — %(message)s"))

    ch = logging.StreamHandler(sys.stdout)
    ch.setFormatter(logging.Formatter("%(message)s"))

    logger.addHandler(fh)
    logger.addHandler(ch)
    return logger

logger = _setup_logging()

def log(msg: str) -> None:     logger.info(f"{Color.B}[INFO]{Color.N}   {msg}")
def success(msg: str) -> None: logger.info(f"{Color.G}[OK]{Color.N}     {msg}")
def warn(msg: str) -> None:    logger.warning(f"{Color.Y}[AVISO]{Color.N} {msg}")
def error(msg: str) -> None:   logger.error(f"{Color.R}[ERRO]{Color.N}  {msg}")
def debug(msg: str) -> None:   logger.debug(f"{Color.C}[DEBUG]{Color.N} {msg}")

# ── 4. Validação Inicial ──────────────────────────────────────
def bootstrap_dirs() -> None:
    """Cria estrutura de diretórios necessária de forma idempotente."""
    for d in (BIN_DIR, LOG_DIR, SHARE_DIR):
        d.mkdir(parents=True, exist_ok=True)
    LOG_FILE.touch(exist_ok=True)
    log(f"Diretórios verificados em: {USER_HOME}")

# ── 5. Execução de Comandos ───────────────────────────────────
def run_cmd(
    cmd: list[str],
    check: bool = True
) -> subprocess.CompletedProcess:
    """Executa comando externo com tratamento de erro padronizado.

    Args:
        cmd: Lista de argumentos do comando.
        check: Se True, lança exceção em caso de falha.

    Returns:
        CompletedProcess contendo código de saída, stdout e stderr.
    """
    log(f"→ {' '.join(cmd)}")
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=check,
        )
        return result
    except subprocess.CalledProcessError as e:
        error(f"Falha [{e.returncode}]: {' '.join(cmd)}")
        if e.stderr:
            error(e.stderr.strip())
        raise
    except FileNotFoundError:
        warn(f"Comando não encontrado: {cmd[0]} — pulando.")
        return subprocess.CompletedProcess(cmd, 127, stdout="", stderr="")

# ── 6. Limpeza e Purga ────────────────────────────────────────
def remove_path(path: Path) -> None:
    """Remove um arquivo ou diretório do sistema de forma segura e idempotente.

    Args:
        path: O objeto Path correspondente ao arquivo ou diretório a remover.
    """
    if path.exists():
        try:
            if path.is_file() or path.is_symlink():
                path.unlink()
                success(f"Removido: {path}")
            elif path.is_dir():
                shutil.rmtree(path)
                success(f"Diretório removido: {path}")
        except Exception as e:
            error(f"Não foi possível remover {path}: {e}")
    else:
        debug(f"Caminho já limpo: {path}")

def purgar_arquivos_sistema() -> None:
    """Remove executáveis, atalhos, ícones e diretórios de dados/cache do SO."""
    log("Iniciando purga de arquivos instalados no sistema...")

    # 1. Remover binários
    remove_path(LAUNCHER_BIN)
    remove_path(LAUNCHER_BAK)

    # 2. Remover atalhos .desktop dinamicamente
    log("Procurando atalhos claw-launcher no XDG...")
    xdg_dirs = [
        USER_HOME / ".local" / "share" / "applications",
        Path("/usr/share/applications"),
        Path("/usr/local/share/applications"),
    ]
    import os
    xdg_data_dirs = os.environ.get("XDG_DATA_DIRS", "")
    for d in xdg_data_dirs.split(":"):
        if d:
            path_dir = Path(d) / "applications"
            if path_dir.exists() and path_dir not in xdg_dirs:
                xdg_dirs.append(path_dir)

    for app_dir in xdg_dirs:
        if app_dir.exists():
            for file_path in app_dir.rglob("*.desktop"):
                if "claw" in file_path.name.lower():
                    remove_path(file_path)

    # 3. Remover ícones dinamicamente
    log("Procurando arquivos de ícones dinamicamente...")
    xdg_icon_dirs = [
        USER_HOME / ".local" / "share" / "icons",
        Path("/usr/share/icons"),
        Path("/usr/local/share/icons"),
    ]
    for d in xdg_data_dirs.split(":"):
        if d:
            path_dir = Path(d) / "icons"
            if path_dir.exists() and path_dir not in xdg_icon_dirs:
                xdg_icon_dirs.append(path_dir)

    for icon_dir in xdg_icon_dirs:
        if icon_dir.exists():
            try:
                for file_path in icon_dir.rglob("*"):
                    if file_path.is_file() and ("claw" in file_path.name.lower()):
                        remove_path(file_path)
            except Exception as e:
                debug(f"Erro ao escanear ícones em {icon_dir}: {e}")

    # 4. Remover pastas de dados persistentes e caches do usuário
    log("Removendo pastas de dados e caches do usuário...")
    diretorios_busca = [
        USER_HOME / ".local" / "share",
        USER_HOME / ".cache",
        USER_HOME / ".config",
    ]
    for base_dir in diretorios_busca:
        if base_dir.exists():
            for path in base_dir.iterdir():
                if path.is_dir():
                    path_name_lower = path.name.lower()
                    if "claw" in path_name_lower or "recifecrypto" in path_name_lower:
                        remove_path(path)

    # 5. Atualizar caches do sistema
    log("Atualizando caches de atalhos e ícones do desktop...")
    run_cmd(["update-desktop-database", str(APPS_DIR)], check=False)
    run_cmd(["gtk-update-icon-cache", "-f", "-t", str(ICONS_BASE)], check=False)

    success("Purga de arquivos do sistema concluída.")

def limpar_ambiente_repositorio(repo_path: Path) -> None:
    """Remove a pasta de build, instâncias e arquivos temporários do repositório.

    Mantém apenas os arquivos e diretórios essenciais para o funcionamento do app
    (como src-tauri/src/, setup-deps.sh, build.sh, create_app.sh, etc).

    Args:
        repo_path: O caminho absoluto da raiz do repositório.
    """
    log("Limpando ambiente do repositório local...")

    # 1. Remover instâncias de aplicações locais (instance_*)
    for inst_dir in repo_path.glob("instance_*"):
        remove_path(inst_dir)

    # 2. Remover diretório target/ (build cache e arquivos de compilação antigos)
    target_dir = repo_path / "src-tauri" / "target"
    if target_dir.exists():
        log("Removendo cache de build antigo (src-tauri/target)...")
        remove_path(target_dir)

    # 3. Remover arquivos temporários ou backups do repositório (*.bak, *.log, __pycache__, .venv, uv.lock)
    for bak_file in repo_path.glob("*.bak"):
        remove_path(bak_file)
        
    for log_file in repo_path.glob("*.log"):
        remove_path(log_file)

    for pycache in repo_path.rglob("__pycache__"):
        remove_path(pycache)

    # Deletar ambientes virtuais do Python
    remove_path(repo_path / ".venv")
    remove_path(repo_path / "venv")
    remove_path(repo_path / "uv.lock")

    success("Ambiente do repositório limpo (mantidos apenas arquivos de código essenciais).")

# ── 7. Entry Point ────────────────────────────────────────────
def main() -> None:
    """Ponto de entrada para a purga completa do CLAW Launcher."""
    bootstrap_dirs()
    log(f"═══ Purga e Limpeza do Repositório Iniciada ═══")
    log(f"Arquivo de log: {LOG_FILE}")

    # Obter caminho do repositório (diretório pai deste script)
    repo_path = Path(__file__).resolve().parent

    # Ler repositório ativo configurado antes de deletar a pasta de configuração
    active_repo = None
    repo_config = USER_HOME / ".config" / "claw-launcher" / "repo_path.txt"
    if repo_config.exists():
        try:
            path_str = repo_config.read_text().strip()
            if path_str:
                active_repo = Path(path_str)
        except Exception as e:
            debug(f"Erro ao ler repo_path.txt: {e}")

    # 1. Desinstalar tudo do sistema (purga completa)
    purgar_arquivos_sistema()

    # 2. Limpar ambiente do repositório atual (onde o script está localizado)
    limpar_ambiente_repositorio(repo_path)

    success("═══ Purga e Limpeza Concluídas com Sucesso! ═══")

if __name__ == "__main__":
    main()
