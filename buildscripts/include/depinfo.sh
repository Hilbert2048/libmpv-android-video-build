#!/bin/bash -e

## Dependency versions

v_sdk=9123335_latest
v_ndk=25.2.9519653
v_sdk_build_tools=33.0.2

v_libass=0.17.1
v_harfbuzz=8.1.1
v_fribidi=1.0.13
v_freetype=2.13.2
v_mbedtls=3.4.1
v_dav1d=1.5.0
v_libxml2=2.13.5
v_ffmpeg=7.1
v_libplacebo=7.349.0
v_mpv=4f401b3a5dca5e064d1612859e58735ea57ea99e
v_libogg=1.3.5
v_libvorbis=1.3.7
v_libvpx=1.13


## Dependency tree
# I would've used a dict but putting arrays in a dict is not a thing

dep_mbedtls=()
dep_dav1d=()
dep_libvorbis=(libogg)
if [ -n "${ENCODERS_GPL+x}" ]; then
	dep_ffmpeg=(mbedtls dav1d libxml2 libvorbis libvpx libx264)
else
	dep_ffmpeg=(mbedtls dav1d libxml2)
fi
dep_freetype2=()
dep_fribidi=()
dep_harfbuzz=()
dep_libass=(freetype fribidi harfbuzz)
dep_lua=()
dep_shaderc=()
dep_libplacebo=(shaderc)
dep_fftools_ffi=(ffmpeg)
if [ -n "${ENCODERS_GPL+x}" ]; then
	dep_mpv=(ffmpeg libass libplacebo fftools_ffi)
else
	dep_mpv=(ffmpeg libass libplacebo fftools_ffi)
fi

