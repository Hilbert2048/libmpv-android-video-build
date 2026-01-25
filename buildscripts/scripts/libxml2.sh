#!/bin/bash -e

. ../../include/depinfo.sh
. ../../include/path.sh

build=_build$ndk_suffix

if [ "$1" == "build" ]; then
	true
elif [ "$1" == "clean" ]; then
	rm -rf $build
	exit 0
else
	exit 255
fi

unset CC CXX # meson wants these unset

# libxml2 2.13+ prefers Meson.
# Autotools has issues detecting cross-compilation on Android CI.

meson setup $build --cross-file "$prefix_dir"/crossfile.txt \
	--prefix=/ \
	--default-library=static \
	-Dhttp=false \
	-Dftp=false \
	-Dlzma=disabled \
	-Dzlib=disabled \
	-Diconv=disabled \
	-Dpython=false \
	-Dthreads=enabled

# Build ONLY the static library target
ninja -C $build -j$cores libxml2.a

# Manual Installation
echo "=== Installing libxml2 manually ==="

# 1. Install Library
mkdir -p "$prefix_dir/lib"
cp "$build/libxml2.a" "$prefix_dir/lib/"
echo "Library installed: $prefix_dir/lib/libxml2.a"

# 2. Install Headers
# FFmpeg expects headers at include/libxml2/libxml/parser.h
# xmlversion.h is GENERATED during build (from xmlversion.h.in)
SRC_DIR="$DIR/deps/libxml2"
mkdir -p "$prefix_dir/include/libxml2/libxml"

# Copy source headers
cp "$SRC_DIR/include/libxml/"*.h "$prefix_dir/include/libxml2/libxml/" 2>/dev/null || true

# Copy generated xmlversion.h from build directory
XMLVERSION=$(find "$build" -name "xmlversion.h" -type f | head -1)
if [ -n "$XMLVERSION" ]; then
    cp "$XMLVERSION" "$prefix_dir/include/libxml2/libxml/"
    echo "Copied generated xmlversion.h from: $XMLVERSION"
else
    echo "ERROR: xmlversion.h not found in build directory!"
    find "$build" -name "*.h" -type f
    exit 1
fi

# 3. Install pkg-config file
mkdir -p "$prefix_dir/lib/pkgconfig"
cp "$build/meson-private/libxml-2.0.pc" "$prefix_dir/lib/pkgconfig/"

# Fix the .pc file:
# 1. prefix=/ to work with PKG_CONFIG_SYSROOT_DIR
# 2. includedir must point to include/libxml2 (not just include)
#    because headers use relative includes like #include <libxml/xmlexports.h>
sed -i 's|^prefix=.*|prefix=/|g' "$prefix_dir/lib/pkgconfig/libxml-2.0.pc"
sed -i 's|^includedir=.*|includedir=${prefix}/include/libxml2|g' "$prefix_dir/lib/pkgconfig/libxml-2.0.pc"

# Verification
echo "=== Verification ==="
echo "Headers at $prefix_dir/include/libxml2/libxml/:"
ls "$prefix_dir/include/libxml2/libxml/" | head -10
echo ""
echo "xmlversion.h content check (first 5 lines):"
head -5 "$prefix_dir/include/libxml2/libxml/xmlversion.h"
echo ""
echo "pkg-config file:"
cat "$prefix_dir/lib/pkgconfig/libxml-2.0.pc"

echo ""
echo "libxml2 install complete."
