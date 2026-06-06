#!/bin/bash
# 🧹 Script de Limpeza de Git - Remove arquivos desnecessários do histórico
# Uso: bash cleanup-git.sh

set -euo pipefail

# Cores para output
G="\033[1;32m"; B="\033[1;34m"; Y="\033[1;33m"; R="\033[1;31m"; C="\033[1;36m"; N="\033[0m"

log()     { echo -e "${B}[INFO]${N}    $*"; }
success() { echo -e "${G}[OK]${N}      $*"; }
warn()    { echo -e "${Y}[AVISO]${N}   $*"; }
error()   { echo -e "${R}[ERRO]${N}    $*" >&2; }
step()    { echo -e "${C}[→]${N}       $*"; }

echo ""
echo "════════════════════════════════════════════════════════════"
echo "🧹 Limpeza de Histórico Git - CLAW Launcher"
echo "════════════════════════════════════════════════════════════"
echo ""

# Verificar se está em repositório Git
if [ ! -d ".git" ]; then
    error "Não está em um repositório Git"
    exit 1
fi

# Menu de opções
echo "Escolha a ação:"
echo ""
echo "  1) Remover target/ do histórico (recomendado)"
echo "  2) Remover instance_*/ do histórico (recomendado)"
echo "  3) Remover .cargo/ do histórico (opcional)"
echo "  4) Fazer limpeza completa (1+2+3)"
echo "  5) Apenas commitar .gitignore (seguro)"
echo "  0) Cancelar"
echo ""
read -r -p "Opção: " choice

case "$choice" in
    1)
        warn "Removendo target/ do histórico..."
        warn "Isto reescreverá o histórico de commits"
        read -r -p "Confirmar? (s/N): " confirm
        if [[ "$confirm" =~ ^[Ss]$ ]]; then
            git rm -r --cached target/ 2>/dev/null || true
            git commit -m "refactor: remover target/ do versionamento" || true
            success "target/ removido"
        fi
        ;;
    2)
        warn "Removendo instance_*/ do histórico..."
        read -r -p "Confirmar? (s/N): " confirm
        if [[ "$confirm" =~ ^[Ss]$ ]]; then
            git rm -r --cached instance_* 2>/dev/null || true
            git commit -m "refactor: remover instâncias de apps do versionamento" || true
            success "instance_*/ removido"
        fi
        ;;
    3)
        warn "Removendo .cargo/ do histórico..."
        read -r -p "Confirmar? (s/N): " confirm
        if [[ "$confirm" =~ ^[Ss]$ ]]; then
            git rm -r --cached .cargo/ 2>/dev/null || true
            git commit -m "refactor: remover .cargo/ cache do versionamento" || true
            success ".cargo/ removido"
        fi
        ;;
    4)
        warn "Fazendo limpeza COMPLETA (isto pode demorar)..."
        read -r -p "CONFIRMAR? (s/N): " confirm
        if [[ "$confirm" =~ ^[Ss]$ ]]; then
            step "Removendo target/..."
            git rm -r --cached target/ 2>/dev/null || true
            
            step "Removendo instance_*/..."
            git rm -r --cached instance_* 2>/dev/null || true
            
            step "Removendo .cargo/..."
            git rm -r --cached .cargo/ 2>/dev/null || true
            
            git commit -m "refactor: limpeza completa - remover build cache e instâncias" || true
            success "Limpeza concluída"
        fi
        ;;
    5)
        step "Commitando .gitignore atualizado..."
        git add .gitignore
        git commit -m "config: .gitignore otimizado - manter apenas essencial" || true
        success ".gitignore commitado"
        ;;
    0)
        warn "Operação cancelada"
        exit 0
        ;;
    *)
        error "Opção inválida"
        exit 1
        ;;
esac

echo ""
echo "════════════════════════════════════════════════════════════"
echo "✅ Limpeza concluída!"
echo "════════════════════════════════════════════════════════════"
echo ""

# Mostrar status
log "Status após limpeza:"
git status --short | head -20

echo ""
echo "💾 Para sincronizar com remote:"
echo "   git push origin main --force-with-lease"
echo ""
