# libcaesium drop-in layout

This repository stages `libcaesium 0.17.4` as prebuilt native artifacts for the
image compression FFI pipeline.

Expected layout:

- `prebuilt/windows/caesium.dll` or `prebuilt/windows/libcaesium.dll`
- `prebuilt/android/arm64-v8a/libcaesium.so`
- `prebuilt/android/armeabi-v7a/libcaesium.so`
- `prebuilt/android/x86_64/libcaesium.so`

Refresh staged artifacts with:

```powershell
pwsh .\tool\build_image_compression_native.ps1
```

The script copies the prebuilt libraries into the platform-specific load paths
used by the Flutter app:

- Windows: `windows/runner/`
- Android: `android/app/src/main/jniLibs/`
