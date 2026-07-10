# traybin

`tray_darwin_arm64` is a native Apple Silicon rebuild of the tray helper that
the `systray` npm package spawns. The x86_64 binary shipped by that package
was built with a pre-2019 Go toolchain whose runtime creates semaphores via
the raw `mach_msg` kernel trap. macOS (Tahoe+) forbids that trap under
Rosetta and kills the process with `EXC_GUARD`, so the tray icon dies at
startup — intermittently, depending on when the Go scheduler first parks a
thread. On Apple Silicon the plugin copies this native binary over the
package's `tray_darwin_release` before starting the tray (see `index.js`).

Source: `tray.go` (from [zaaack/systray-portable](https://github.com/zaaack/systray-portable),
unmodified) built against a current `github.com/getlantern/systray`.

Rebuild with:

```sh
CGO_ENABLED=1 GOOS=darwin GOARCH=arm64 go build -ldflags="-s -w" -o tray_darwin_arm64 tray.go
```
