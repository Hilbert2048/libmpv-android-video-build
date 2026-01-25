# libmpv-android-video-build

Build scripts for building libmpv and FFmpeg for Android, tailored for [media_kit](https://github.com/alexmercerind/media_kit).

## Build Status
[![Build](https://github.com/Hilbert2048/libmpv-android-video-build/actions/workflows/build.yaml/badge.svg)](https://github.com/Hilbert2048/libmpv-android-video-build/actions/workflows/build.yaml)

## Upgrades & Fixes (January 2026)
This repository has been upgraded to support **MPV 0.41.0** and **FFmpeg 7.1**.

Key fixes included:
- **libxml2**: Switched to Meson build system to fix cross-compilation issues on Android.
- **AAudio**: Patched for compatibility with older NDK versions lacking `AAUDIO_FORMAT_IEC61937`.
- **Encoders-GPL**: Patched `fftools-ffi` to work with FFmpeg 7.1 (replaced deprecated `av_stream_get_end_pts`).

## Flavors

- **default**: Standard build (LGPL) suitable for most users.
- **full**: Includes more features/codecs (may be GPL).
- **encoders-gpl**: Includes GPL encoders (x264) and `fftools` CLI interface exposed to Dart.

## Integration with media-kit

1. **Download Artifacts**: Go to the [GitHub Actions](https://github.com/Hilbert2048/libmpv-android-video-build/actions) page for the latest successful run and download the artifacts (e.g., `libmpv-android-video-encoders-gpl`).
2. **Extract**: Unzip the downloaded file. You will find JAR files containing native libraries (`libmpv.so`, etc.).
3. **Install**:
   - Locate the `media_kit_libs_android_video` package in your project (or fork it).
   - Replace the `libs` content or configure your Gradle build to use the local JARs.
   
   If you are building your own app, you can place the JARs in your app's `android/app/libs` folder and ensure `build.gradle` includes `implementation fileTree(dir: 'libs', include: ['*.jar'])`.

## Manual Build
Requirements:
- Android NDK (r25c recommended)
- Meson, Ninja
- Standard build tools (automake, libtool, pkg-config, etc.)

Run:
```bash
./buildscripts/bundle_default.sh
# or
./buildscripts/bundle_encoders-gpl.sh
```
