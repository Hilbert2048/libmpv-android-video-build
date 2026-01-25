#!/bin/bash -e

PATCHES=(patches-encoders-gpl/*)
ROOT=$(pwd)

for dep_path in "${PATCHES[@]}"; do
    if [ -d "$dep_path" ]; then
        patches=($dep_path/*)
        dep=$(echo $dep_path |cut -d/ -f 2)
        cd deps/$dep
        echo Patching $dep
        git reset --hard
        for patch in "${patches[@]}"; do
            echo Applying $patch
            git apply "$ROOT/$patch"
        done

        if [ "$dep" == "mpv" ]; then
            echo "Injecting fftools-ffi dependency into meson.build using sed..."
            
            # 1. Define dependency (after libavutil)
            sed -i "/libavutil = dependency/a libfftools_ffi = dependency('fftools-ffi')" meson.build
            
            # 2. Add to dependencies list (after libavutil in the list)
            # Assumption: libavutil is in the main dependencies list
            sed -i "/libavutil,/a \                libfftools_ffi," meson.build
            
            # 3. Add source file (after ta/ta_utils.c)
            # Assumption: ta/ta_utils.c is in the main sources list
            sed -i "/'ta\/ta_utils.c'/a \    'fftools-ffi.c'," meson.build
        fi
        cd $ROOT
    fi
done

# Fix fftools_ffi compatibility with FFmpeg 7.1 (av_stream_get_end_pts removed)
# We replace the function call with AV_NOPTS_VALUE because the function is missing in static builds
FFTOOLS_DIR=""
if [ -d "deps/fftools-ffi" ]; then
    FFTOOLS_DIR="deps/fftools-ffi"
elif [ -d "deps/fftools_ffi" ]; then
    FFTOOLS_DIR="deps/fftools_ffi"
fi

if [ -n "$FFTOOLS_DIR" ]; then
    echo "Patching $FFTOOLS_DIR/ffmpeg.c for av_stream_get_end_pts..."
    sed -i 's/av_stream_get_end_pts([^)]*)/AV_NOPTS_VALUE/g' "$FFTOOLS_DIR/ffmpeg.c"
    
    # Also patch avcodec_get_name if needed (usually handled elsewhere but safe to ensure)
    sed -i 's/avcodec_get_name/avcodec_get_name_null/g' "$FFTOOLS_DIR/ffmpeg_filter.c" || true
else
    echo "WARNING: fftools-ffi directory not found, skipping av_stream_get_end_pts patch."
fi

exit 0
