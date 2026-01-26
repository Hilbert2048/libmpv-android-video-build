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

echo "================================================================="
echo "Patching fftools for av_stream_get_end_pts compatibility..."
echo "================================================================="

FFTOOLS_DIR=""

# Order matters: check the one we expect more likely first
if [ -d "deps/fftools_ffi" ]; then
    FFTOOLS_DIR="deps/fftools_ffi"
elif [ -d "deps/fftools-ffi" ]; then
    FFTOOLS_DIR="deps/fftools-ffi"
fi

if [ -n "$FFTOOLS_DIR" ]; then
    echo "Found fftools directory at: $FFTOOLS_DIR"
    
    if [ ! -f "$FFTOOLS_DIR/ffmpeg.c" ]; then
         echo "ERROR: $FFTOOLS_DIR/ffmpeg.c does not exist!"
         exit 1
    fi

    # Check if we already patched it to avoid duplicate definitions
    if ! grep -q "define av_stream_get_end_pts" "$FFTOOLS_DIR/ffmpeg.c"; then
        echo "Applying macro definition..."
        
        # Try to insert after config.h, which is always at the top.
        if grep -q '#include "config.h"' "$FFTOOLS_DIR/ffmpeg.c"; then
             sed 's|#include "config.h"|#include "config.h"\n#define av_stream_get_end_pts(st) ((st)->duration != AV_NOPTS_VALUE ? (st)->start_time + (st)->duration : AV_NOPTS_VALUE)|g' "$FFTOOLS_DIR/ffmpeg.c" > "$FFTOOLS_DIR/ffmpeg.c.tmp" && mv "$FFTOOLS_DIR/ffmpeg.c.tmp" "$FFTOOLS_DIR/ffmpeg.c"
        else
             # Insert at line 2
             sed '2i #define av_stream_get_end_pts(st) ((st)->duration != AV_NOPTS_VALUE ? (st)->start_time + (st)->duration : AV_NOPTS_VALUE)' "$FFTOOLS_DIR/ffmpeg.c" > "$FFTOOLS_DIR/ffmpeg.c.tmp" && mv "$FFTOOLS_DIR/ffmpeg.c.tmp" "$FFTOOLS_DIR/ffmpeg.c"
        fi
        
        # Verify
        if grep -q "define av_stream_get_end_pts" "$FFTOOLS_DIR/ffmpeg.c"; then
            echo "SUCCESS: Macro injected."
        else
            echo "ERROR: Failed to patch ffmpeg.c."
            exit 1
        fi
    else
        echo "Macro already present. Skipping."
    fi

    # Also patch avcodec_get_name if needed
    sed -i 's/avcodec_get_name/avcodec_get_name_null/g' "$FFTOOLS_DIR/ffmpeg_filter.c" || true
else
    echo "WARNING: fftools-ffi directory not found. Skipping patch."
fi

echo "Done."

exit 0
