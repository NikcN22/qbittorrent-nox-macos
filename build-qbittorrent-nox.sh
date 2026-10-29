#!/bin/bash
#
#  build-qbittorrent-nox.sh
#
#  Builds qbittorrent-nox for macOS from the unmodified upstream sources of
#  qBittorrent, libtorrent, Qt, OpenSSL and Boost, linked statically: the binary
#  depends only on libraries that ship with macOS.
#
#  The same build as the qBittorrent that Lizard installs, without signing and
#  notarization: a binary built on this Mac runs here as is.
#
#  Usage:
#    ./build-qbittorrent-nox.sh
#
#  Builds for the architecture of this Mac. The result is qbt-build/qbittorrent-nox
#  in the current folder, another folder can be set in BUILD_DIR.
#
#  Requires Xcode command line tools, cmake and ninja (brew install cmake ninja).
#

set -euo pipefail

QBT_VERSION="5.2.4"
LIBTORRENT_VERSION="2.0.11"
QT_VERSION="6.8.3"
OPENSSL_VERSION="3.5.0"
BOOST_VERSION="1.88.0"
MACOS_DEPLOYMENT_TARGET="13.0"

ARCH="$(uname -m)"
case "$ARCH" in
    arm64) OPENSSL_TARGET="darwin64-arm64-cc" ;;
    x86_64) OPENSSL_TARGET="darwin64-x86_64-cc" ;;
    *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;;
esac

ROOT="${BUILD_DIR:-$PWD/qbt-build}"
SRC="$ROOT/src"
ARCHIVES="$SRC/archives"
WORK="$ROOT/work"
PREFIX="$WORK/prefix"
JOBS="$(sysctl -n hw.ncpu)"

export MACOSX_DEPLOYMENT_TARGET="$MACOS_DEPLOYMENT_TARGET"
CMAKE_COMMON=(
    -G Ninja
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_OSX_ARCHITECTURES="$ARCH"
    -DCMAKE_OSX_DEPLOYMENT_TARGET="$MACOS_DEPLOYMENT_TARGET"
    -DCMAKE_PREFIX_PATH="$PREFIX"
    -DCMAKE_INSTALL_PREFIX="$PREFIX"
    -DBUILD_SHARED_LIBS=OFF
)

QT_EXTRA_FLAGS=()
if [[ "$ARCH" == arm64 ]]; then
    for lang in C CXX OBJC OBJCXX; do
        QT_EXTRA_FLAGS+=(-DCMAKE_${lang}_FLAGS="-include arm_acle.h")
    done
fi

step() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }

fetch() {
    local url="$1" dir="$2" name="${3:-${1##*/}}"
    local archive="$ARCHIVES/$name"
    mkdir -p "$ARCHIVES"
    if [[ ! -f "$archive" ]]; then
        curl -fL -o "$archive.part" "$url"
        mv "$archive.part" "$archive"
    fi
    [[ -d "$SRC/$dir" ]] || tar -xf "$archive" -C "$SRC"
}

mkdir -p "$WORK" "$PREFIX"

step "OpenSSL $OPENSSL_VERSION"
fetch "https://github.com/openssl/openssl/releases/download/openssl-$OPENSSL_VERSION/openssl-$OPENSSL_VERSION.tar.gz" "openssl-$OPENSSL_VERSION"
rm -rf "$WORK/openssl" && cp -R "$SRC/openssl-$OPENSSL_VERSION" "$WORK/openssl"
(
    cd "$WORK/openssl"
    ./Configure "$OPENSSL_TARGET" no-shared no-tests --prefix="$PREFIX" --libdir=lib "-mmacosx-version-min=$MACOS_DEPLOYMENT_TARGET"
    make -j"$JOBS"
    make install_sw
)

step "Boost $BOOST_VERSION (headers)"
BOOST_DIR="boost_${BOOST_VERSION//./_}"
fetch "https://archives.boost.io/release/$BOOST_VERSION/source/$BOOST_DIR.tar.gz" "$BOOST_DIR"

