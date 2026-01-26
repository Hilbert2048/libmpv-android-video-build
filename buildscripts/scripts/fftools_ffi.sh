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


# [MediaKit Patch] Apply fix for av_stream_get_end_pts directly in build script
if [ -f "ffmpeg.c" ]; then
    if ! grep -q "define av_stream_get_end_pts" "ffmpeg.c"; then
        # Force insert after config.h
        if grep -q '#include "config.h"' "ffmpeg.c"; then
             sed 's|#include "config.h"|#include "config.h"\n#define av_stream_get_end_pts(st) ((st)->duration != AV_NOPTS_VALUE ? (st)->start_time + (st)->duration : AV_NOPTS_VALUE)|g' "ffmpeg.c" > "ffmpeg.c.tmp" && mv "ffmpeg.c.tmp" "ffmpeg.c"
        else
             sed '2i #define av_stream_get_end_pts(st) ((st)->duration != AV_NOPTS_VALUE ? (st)->start_time + (st)->duration : AV_NOPTS_VALUE)' "ffmpeg.c" > "ffmpeg.c.tmp" && mv "ffmpeg.c.tmp" "ffmpeg.c"
        fi
    fi
    
    # Also patch avcodec_get_name if needed
    if [ -f "ffmpeg_filter.c" ]; then
        sed -i 's/avcodec_get_name/avcodec_get_name_null/g' "ffmpeg_filter.c" || true
    fi
else
    echo "ERROR: ffmpeg.c not found in $(pwd)"
    exit 1
fi


CFLAGS=-fPIC CXXFLAGS=-fPIC meson setup $build --cross-file "$prefix_dir"/crossfile.txt




ninja -C $build -j$cores
DESTDIR="$prefix_dir" ninja -C $build install


