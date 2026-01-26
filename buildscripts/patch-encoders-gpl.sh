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

echo "Checking for fftools-ffi directory..."
if [ -n "$FFTOOLS_DIR" ]; then
    echo "Found fftools directory at: $FFTOOLS_DIR"
    echo "Patching $FFTOOLS_DIR/ffmpeg.c for av_stream_get_end_pts..."
    
    if [ ! -f "$FFTOOLS_DIR/ffmpeg.c" ]; then
         echo "ERROR: $FFTOOLS_DIR/ffmpeg.c does not exist!"
         exit 1
    fi

    # Check if we already patched it to avoid duplicate definitions
    if ! grep -q "int64_t av_stream_get_end_pts" "$FFTOOLS_DIR/ffmpeg.c"; then
        echo "Appending dummy implementation of av_stream_get_end_pts to $FFTOOLS_DIR/ffmpeg.c..."
        
        # 1. Inject FORWARD DECLARATION at the top (after includes) to avoid implicit declaration error
        # We insert after the last #include to be safe (around line 100 usually, or just after config.h)
        # Using sed to insert after the first few lines is risky if includes change.
        # Let's try inserting after '#include "libavutil/time.h"' which should be present.
        if grep -q '#include "libavutil/time.h"' "$FFTOOLS_DIR/ffmpeg.c"; then
            sed -i '/#include "libavutil\/time.h"/a int64_t av_stream_get_end_pts(const AVStream *st);' "$FFTOOLS_DIR/ffmpeg.c"
            echo "Inserted forward declaration."
        else
            echo "WARNING: Could not find '#include \"libavutil/time.h\"' to insert forward declaration. Appending to end only."
        fi

        # 2. Append IMPLEMENTATION at the bottom
        cat >> "$FFTOOLS_DIR/ffmpeg.c" <<EOF

// [MediaKit Patch] Dummy implementation for missing internal symbol in static build
int64_t av_stream_get_end_pts(const AVStream *st) {
    return AV_NOPTS_VALUE; 
}
EOF
        echo "Appended implementation."
        
        # Verify
        if grep -q "int64_t av_stream_get_end_pts" "$FFTOOLS_DIR/ffmpeg.c"; then
            echo "SUCCESS: av_stream_get_end_pts found in ffmpeg.c after patching."
        else
            echo "ERROR: Failed to patch ffmpeg.c (grep check failed after patch)."
            exit 1
        fi
    else
        echo "av_stream_get_end_pts implementation already present. Skipping."
    fi

    # Also patch avcodec_get_name if needed (usually handled elsewhere but safe to ensure)
    sed -i 's/avcodec_get_name/avcodec_get_name_null/g' "$FFTOOLS_DIR/ffmpeg_filter.c" || true
else
    echo "WARNING: fftools-ffi directory not found, skipping av_stream_get_end_pts patch."
    ls -l deps/ || true
fi

exit 0
