# Windows Native Dependencies

This directory caches third-party Windows native archives used by
`media_kit_libs_windows_video` during Flutter Windows builds.

Files:

- `ANGLE.7z`
  - Source: https://github.com/alexmercerind/flutter-windows-ANGLE-OpenGL-ES/releases/download/v1.0.1/ANGLE.7z
  - MD5: `e866f13e8d552348058afaafe869b1ed`
- `mpv-dev-x86_64-20230924-git-652a1dd.7z`
  - Source: https://github.com/media-kit/libmpv-win32-video-build/releases/download/2023-09-24/mpv-dev-x86_64-20230924-git-652a1dd.7z
  - MD5: `a832ef24b3a6ff97cd2560b5b9d04cd8`

The Windows CMake build verifies these archives before copying them into the
build directory. If these files are removed, the build falls back to downloading
the same archives from the upstream release URLs.
