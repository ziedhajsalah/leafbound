import Foundation

enum EPUBWriter {
    static func write(_ book: Book, to destination: URL) throws {
        let manager = FileManager.default
        let staging = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try manager.createDirectory(at: staging, withIntermediateDirectories: false)
        defer { try? manager.removeItem(at: staging) }

        func write(_ text: String, at path: String) throws {
            try text.write(to: staging.appendingPathComponent(path), atomically: false, encoding: .utf8)
        }

        for directory in ["META-INF", "EPUB"] {
            try manager.createDirectory(
                at: staging.appendingPathComponent(directory), withIntermediateDirectories: false
            )
        }
        try write("application/epub+zip", at: "mimetype")
        try write("""
        <?xml version="1.0" encoding="UTF-8"?>
        <container xmlns="urn:oasis:names:tc:opendocument:xmlns:container" version="1.0">
          <rootfiles><rootfile full-path="EPUB/book.opf" media-type="application/oebps-package+xml"/></rootfiles>
        </container>
        """, at: "META-INF/container.xml")
        try write(package(book), at: "EPUB/book.opf")
        try write(document(book, body: book.body, stylesheet: true), at: "EPUB/book.xhtml")

        let entries = book.contents.isEmpty ? [Book.Entry(label: book.title, id: "")] : book.contents
        let links = entries.map { entry in
            let target = entry.id.isEmpty ? "book.xhtml" : "book.xhtml#\(entry.id)"
            return "<li><a href=\"\(target)\">\(entry.label.xmlEscaped)</a></li>"
        }.joined(separator: "\n")
        let navigation = """
        <nav epub:type="toc" id="contents"><h1>Contents</h1><ol>\(links)</ol></nav>
        """
        try write(document(book, body: navigation), at: "EPUB/nav.xhtml")
        try write("""
        body { line-height: 1.45; }
        img { max-width: 100%; height: auto; }
        figure { margin: 1em 0; }
        figcaption { font-size: 0.9em; }
        pre { white-space: pre-wrap; overflow-wrap: break-word; }
        blockquote { margin-inline: 1.25em; }
        table { border-collapse: collapse; }
        td, th { border: 1px solid; padding: 0.25em; }
        """, at: "EPUB/book.css")
        if !book.assets.isEmpty {
            try manager.createDirectory(
                at: staging.appendingPathComponent("EPUB/images"), withIntermediateDirectories: false
            )
            for asset in book.assets {
                try asset.data.write(to: staging.appendingPathComponent("EPUB/\(asset.path)"))
            }
        }

        let archive = staging.appendingPathComponent("export.epub")
        try zip(["-X0q", "export.epub", "mimetype"], in: staging)
        try zip(["-Xrq", "export.epub", "META-INF", "EPUB"], in: staging)
        try Task.checkCancellation()
        try Data(contentsOf: archive, options: .mappedIfSafe).write(to: destination, options: .atomic)
    }

    private static func package(_ book: Book) -> String {
        let modified = ISO8601DateFormatter().string(from: Date())
        let creator = book.author.map { "<dc:creator>\($0.xmlEscaped)</dc:creator>" } ?? ""
        let images = book.assets.enumerated().map { index, asset in
            "<item id=\"image-\(index)\" href=\"\(asset.path)\" media-type=\"\(asset.mediaType)\"/>"
        }.joined(separator: "\n")
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="book-id">
          <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
            <dc:identifier id="book-id">urn:uuid:\(UUID().uuidString.lowercased())</dc:identifier>
            <dc:title>\(book.title.xmlEscaped)</dc:title>
            <dc:language>\(book.language.xmlEscaped)</dc:language>
            \(creator)
            <meta property="dcterms:modified">\(modified)</meta>
          </metadata>
          <manifest>
            <item id="text" href="book.xhtml" media-type="application/xhtml+xml"/>
            <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
            <item id="css" href="book.css" media-type="text/css"/>
            \(images)
          </manifest>
          <spine><itemref idref="text"/></spine>
        </package>
        """
    }

    private static func document(_ book: Book, body: String, stylesheet: Bool = false) -> String {
        let style = stylesheet ? "<link rel=\"stylesheet\" href=\"book.css\"/>" : ""
        let language = book.language.xmlEscaped
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops"
              xml:lang="\(language)" lang="\(language)">
          <head><title>\(book.title.xmlEscaped)</title>\(style)</head>
          <body>\(body)</body>
        </html>
        """
    }

    private static func zip(_ arguments: [String], in directory: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = arguments
        process.currentDirectoryURL = directory
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw ConversionError.archive }
    }
}
