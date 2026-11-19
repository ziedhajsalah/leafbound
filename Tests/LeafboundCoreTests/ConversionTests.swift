import CoreGraphics
import CoreText
import Foundation
import Testing
@testable import LeafboundCore

@Test func exportsStructuredHTML() async throws {
    let folder = try scratchFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let input = folder.appendingPathComponent("article.html")
    let output = folder.appendingPathComponent("article.epub")
    try """
    <!doctype html>
    <html lang="en"><head><meta name="author" content="A. Writer"><title>Tea &amp; Tides</title></head>
    <body><h1 id="introduction">Introduction</h1>
    <p>Tea &amp; tides with <strong>emphasis</strong> and <a href="#introduction">a link</a>.</p>
    <p><img src="local.png" alt="Local illustration"></p>
    <script>alert('remove-me')</script><p hidden>invisible text</p>
    <p><a href="javascript:alert(1)" onclick="alert(2)">plain text survives</a></p>
    </body></html>
    """.write(to: input, atomically: true, encoding: .utf8)
    let image = try #require(Data(base64Encoded:
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jR70AAAAASUVORK5CYII="
    ))
    try image.write(to: folder.appendingPathComponent("local.png"))

    let title = try await Converter.export(.file(input), to: output)
    #expect(title == "Tea & Tides")
    try checkPackage(output)
    let book = try entry("EPUB/book.xhtml", from: output)
    #expect(book.contains("<strong>emphasis</strong>"))
    #expect(book.contains("href=\"#ref-1\""))
    #expect(book.contains("src=\"images/image-1.png\""))
    #expect(book.contains("plain text survives"))
    #expect(!book.contains("javascript:") && !book.contains("invisible text") && !book.contains("remove-me"))
    #expect(try entry("EPUB/nav.xhtml", from: output).contains("book.xhtml#ref-1"))
    #expect(try entry("EPUB/book.opf", from: output).contains("<dc:creator>A. Writer</dc:creator>"))
}

@Test(arguments: [false, true]) func exportsPDF(scanned: Bool) async throws {
    let folder = try scratchFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let input = folder.appendingPathComponent(scanned ? "scan.pdf" : "text.pdf")
    let output = folder.appendingPathComponent("reading.epub")
    try createPDF(at: input, scanned: scanned)

    _ = try await Converter.export(.file(input), to: output)
    try checkPackage(output)
    let book = try entry("EPUB/book.xhtml", from: output)
    #expect(book.contains("Reading by the sea"))
}

@Test func emptySourceLeavesExistingExportIntact() async throws {
    let folder = try scratchFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let input = folder.appendingPathComponent("empty.html")
    let output = folder.appendingPathComponent("existing.epub")
    try "<html><body><script>ignored</script></body></html>".write(to: input, atomically: true, encoding: .utf8)
    let original = Data("existing contents".utf8)
    try original.write(to: output)
    await #expect(throws: ConversionError.empty) {
        _ = try await Converter.export(.file(input), to: output)
    }
    #expect(try Data(contentsOf: output) == original)
}

@Test func webArticleUsesReadingContent() async throws {
    let source = try #require(URL(string: "https://example.org/articles/current"))
    let html = """
    <html><head><title>Reading notes</title></head>
    <body><nav>Site navigation</nav><main><article><h1>A short article</h1>
    <p>Find the <a href="../archive">archive</a> for more.</p></article></main><footer>Site footer</footer></body>
    </html>
    """
    let book = try await HTMLReader.read(
        Data(html.utf8), source: source, fallbackTitle: "Example", download: nil
    )
    #expect(book.title == "Reading notes")
    #expect(book.body.contains("A short article"))
    #expect(book.body.contains("https://example.org/archive"))
    #expect(!book.body.contains("Site navigation") && !book.body.contains("Site footer"))
    #expect(Source.webURL("example.org/articles/current") == source)
    #expect(Source.webURL("file:///tmp/example.html") == nil)
}

private func scratchFolder() throws -> URL {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
    return folder
}

private func checkPackage(_ file: URL) throws {
    let data = try Data(contentsOf: file)
    // The OCF mimetype must be first, stored, and have no ZIP extra field.
    #expect(Array(data.prefix(4)) == [0x50, 0x4B, 0x03, 0x04])
    #expect(Array(data[8..<10]) == [0, 0])
    #expect(Array(data[26..<30]) == [8, 0, 0, 0])
    #expect(String(decoding: data[30..<58], as: UTF8.self) == "mimetypeapplication/epub+zip")

    for path in ["META-INF/container.xml", "EPUB/book.opf", "EPUB/book.xhtml", "EPUB/nav.xhtml"] {
        let xml = try entry(path, from: file)
        let parser = XMLParser(data: Data(xml.utf8))
        parser.shouldProcessNamespaces = true
        #expect(parser.parse())
    }
}

private func entry(_ path: String, from file: URL) throws -> String {
    let output = Pipe()
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
    process.arguments = ["-p", file.path, path]
    process.standardOutput = output
    try process.run()
    let data = output.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    try #require(process.terminationStatus == 0)
    return String(decoding: data, as: UTF8.self)
}

private func createPDF(at url: URL, scanned: Bool) throws {
    var page = CGRect(x: 0, y: 0, width: 600, height: 800)
    let pdf = try #require(CGContext(url as CFURL, mediaBox: &page, nil))
    let text = NSAttributedString(
        string: "Reading by the sea",
        attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName("Helvetica" as CFString, 38, nil)
        ]
    )
    let line = CTLineCreateWithAttributedString(text)
    pdf.beginPDFPage(nil)
    if scanned {
        let bitmap = try #require(CGContext(
            data: nil, width: 600, height: 800, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        bitmap.setFillColor(CGColor(gray: 1, alpha: 1))
        bitmap.fill(page)
        bitmap.textPosition = CGPoint(x: 70, y: 650)
        CTLineDraw(line, bitmap)
        let image = try #require(bitmap.makeImage())
        pdf.draw(image, in: page)
    } else {
        pdf.textPosition = CGPoint(x: 70, y: 650)
        CTLineDraw(line, pdf)
    }
    pdf.endPDFPage()
    pdf.closePDF()
}
