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

CFLAGS=-fPIC CXXFLAGS=-fPIC meson setup $build --cross-file "$prefix_dir"/crossfile.txt


ninja -C $build -j$cores
DESTDIR="$prefix_dir" ninja -C $build install

# FORENSIC LOGGING: Check if symbol exists in the static library
echo "================================================================="
echo " FORENSIC LOGGING: CHECKING SYMBOLS IN libfftools-ffi.a"
echo "================================================================="
LIB_PATH="$prefix_dir/usr/local/lib/libfftools-ffi.a"
if [ -f "$LIB_PATH" ]; then
    echo "Library found at $LIB_PATH"
    echo "Running llvm-nm to check for av_stream_get_end_pts..."
    # standard nm output: T = defined, U = undefined
    ${NDK_ROOT}/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-nm "$LIB_PATH" | grep "av_stream_get_end_pts" || echo "Symbol av_stream_get_end_pts NOT FOUND in nm output"
else
    echo "ERROR: Library $LIB_PATH not found after install!"
    ls -R "$prefix_dir" || true
fi
echo "================================================================="