step "libtorrent $LIBTORRENT_VERSION"
fetch "https://github.com/arvidn/libtorrent/releases/download/v$LIBTORRENT_VERSION/libtorrent-rasterbar-$LIBTORRENT_VERSION.tar.gz" "libtorrent-rasterbar-$LIBTORRENT_VERSION"
cmake -S "$SRC/libtorrent-rasterbar-$LIBTORRENT_VERSION" -B "$WORK/libtorrent" "${CMAKE_COMMON[@]}" \
    -DBOOST_ROOT="$SRC/$BOOST_DIR" \
    -DOPENSSL_ROOT_DIR="$PREFIX" \
    -Ddeprecated-functions=OFF
cmake --build "$WORK/libtorrent"
cmake --install "$WORK/libtorrent"

step "Qt $QT_VERSION (qtbase, no GUI)"
QT_MINOR="${QT_VERSION%.*}"
fetch "https://download.qt.io/archive/qt/$QT_MINOR/$QT_VERSION/submodules/qtbase-everywhere-src-$QT_VERSION.tar.xz" "qtbase-everywhere-src-$QT_VERSION"
cmake -S "$SRC/qtbase-everywhere-src-$QT_VERSION" -B "$WORK/qtbase" "${CMAKE_COMMON[@]}" ${QT_EXTRA_FLAGS[@]+"${QT_EXTRA_FLAGS[@]}"} \
    -DFEATURE_gui=OFF -DFEATURE_widgets=OFF -DFEATURE_dbus=OFF \
    -DFEATURE_openssl_linked=ON -DOPENSSL_ROOT_DIR="$PREFIX" \
    -DFEATURE_sql_sqlite=ON -DFEATURE_system_sqlite=OFF \
    -DQT_BUILD_EXAMPLES=OFF -DQT_BUILD_TESTS=OFF
cmake --build "$WORK/qtbase"
cmake --install "$WORK/qtbase"

step "Qt $QT_VERSION (qttools, Linguist tools only)"
fetch "https://download.qt.io/archive/qt/$QT_MINOR/$QT_VERSION/submodules/qttools-everywhere-src-$QT_VERSION.tar.xz" "qttools-everywhere-src-$QT_VERSION"
cmake -S "$SRC/qttools-everywhere-src-$QT_VERSION" -B "$WORK/qttools" "${CMAKE_COMMON[@]}" ${QT_EXTRA_FLAGS[@]+"${QT_EXTRA_FLAGS[@]}"} \
    -DFEATURE_assistant=OFF -DFEATURE_designer=OFF -DFEATURE_clang=OFF -DFEATURE_qdoc=OFF \
    -DFEATURE_distancefieldgenerator=OFF -DFEATURE_pixeltool=OFF -DFEATURE_qdbus=OFF -DFEATURE_qev=OFF \
    -DFEATURE_qtattributionsscanner=OFF -DFEATURE_qtdiag=OFF -DFEATURE_qtplugininfo=OFF -DFEATURE_kmap2qmap=OFF \
    -DQT_BUILD_EXAMPLES=OFF -DQT_BUILD_TESTS=OFF
cmake --build "$WORK/qttools"
cmake --install "$WORK/qttools"

step "qBittorrent $QBT_VERSION (nox)"
fetch "https://github.com/qbittorrent/qBittorrent/archive/refs/tags/release-$QBT_VERSION.tar.gz" "qBittorrent-release-$QBT_VERSION" "qBittorrent-release-$QBT_VERSION.tar.gz"
cmake -S "$SRC/qBittorrent-release-$QBT_VERSION" -B "$WORK/qbittorrent" "${CMAKE_COMMON[@]}" ${QT_EXTRA_FLAGS[@]+"${QT_EXTRA_FLAGS[@]}"} \
    -DGUI=OFF -DSTACKTRACE=OFF \
    -DBOOST_ROOT="$SRC/$BOOST_DIR" \
    -DOPENSSL_ROOT_DIR="$PREFIX"
cmake --build "$WORK/qbittorrent"

BINARY="$WORK/qbittorrent/qbittorrent-nox"
[[ -f "$BINARY" ]] || BINARY="$(find "$WORK/qbittorrent" -type f -name qbittorrent-nox -perm -u+x | head -n1)"

step "Checking linkage"
if otool -L "$BINARY" | tail -n +2 | grep -vE '^\s+(/usr/lib/|/System/)'; then
    echo "Non-system libraries are linked, aborting." >&2
    exit 1
fi

cp "$BINARY" "$ROOT/qbittorrent-nox"

echo
echo "Built: $ROOT/qbittorrent-nox"
"$ROOT/qbittorrent-nox" --version
