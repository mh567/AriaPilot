# Bundled aria2 backend

AriaPilot expects the bundled macOS ARM64 aria2 binary at:

```text
vendor/aria2/darwin-arm64/aria2c
```

The release build copies this file into:

```text
AriaPilot.app/Contents/Resources/aria2/aria2c
```

The official aria2 release assets do not currently include a macOS ARM64
binary. The update workflow builds aria2 from the official source archive on a
macOS ARM runner, records the upstream version, and opens a pull request.
