# Leafbound

Leafbound is a macOS app that converts a PDF, HTML file, or web link into a reflowable EPUB for Amazon Send to Kindle.

## Download

Get `Leafbound-macOS-arm64.zip` from the [latest GitHub release](https://github.com/ziedhajsalah/leafbound/releases/latest). Each push to `main` publishes a build for Apple silicon Macs running macOS 14 or later. The release build is ad hoc signed and unnotarized.

### Open Leafbound for the first time

1. Unzip the download and open `Leafbound.app`.
2. If macOS says it cannot verify Leafbound, click **Done**.
3. Go to **System Settings → Privacy & Security**, scroll down to **Security**, and click **Open Anyway** next to the Leafbound message.
4. Confirm when prompted. macOS remembers the exception for that copy of the app.

If **Open Anyway** is missing, try opening Leafbound again, then return to **Privacy & Security**. [Apple Support](https://support.apple.com/en-us/102445)

## Run locally

Build with Swift 6 and the macOS SDK, then open the app on macOS 14 or later.

```sh
./scripts/build-app.sh
open dist/Leafbound.app
```

1. Drop a PDF or HTML file into **Local file**, or paste a public HTTP(S) address into **Web link**.
2. Select **Create EPUB** and choose where to save the file.
3. Upload the saved EPUB using [Amazon Send to Kindle](https://www.amazon.com/sendtokindle).

Local files are processed on your Mac. Leafbound sends web requests when you use a web link and leaves the upload to you.

PDF conversion extracts embedded text or recognizes text on scanned pages using macOS Vision. It does not preserve PDF page layouts or illustrations. Web links work with HTML served directly by the site. Pages that require a login or build their article in JavaScript may need to be saved as a local HTML file first. Leafbound embeds compatible raster images from the local HTML folder, from the same web origin, or inline.

## Checks

```sh
swift test
```
