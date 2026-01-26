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
echo " FORENSIC LOGGING: START PATCHING"
echo "================================================================="
echo "PWD: $(pwd)"
echo "Directory structure of deps (maxdepth 2):"
find deps -maxdepth 2 -type d || echo "Find failed"

FFTOOLS_DIR=""

echo "Searching for fftools directory..."
# Order matters: check the one we expect more likely first, but check all.
if [ -d "deps/fftools_ffi" ]; then
    FFTOOLS_DIR="deps/fftools_ffi"
elif [ -d "deps/fftools-ffi" ]; then
    FFTOOLS_DIR="deps/fftools-ffi"
# Fallback search if exact names don't match
else
    echo "WARNING: Standard directories not found. Searching wildcard..."
    FFTOOLS_DIR=$(find deps -maxdepth 1 -type d -name "fftools*" | head -n 1)
fi

echo "Selected FFTOOLS_DIR: '$FFTOOLS_DIR'"

if [ -n "$FFTOOLS_DIR" ]; then
    echo "Found fftools directory at: $FFTOOLS_DIR"
    echo "Patching $FFTOOLS_DIR/ffmpeg.c for av_stream_get_end_pts..."
    
    if [ ! -f "$FFTOOLS_DIR/ffmpeg.c" ]; then
         echo "ERROR: $FFTOOLS_DIR/ffmpeg.c does not exist!"
         echo "Listing contents of $FFTOOLS_DIR:"
         ls -R "$FFTOOLS_DIR" || true
         exit 1
    fi

    echo "--- ffmpeg.c HEAD (before patch) ---"
    head -n 20 "$FFTOOLS_DIR/ffmpeg.c"
    echo "------------------------------------"

    # Check if we already patched it to avoid duplicate definitions
    if ! grep -q "int64_t av_stream_get_end_pts" "$FFTOOLS_DIR/ffmpeg.c"; then
        echo "Appending dummy implementation of av_stream_get_end_pts to $FFTOOLS_DIR/ffmpeg.c..."
        
        # 1. Inject FORWARD DECLARATION
        echo "Injecting forward declaration..."
        if grep -q '#include "libavutil/time.h"' "$FFTOOLS_DIR/ffmpeg.c"; then
             # Match exact line to avoid issues
             # Use a temporary file to ensure atomic write and avoid sed quirks in some envs
             sed 's|#include "libavutil/time.h"|#include "libavutil/time.h"\nint64_t av_stream_get_end_pts(const AVStream *st);|g' "$FFTOOLS_DIR/ffmpeg.c" > "$FFTOOLS_DIR/ffmpeg.c.tmp" && mv "$FFTOOLS_DIR/ffmpeg.c.tmp" "$FFTOOLS_DIR/ffmpeg.c"
             echo "Inserted forward declaration after libavutil/time.h."
        else
             echo "WARNING: Could not find '#include \"libavutil/time.h\"'. Trying to insert after last #include..."
             # Insert after the last #include line
             sed '$!N;s/#include.*\n/#include&\nint64_t av_stream_get_end_pts(const AVStream *st);\n/;P;D' "$FFTOOLS_DIR/ffmpeg.c" > "$FFTOOLS_DIR/ffmpeg.c.tmp" && mv "$FFTOOLS_DIR/ffmpeg.c.tmp" "$FFTOOLS_DIR/ffmpeg.c" || echo "Failed to insert forward decl via sed."
        fi

        # 2. Append IMPLEMENTATION at the bottom
        echo "Appending implementation..."
        cat >> "$FFTOOLS_DIR/ffmpeg.c" <<EOF

// [MediaKit Patch] Dummy implementation for missing internal symbol in static build
int64_t av_stream_get_end_pts(const AVStream *st) {
    return AV_NOPTS_VALUE; 
}
EOF
        echo "Appended implementation."
        
        # Verify
        echo "Verifying patch application..."
        if grep -q "int64_t av_stream_get_end_pts" "$FFTOOLS_DIR/ffmpeg.c"; then
            echo "SUCCESS: av_stream_get_end_pts found in ffmpeg.c after patching."
            echo "--- ffmpeg.c TAIL (after patch) ---"
            tail -n 20 "$FFTOOLS_DIR/ffmpeg.c"
            echo "-----------------------------------"
        else
            echo "ERROR: Failed to patch ffmpeg.c (grep check failed after patch)."
            echo "--- ffmpeg.c TAIL (failed patch) ---"
            tail -n 20 "$FFTOOLS_DIR/ffmpeg.c"
            exit 1
        fi
    else
        echo "av_stream_get_end_pts implementation already present. Skipping."
    fi

    # Also patch avcodec_get_name if needed (usually handled elsewhere but safe to ensure)
    sed -i 's/avcodec_get_name/avcodec_get_name_null/g' "$FFTOOLS_DIR/ffmpeg_filter.c" || true
else
    echo "ERROR: fftools-ffi directory not found!"
    echo "Listing deps/:"
    ls -l deps/ || true
    exit 1
fi

echo "================================================================="
echo " FORENSIC LOGGING: DONE PATCHING"
echo "================================================================="

exit 0
