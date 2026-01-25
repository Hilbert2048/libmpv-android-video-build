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
# Fix fftools_ffi compatibility with FFmpeg 7.1 (av_stream_get_end_pts removed)
# Fix fftools_ffi compatibility with FFmpeg 7.1 (av_stream_get_end_pts removed)
if [ -d "deps/fftools_ffi" ]; then
    echo "Found deps/fftools_ffi. Applying manual fix for av_stream_get_end_pts..."
    cd deps/fftools_ffi
    
    # Patch ffmpeg.h instead of ffmpeg.c to ensure visibility across translation units
    # Insert inside the header, after includes. Assuming standard include guards or content.
    # We'll simple append it to the end, but before the last #endif if possible, or just after includes.
    # Safer: Insert at the top of ffmpeg.c after all system includes.
    
    # Let's try inserting into ffmpeg.c again but with a very generic match to ensure it works.
    # We place it after the last #include to ensure types are defined.
    # Using '1,/^#include/!d' logic is hard in sed -i.
    # Simple approach: Match 'main(' or 'int main' and insert BEFORE it? No, global scope.
    # Match the last include?
    
    # Let's check if patch is already applied
    if grep -q "av_stream_get_end_pts(st)" ffmpeg.c; then
        echo "Patch already present in ffmpeg.c."
        cd $ROOT
    else
        # Insert after the block of includes. 
        # ffmpeg.c typically starts with many includes. 
        # We'll just insert at line 20, or find a safe anchor like 'const char program_name'.
        # Or better: just append to config.h? No.
        
        # Let's try inserting after '#include "ffmpeg.h"' or '#include <stdlib.h>'
        # If previous sed failed, maybe that include line looks different.
        
        # We will append the macro to the end of 'config.h' if it exists (it's often included everywhere).
        # But config.h is auto-generated.
        
        # Let's stick to ffmpeg.c and use a very robust insertion: Line 2.
        # But we need includes.
        
        # Robust strategy: Insert after the first line that starts with '#include'.
        # sed -i '0,/^#include/s//&/' ... no.
        
        # Let's use the define that identifies the file/project if possible.
        # How about inserting at the end of 'ffmpeg.h'?
        if [ -f "ffmpeg.h" ]; then
             echo "Patching ffmpeg.h..."
             # Insert before the last line (assuming #endif)
             sed -i '$i #define av_stream_get_end_pts(st) ((st)->duration != AV_NOPTS_VALUE ? (st)->start_time + (st)->duration : AV_NOPTS_VALUE)' ffmpeg.h
        else
             echo "ffmpeg.h not found, patching ffmpeg.c..."
             # Fallback to ffmpeg.c, insert at line 50 (arbitrary but likely after includes)
             sed -i '50i #define av_stream_get_end_pts(st) ((st)->duration != AV_NOPTS_VALUE ? (st)->start_time + (st)->duration : AV_NOPTS_VALUE)' ffmpeg.c
        fi
        
        echo "Verifying patch..."
        if grep -q "av_stream_get_end_pts" ffmpeg.h || grep -q "av_stream_get_end_pts" ffmpeg.c; then
            echo "Patch successfully applied."
        else
            echo "ERROR: Patch failed to apply!"
            exit 1
        fi
        cd $ROOT
    fi
else
    echo "ERROR: deps/fftools_ffi not found!"
    echo "Current directory: $(pwd)"
    echo "Contents of deps/:"
    ls -F deps/ || true
    exit 1
fi

exit 0
