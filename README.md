# Leafbound

Leafbound is a macOS app that converts a PDF, HTML file, or web link into a reflowable EPUB for Amazon Send to Kindle.

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
