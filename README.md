# Leafbound

Leafbound is a macOS app that converts a PDF, HTML file, or web link into a reflowable EPUB for Amazon Send to Kindle.

## Download

Get `Leafbound-macOS-arm64.zip` from the [latest GitHub release](https://github.com/ziedhajsalah/leafbound/releases/latest). Leafbound runs on Apple silicon Macs with macOS 14 or later. Releases are ad hoc signed and unnotarized.

### Open Leafbound for the first time

1. Unzip the download and open `Leafbound.app`.
2. If macOS says it cannot verify Leafbound, click **Done**.
3. Go to **System Settings → Privacy & Security**, scroll down to **Security**, and click **Open Anyway** next to the Leafbound message.
4. Confirm when prompted. macOS remembers the exception for that copy of the app.

If **Open Anyway** is missing, try opening Leafbound again, then return to **Privacy & Security**. [Apple Support](https://support.apple.com/en-us/102445)

### Update Leafbound

Open **Leafbound → Check for Updates…**. When a newer version is available, follow the prompts to install it and relaunch. If your copy predates this menu item, download the [latest release](https://github.com/ziedhajsalah/leafbound/releases/latest) once to get the updater.

### Release versions

Leafbound uses `MAJOR.MINOR.PATCH` versions, starting at `0.0.4`. Pushes to `main` publish the next patch version by default and tag it on GitHub, for example `v0.0.5`. To publish a higher minor or major version, set `CFBundleShortVersionString` in `scripts/Info.plist` to the intended version, such as `0.1.0`, before pushing. Local builds use the version in that file.

## Run locally

Build with Swift 6 and the macOS SDK, then open the app on macOS 14 or later.

```sh
./scripts/build-app.sh
open dist/Leafbound.app
```

1. Drop a PDF or HTML file into **Local file**, or paste a public HTTP(S) address into **Web link**.
2. Select **Create EPUB** and choose where to save the file.
3. Click **Send to Kindle** to open the Kindle app on your Mac. If Leafbound can't open the app, it opens the upload page in your browser. You can upload the saved EPUB to your Kindle library at [Amazon Send to Kindle](https://www.amazon.com/sendtokindle).

Local files are processed on your Mac. Leafbound sends web requests when you use a web link and leaves the upload to you.

PDF conversion extracts embedded text or recognizes text on scanned pages using macOS Vision. It does not preserve PDF page layouts or illustrations. Web links work with HTML served directly by the site. Pages that require a login or build their article in JavaScript may need to be saved as a local HTML file first. Leafbound embeds compatible raster images from the local HTML folder, from the same web origin, or inline.

## Checks

```sh
swift test
```
