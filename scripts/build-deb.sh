#!/bin/bash
# Build Debian package for cryptnox-cli
# Usage: ./build-deb.sh [version]
#
# Supports: Debian 12+, Ubuntu 22.04+, Linux Mint 21+

set -e

# Capture script location BEFORE any cd commands
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "${SCRIPT_DIR}")"

VERSION="${1:-1.0.3}"
PKG_NAME="cryptnox-cli"
BUILD_DIR="${BUILD_DIR:-$(mktemp -d /tmp/cryptnox-deb-build.XXXXXX)}"
SKIP_DEPS="${SKIP_DEPS:-false}"

echo "=== Building ${PKG_NAME} ${VERSION} deb package ==="
echo "Build directory: ${BUILD_DIR}"
echo "Repo root: ${REPO_ROOT}"

# Cleanup previous build if using default location
if [[ "${BUILD_DIR}" == /tmp/cryptnox-deb-build.* ]]; then
    trap "rm -rf ${BUILD_DIR}" EXIT
fi
mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}"

# Download source from PyPI
echo "Downloading ${PKG_NAME} ${VERSION} from PyPI..."
pip3 download --no-deps --no-binary :all: "${PKG_NAME}==${VERSION}"

# Extract source
TAR_FILE=$(ls ${PKG_NAME}*.tar.gz 2>/dev/null || ls ${PKG_NAME//-/_}*.tar.gz)
echo "Extracting ${TAR_FILE}..."
tar -xzf "${TAR_FILE}"

# Find extracted directory
SRC_DIR=$(find . -maxdepth 1 -type d -name "${PKG_NAME}*" -o -name "${PKG_NAME//-/_}*" | grep -v "^\.$" | head -1)
if [ -z "${SRC_DIR}" ]; then
    SRC_DIR=$(find . -maxdepth 1 -type d ! -name "." | head -1)
fi

# Rename to Debian standard format
DEBIAN_DIR="${PKG_NAME}-${VERSION}"
mv "${SRC_DIR}" "${DEBIAN_DIR}"
cd "${DEBIAN_DIR}"

# Copy debian directory from repo root
if [ -d "${REPO_ROOT}/debian" ]; then
    cp -r "${REPO_ROOT}/debian" .
    echo "Copied debian/ from ${REPO_ROOT}"
else
    echo "Error: debian/ directory not found at ${REPO_ROOT}"
    exit 1
fi

# Update changelog version if different
if [ "${VERSION}" != "1.0.3" ]; then
    sed -i "s/1.0.3-1/${VERSION}-1/g" debian/changelog
fi

# Install build dependencies (skip with SKIP_DEPS=true)
if [ "${SKIP_DEPS}" != "true" ]; then
    echo "Installing build dependencies..."
    sudo apt-get update
    sudo apt-get install -y \
        debhelper \
        dh-python \
        python3-all \
        python3-setuptools \
        python3-pip \
        pybuild-plugin-pyproject \
        swig \
        libpcsclite-dev \
        pcscd \
        devscripts \
        fakeroot
else
    echo "Skipping dependency installation (SKIP_DEPS=true)"
fi

# Build the package
echo "Building package..."
dpkg-buildpackage -us -uc -b

# Copy results
echo "=== Build complete ==="
echo "Packages are in: ${BUILD_DIR}"
ls -la "${BUILD_DIR}"/*.deb 2>/dev/null || echo "No .deb files found"

echo ""
echo "To install: sudo dpkg -i ${BUILD_DIR}/${PKG_NAME}_${VERSION}-1_*.deb"
echo "Then fix dependencies: sudo apt-get install -f"
