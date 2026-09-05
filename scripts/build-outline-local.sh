#!/usr/bin/env bash
# ==============================================================================
# build-outline-local.sh
#
# Compila o Outline na estação de trabalho local (WSL / Linux) e gera um
# pacote compactado (outline-build.tar.gz) pronto para ser transferido e
# implantado na VM e2-micro via Ansible.
#
# Isso poupa o processamento e a memória limitada da máquina e2-micro.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
OUTPUT_DIR="${ROOT_DIR}/ansible/files"
OUTPUT_TARBALL="${OUTPUT_DIR}/outline-build.tar.gz"

OUTLINE_REPO_URL="${OUTLINE_REPO_URL:-https://github.com/outline/outline.git}"
OUTLINE_VERSION="${OUTLINE_VERSION:-main}"
BUILD_WORK_DIR="${BUILD_WORK_DIR:-/tmp/outline-local-build}"

echo "========================================================="
echo " Compilação local do Outline para implantação na GCP VM  "
echo "========================================================="
echo "Repositório: ${OUTLINE_REPO_URL}"
echo "Versão/Tag:  ${OUTLINE_VERSION}"
echo "Diretório:   ${BUILD_WORK_DIR}"
echo "Destino:     ${OUTPUT_TARBALL}"
echo "========================================================="

# 1. Verificar Node.js
if ! command -v node >/dev/null 2>&1; then
  echo "Erro: Node.js não foi encontrado nesta estação. Instale o Node.js v20+ para continuar." >&2
  exit 1
fi

echo "Versão do Node.js: $(node -v)"

# 2. Garantir yarn disponível
if ! command -v yarn >/dev/null 2>&1; then
  echo "Yarn não encontrado. Tentando habilitar via corepack..."
  if command -v corepack >/dev/null 2>&1; then
    corepack enable || true
  fi
  if ! command -v yarn >/dev/null 2>&1; then
    echo "Instalando yarn via npm..."
    npm install --global yarn
  fi
fi

echo "Versão do Yarn: $(yarn -v)"

# 3. Preparar diretório de build
mkdir -p "${BUILD_WORK_DIR}"
mkdir -p "${OUTPUT_DIR}"

if [ ! -d "${BUILD_WORK_DIR}/.git" ]; then
  echo "Clonando repositório do Outline..."
  git clone --depth 1 --branch "${OUTLINE_VERSION}" "${OUTLINE_REPO_URL}" "${BUILD_WORK_DIR}"
else
  echo "Atualizando repositório existente..."
  cd "${BUILD_WORK_DIR}"
  git fetch --depth 1 origin "${OUTLINE_VERSION}"
  git checkout -f "${OUTLINE_VERSION}"
  git reset --hard "origin/${OUTLINE_VERSION}"
fi

cd "${BUILD_WORK_DIR}"

# 4. Instalar dependências
echo "Instalando dependências via Yarn..."
yarn install --immutable || yarn install

# 5. Gerar build do Outline
echo "Compilando Outline (yarn build)..."
export NODE_OPTIONS="--max-old-space-size=4096"
yarn build

# 6. Empacotar artefatos para transferência
echo "Empacotando artefatos compilados em ${OUTPUT_TARBALL}..."
tar -czf "${OUTPUT_TARBALL}" \
  build \
  server \
  shared \
  public \
  .sequelizerc \
  package.json \
  yarn.lock \
  .yarnrc.yml 2>/dev/null || \
tar -czf "${OUTPUT_TARBALL}" \
  build \
  server \
  shared \
  public \
  .sequelizerc \
  package.json \
  yarn.lock

echo "========================================================="
echo " Sucesso! Artefato gerado: ${OUTPUT_TARBALL} "
echo " Tamanho: $(du -sh "${OUTPUT_TARBALL}" | cut -f1)"
echo ""
echo " Ao executar o Ansible, ele detectará automaticamente este"
echo " arquivo e transferirá diretamente para a VM na GCP."
echo "========================================================="
