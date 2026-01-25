#!/bin/bash -e

. ../../include/depinfo.sh
. ../../include/path.sh

build=_build$ndk_suffix

if [ "$1" == "build" ]; then
	true
elif [ "$1" == "clean" ]; then
	rm -rf _build$ndk_suffix
	exit 0
else
	exit 255
fi

unset CC CXX # meson wants these unset

# Fix NDK compatibility: define AAUDIO_FORMAT_IEC61937 if missing (API 33+)
# Using sed instead of patch to avoid context mismatch issues
if [ -f audio/out/ao_aaudio.c ]; then
    sed -i '/struct priv {/i \
#ifndef AAUDIO_FORMAT_IEC61937\n#define AAUDIO_FORMAT_IEC61937 13\n#endif\n' audio/out/ao_aaudio.c
fi

meson setup $build --cross-file "$prefix_dir"/crossfile.txt \
	-Dc_link_args="-lc++_shared" \
	-Dcpp_link_args="-lc++_shared" \
	--prefer-static \
	--default-library shared \
	-Dgpl=false \
	-Dlibmpv=true \
	-Dlua=disabled \
	-Dcplayer=false \
	-Diconv=disabled \
	-Djavascript=disabled \
	-Dwayland=disabled \
	-Dx11=disabled \
	-Ddrm=disabled \
	-Dgl-x11=disabled \
	-Degl-x11=disabled \
	-Dmanpage-build=disabled

ninja -C $build -j$cores
DESTDIR="$prefix_dir" ninja -C $build install

ln -sf "$prefix_dir"/lib/libmpv.so "$native_dir"
