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

meson setup $build --cross-file "$prefix_dir"/crossfile.txt \
	-Dvulkan=disabled \
	-Dopengl=disabled \
	-Dd3d11=disabled \
	-Ddemos=false \
	-Dtests=false \
	-Dbench=false \
	-Dfuzz=false \
	-Dlcms=disabled \
	-Dxxhash=disabled \
	-Dunwind=disabled

ninja -C $build -j$cores
DESTDIR="$prefix_dir" ninja -C $build install
